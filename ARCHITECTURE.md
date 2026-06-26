# Architecture

## Principles
- **Server-authoritative.** The client sends *intent* (a slot index + seed tier). The server owns
  every value that matters (§17). The client growth bar is cosmetic; the server recomputes on harvest.
- **Timestamp-driven, not loop-driven.** Growth is `ReadyAt = PlantedAt + duration`. No per-crop
  loops; readiness is a comparison against `os.time()` (§9, §29). Offline growth is automatic (§15).
- **Single sources of truth.** All balance in `Shared/Config`; all definitions in `Shared/Definitions`;
  all IDs in `MonetizationConfig`/`AssetConfig`; all remote names in `Shared/Constants`.
- **Dependency-free shared leaf modules.** Config/Definitions/Utility `require` nothing and avoid
  Roblox-only globals, so they unit-test under Lune. Colors are `{r,g,b}` and materials are strings,
  converted to `Color3`/`Enum.Material` in `CreatureModelFactory`.

## Lifecycle
`ServerBootstrap` and `FarmClient` each load their modules in a fixed order and call `Init()` then
`Start()` on every one (errors are isolated via pcall). To add a system, drop a module in the right
folder and add its name to the order list in the bootstrap.

Service order (server): PlayerData → World → Plot → Growth → Economy → Farm → Rebirth → Tutorial →
AutoCollect → Monetization → Admin. Controller order (client): UI → Farm → Tutorial → Effects.

## Data flow (plant → harvest)
1. Client taps an empty slot → `SeedPicker` → fires `PlantSeed(slotIndex, seedTier)`.
2. `FarmService` validates (data loaded, owns plot, slot in range + empty, tier unlocked, affordable,
   not rate-limited, tutorial allows), deducts cost (`EconomyService`), rolls creature + mutation
   (`WeightedRandom`), sets `ReadyAt` (`GrowthService`), stores the slot, marks data dirty, replicates
   a sanitized slot via `SlotUpdated`.
3. Client animates 4 cosmetic stages from the replicated `PlantedAt`/`ReadyAt`.
4. Client taps a ready slot → fires `HarvestSlot(slotIndex)`.
5. `FarmService` validates (`now >= ReadyAt`, owned, not already harvested), computes payout
   (`EconomyConfig.computePayout`), adds coins + LifetimeCoins, updates stats, re-checks unlocks,
   clears the slot, marks dirty, fires `PlayEffect` + `DataUpdated`.

## Networking
One `Net` folder of shared RemoteEvents/Functions (`Remotes` module), never per-slot remotes (§29).
Server→client uses sanitized `DataSnapshot`s (`Types.luau`); no internal/security fields leave the server.

## Security
`RemoteValidator` (arg shape/range) + `RateLimiter` (per-key/sec) guard every handler. The server
accepts only a slot index and seed tier from the client — never coins, payouts, durations, ready
times, ids, multipliers, or ownership (§17).
