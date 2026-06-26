# Development Log

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
