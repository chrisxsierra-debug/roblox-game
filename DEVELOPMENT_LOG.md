# Development Log

## 2026-06-26 — Vertical slice + ProfileStore + adversarial review

**Build.** Implemented the playable vertical slice across server/world/client via a multi-agent
workflow (3 parallel track agents → integrate-to-green → review). The integrate pass found+fixed two
real contract gaps (a dead `UpdateSettings` handler and an unhandled `RequestData` RemoteFunction).
Checkpoint commit `c8d9b1b`.

**Data backend → ProfileStore.** Per the "copy how the top games do the backend" research, swapped the
hand-rolled DataStore layer for **ProfileStore** (loleris/MadStudio, Apache-2.0, vendored at
`Server/Vendor/ProfileStore.luau`) — session-locking is what prevents the server-hop/fast-rejoin data
loss that kills "currency goes up" games (loleris has stated Grow a Garden uses it). Kept
`PlayerDataService`'s public API identical, so nothing else changed. Added leaderstats mirroring. The
vendored lib is excluded from selene/stylua.

**Review.** The workflow's own review phase failed (two reviewers returned placeholder output, one
errored on the schema), so I re-ran a real 3-lens adversarial review (security / economy-logic /
integration+ProfileStore). Verdict: core is sound — no exploitable economy/ownership/double-grant/
early-harvest holes, ProfileStore integration correct, no require cycles. Fixed the real findings:
- Tutorial crop now pays the flat `TutorialReward` (20) and pins a fixed Common (was rolling 10–12).
- **Creature models now advance through their 4 stages** via a single central `GrowthService` sweep
  (§29-friendly) that also fires the `Ready` effect — previously the model was stuck at the egg.
- `RateLimiter:clear` is delimiter-aware (no longer wipes userId "120" when clearing "12").
- `DataSnapshot.PlotId` + `ReducedEffects` are now populated (fixes multi-player effect targeting and
  the reduced-effects setting); plot id flows via a transient cache (no require cycle).
- Client pulls an initial snapshot via `RequestData` and recovers its plot from `snapshot.PlotId`
  (fixes a first-frame race where the HUD/plot could be dropped).
- Offline-cap constant is now enforced as the max grow duration.

Remaining known gaps (gated, not active) tracked in `TODO.md` — chiefly: fertilizer charges aren't
consumed yet. All four static gates green throughout.

## 2026-06-26 — Foundation + 3-team scaffold

**Context.** Repo cleared of the previous ISHIMURA concept and re-scoped to *Brainrot Farm: Grow &
Raid* per the build spec. Decisions: structure the project for **3 human teammates**, build live in
**Studio via MCP (Mode A)** *later*, install a real toolchain and run tests now. The robloxstudio MCP
plugin is disconnected, so this pass is all file-based (the spec's "Mode B" for source).

**Built this pass.**
- Toolchain pinned in `rokit.toml` (rojo, lune, selene, stylua); `selene.toml`, `stylua.toml`, `.luaurc`.
- Rojo `default.project.json` mapping `src/` → ReplicatedStorage / ServerScriptService / StarterPlayer.
- **Shared foundation (fully implemented, dependency-free, unit-tested):** `EconomyConfig`, `GameConfig`,
  `MonetizationConfig`, `AssetConfig`, `AdminConfig`; `SeedTierDefinitions`, `MutationDefinitions`,
  `CreatureDefinitions` (9 original creatures); `Types`, `Constants`; `WeightedRandom`, `TableUtility`,
  `TimeUtility`; the `Remotes` registry.
- **Skeletons (stubs, interfaces locked):** server `ServerBootstrap` + 11 services + 2 factories + 3
  utilities (`RateLimiter` + `RemoteValidator` partly implemented); client `FarmClient` + 4 controllers
  + 7 UI modules (`UITheme` implemented).
- Lune test suite in `tests/run.luau`; all 8 docs incl. `TASK_SPLIT.md`.

**Key decisions / deviations.**
- **Colors as `{r,g,b}` and materials as strings** in Definitions instead of `Color3`/`Enum.Material`.
  Rationale: keeps those modules free of Roblox-only globals so Lune can unit-test them, and aligns with
  §13 ("don't store Color3 in data"). `CreatureModelFactory` converts them (helpers provided).
- **Lune-testability constraint:** every module a test touches is `require`-free, because Roblox-style
  (`script.Parent`) and Lune-style (relative path) requires are incompatible. Server/client code (which
  only runs in Roblox) freely uses Roblox requires and is verified in Studio instead.

**Not done / deferred.** All runtime behaviour (DataStore, planting, growth, harvest, UI, world,
playtests, security tests) is deferred to Studio (Mode A) and owned by the three tracks — see
`QA_CHECKLIST.md`. Nothing has been claimed as runtime-tested.
