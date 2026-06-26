# Task Split — 3 Teammates

The shared foundation (everything in `src/ReplicatedStorage/Shared` + `Remotes`) is **done and
unit-tested**. It is the *contract*: all three tracks depend on it and only on it, so they can be
built in parallel with very few merge conflicts (each track owns a different folder).

> Before writing code: read [`ARCHITECTURE.md`](ARCHITECTURE.md) and [`DATA_SCHEMA.md`](DATA_SCHEMA.md),
> install the toolchain (`rokit install`), and run `lune run tests/run` to confirm a green baseline.

Each stub already declares the function signatures you implement — search the code for
`TODO(Track A)`, `TODO(Track B)`, `TODO(Track C)`.

---

## Track A — Server Systems & Data  (owner: ____)
**Folder you own:** `src/ServerScriptService/Server/Services` + `Server/Utility`
**Spec sections:** §13–18, §24, §27, §29 (server)

The authority. If it touches Coins, slots, growth completion, rolls, payouts, rebirths, unlocks,
passes, or receipts, it lives here and the client may never compute it.

1. `PlayerDataService` — DataStore load/save: `UpdateAsync` + pcall + exponential backoff,
   **failed-load guard** (mark load-failed → friendly error → block gameplay → kick → never save),
   default reconciliation (`TableUtility.reconcile`), migration v0→v1, sanitize/clamp
   (`DataValidator`), autosave (60s) + `PlayerRemoving` + `BindToClose`, receipt pruning.
2. `EconomyService` — add/spend coins, LifetimeCoins on earn, BuySlot validation, unlock re-checks.
3. `GrowthService` — set `ReadyAt` at plant time using the combined speed multiplier; stage index.
4. `FarmService` — the plant/harvest remote handlers + full validation (§17) + creature/mutation
   rolls (`WeightedRandom`) + payout (`EconomyConfig.computePayout`).
5. `RebirthService` — server-computed requirement, confirmation token, reset/preserve rules.
6. `TutorialService` — step state + gating (guaranteed Common, 15s, +20 coins), persisted.
7. `AutoCollectService` — one central interval loop (not per-crop).
8. `MonetizationService` — pass ownership cache + idempotent `ProcessReceipt` + pending-purchase
   context for Instant Grow + safe fallback.
9. `AdminService` — Studio-only guarded commands.
10. `Server/Utility` — extend `RateLimiter` (done), `RemoteValidator` (guards done), `DataValidator`.

**Definition of done:** every remote validated + rate-limited; a client cannot harvest early,
overspend, plant a locked/unaffordable seed, or touch another player's slot.

---

## Track B — Client UI, Input & Effects  (owner: ____)
**Folder you own:** `src/StarterPlayer/StarterPlayerScripts/Client`
**Spec sections:** §19, §20, §25, §28

Everything the player sees and touches. Display only — render server snapshots, send intent,
never compute a payout.

1. `UIController` — build the ScreenGui; instantiate HUD + panels; route `DataUpdated`,
   `SlotUpdated`, `Notification`, `TutorialUpdated`, `PlayEffect`.
2. `FarmController` — slot tap/click → SeedPicker / growing info / Harvest → fire `PlantSeed` /
   `HarvestSlot`; keyboard (E/B/R/Esc) + gamepad (`ContextActionService`); cosmetic stage animation
   from replicated timestamps.
3. `TutorialController` — onboarding prompts from `TutorialUpdated`; no Robux prompts mid-tutorial.
4. `EffectsController` — juice from `PlayEffect`; respects `ReducedEffects` + AssetConfig id 0.
5. `UI/*` — `HUD`, `SlotPanel`, `SeedPicker`, `ShopPanel`, `RebirthPanel`, `NotificationPanel`
   (build on the finished `UITheme`). Mobile-first, thumb-reachable, safe-area aware, scalable.

**Definition of done:** a player on a phone can see coins, plant, watch growth, harvest, open the
shop, buy a slot, and rebirth — all driven by server data, hiding any pass/product with id 0.

---

## Track C — World, Creatures & QA  (owner: ____)
**Folder you own:** `src/ServerScriptService/Server/Factories` + world gen in `WorldService` +
the QA pass + the in-Studio assembly.
**Spec sections:** §11, §21, §22, §28 (assets), §30, §32

The 3D world and the creature art, plus owning the Studio integration the other two can't do headless.

1. `CreatureModelFactory` — build the 9 creatures from primitive Parts by `ModelBuilderId`
   (Quadruped/Biped/Blob/Tall); 4 simplifying growth stages; mutation visuals (Shiny/Golden/Giant/
   Glitched); convert `{r,g,b}` → `Color3` (helper done) and material string → `Enum.Material`
   (helper done); no rapid flashing; clean up.
2. `PlotFactory` + `WorldService` — generate baseplate, spawn, 8 plots (signs, slots, rebirth altar,
   shop sign, borders), paths, lighting; detect an authored map first; anchored; idempotent.
3. Populate `AssetConfig` sound ids and author the juice assets.
4. **Own the Studio integration + QA:** run [`QA_CHECKLIST.md`](QA_CHECKLIST.md) once the
   robloxstudio plugin is connected, coordinate playtests, file bugs back to A/B.

**Definition of done:** joining spawns you at your own plot with placeholder creatures that visibly
grow through 4 stages, and the QA checklist is executed with results recorded.

---

## Seams (where tracks touch — agree on these early)
- **Plot ownership/assignment** = Track A (`PlotService` logic). **Plot visuals** = Track C
  (`PlotFactory`). A calls C to build; C never reads player data directly.
- **Remotes** are frozen in `Shared/Constants` + `Remotes`. If you need a new one, change it in the
  shared layer in a small dedicated PR so all three rebase on it.
- **Snapshots:** Track A defines the `DataSnapshot` shape (already typed in `Types.luau`); Track B
  consumes it. Change it together.

## Workflow
- Branch per track (`track-a/...`, `track-b/...`, `track-c/...`), PR into the integration branch.
- Keep `lune run tests/run`, `selene src`, and `stylua --check` green before every PR.
- Don't claim a feature works until it's been tested in Studio (§1.18).
