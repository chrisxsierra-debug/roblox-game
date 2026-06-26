# Integration Contract

The binding agreement between the three tracks. **All shared modules (`Shared/*`, `Remotes`) are
frozen** — implement against them, do not change them. If a change is truly needed, it's a separate
shared-layer PR everyone rebases on.

## 1. Session data (server-internal)
`PlayerDataService` is the **sole owner** of the in-memory session cache. Other server services read
and mutate through it; nothing else opens a DataStore.

```
PlayerDataService.getDefaultProfile(): PlayerData          -- already present
PlayerDataService.get(userId): PlayerData?                 -- live mutable profile, nil if not loaded/failed
PlayerDataService.isLoaded(userId): boolean
PlayerDataService.waitForData(player): PlayerData?          -- ADD: yields until loaded; nil on load-failure
PlayerDataService.markDirty(userId)                        -- ADD: flag for autosave
PlayerDataService.save(player, reason?)                    -- already present (implement body)
```
Pattern for other services: `local data = PlayerDataService.get(userId); if not data then return end;
mutate data...; PlayerDataService.markDirty(userId); replicate()`. After a load failure, `get` returns
`nil`, so every gameplay path no-ops safely (the failed-load guard).

On join, `PlotService` and `TutorialService` call `PlayerDataService.waitForData(player)` before acting.

## 2. Replication (server → client)
The server is the only writer of state. After any change, send the relevant event below.

| Remote | Args | Meaning |
| --- | --- | --- |
| `DataUpdated` | `(snapshot: DataSnapshot)` | full sanitized state; client replaces local state |
| `SlotUpdated` | `(slotIndex: number, slot: FarmSlot?)` | one slot changed; `slot=nil` means emptied |
| `FarmAssigned` | `(plotId: number)` | client locates its plot in Workspace by this id |
| `Notification` | `(text: string, level: number)` | toast (level 0 info … 2 big) |
| `TutorialUpdated` | `(step: number, completed: boolean, prompt: string?)` | onboarding state |
| `PlayEffect` | `(payload: EffectPayload)` | juice; `Kind` ∈ `Constants.Effects` |
| `PurchaseResult` | `(ok: boolean, message: string)` | result of a dev-product flow |

`DataSnapshot` (see `Types.luau`) is built **only** by the server and includes the derived fields
`IncomeMultiplier`, `NextSlotCost`, `RebirthRequirement`, and `Passes` — the client renders them as-is
and **never recomputes economy values**.

## 3. Intent (client → server)
The client sends only these, and only the args listed (never coins/payouts/ids/timestamps):

| Remote | Args |
| --- | --- |
| `PlantSeed` | `(slotIndex: number, seedTier: number)` |
| `HarvestSlot` | `(slotIndex: number)` |
| `BuySlot` | `()` — buys the next slot (`UnlockedSlots + 1`); server owns the cost |
| `RequestRebirth` | `()` — server validates affordability + a short cooldown; client shows the confirm dialog |
| `RequestInstantGrowPurchase` | `(slotIndex: number)` |
| `RequestFertilizerPurchase` | `()` |
| `RequestCoinPackPurchase` | `(packKey: string)` |
| `UpdateSettings` | `(settings: {MusicVolume:number, SoundVolume:number, ReducedEffects:boolean})` |

Every handler goes through `RemoteValidator` (arg shape/range) **and** `RateLimiter` (per
`Constants.RateLimits`) before touching data.

## 4. World ↔ Client (3D slot discovery)
The **World** builds each plot under `Workspace/<Constants.World.GeneratedFolder>/<PlotsFolder>` and tags
every grow-slot anchor with `Constants.Tags.GrowSlot`, plus attributes:
`Constants.Attributes.PlotId`, `Constants.Attributes.SlotIndex`, and `Constants.Attributes.Locked`.
The plot root is tagged `Constants.Tags.Plot` with `PlotId` + `OwnerUserId` attributes.

The **Client**, on `FarmAssigned(plotId)`, finds its plot by `PlotId`, then finds each slot anchor by
`SlotIndex` to position SurfaceGui/BillboardGui prompts and the (server-spawned) creature models. The
client never builds gameplay parts — only UI/Billboards.

Creature models are spawned **by the server** (`CreatureModelFactory`) parented under the slot anchor so
they replicate; the client only reads them for cosmetic stage animation driven by replicated
`PlantedAt`/`ReadyAt` (via `GrowthService.getStageIndex`).

## 5. Effects payloads (`EffectPayload.Kind`)
- `Plant` — `{Kind, SlotIndex}` dirt puff + egg pop
- `StageChange` — `{Kind, SlotIndex}` bounce/sparkle
- `Ready` — `{Kind, SlotIndex}` glow + READY billboard
- `Harvest` — `{Kind, SlotIndex, CreatureId, MutationId, Amount}` coin burst + floating payout
- `Mutation` — `{Kind, SlotIndex, MutationId}` rarity reveal (server may also broadcast a `Notification`)

## 6. Ownership of files (no two tracks write the same file)
- **Track A (server):** `ServerScriptService/Server/Services/*` (except World/Plot **visuals**),
  `Server/Utility/*`, `ServerBootstrap`. Owns the session cache + all authority + security.
- **Track C (world):** `Server/Services/WorldService`, `Server/Factories/*` (`PlotFactory`,
  `CreatureModelFactory`). Owns Workspace generation + creature/plot visuals.
  (Seam: `PlotService` (A) decides *who* owns *which* plot and calls `WorldService`/`PlotFactory` (C) to
  build/rebuild visuals. `PlotService.assign` → `WorldService.buildPlotFor(player, plotId)`.)
- **Track B (client):** `StarterPlayer/StarterPlayerScripts/Client/*` + `FarmClient`. Owns all UI/input.

## 7. Definition of done for this slice
Join → auto-assigned plot → tutorial (free guaranteed Common, 15s, +20) → plant Tier 1 → 4 visible
stages → reveal creature+mutation → harvest → coins up → buy slot → unlock tiers via LifetimeCoins →
rebirth → leave/rejoin with progress + offline growth. Monetization framework present (pass checks +
idempotent ProcessReceipt), but tuning/playtest is Mode A (Studio). Static gates: `selene src`,
`stylua --check`, `lune run tests/run`, `rojo build` all green.
