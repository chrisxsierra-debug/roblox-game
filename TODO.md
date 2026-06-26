# TODO

Foundation is done. Remaining work is split in [`TASK_SPLIT.md`](TASK_SPLIT.md). High-level checklist:

## Track A — Server & Data
- [ ] `PlayerDataService`: load/save, backoff, **failed-load guard**, reconcile, migrate v0→v1,
      sanitize, autosave + PlayerRemoving + BindToClose, receipt pruning.
- [ ] `EconomyService`: add/spend coins, LifetimeCoins, BuySlot, unlock re-checks.
- [ ] `GrowthService`: ReadyAt at plant time + combined speed multiplier.
- [ ] `FarmService`: PlantSeed/HarvestSlot handlers + full §17 validation + rolls + payout.
- [ ] `RebirthService`: requirement, confirmation token, reset/preserve.
- [ ] `TutorialService`: step gating, guaranteed Common, persisted.
- [ ] `AutoCollectService`: single central interval loop.
- [ ] `MonetizationService`: pass cache + idempotent ProcessReceipt + pending-purchase context.
- [ ] `AdminService`: Studio-only guarded commands.
- [ ] `DataValidator.sanitizeProfile`.

## Track B — Client
- [ ] `UIController`: ScreenGui + wire UI modules + route snapshots.
- [ ] `FarmController`: slot input → intents; keyboard + gamepad; cosmetic stage animation.
- [ ] `TutorialController`, `EffectsController`.
- [ ] UI modules: `HUD`, `SlotPanel`, `SeedPicker`, `ShopPanel`, `RebirthPanel`, `NotificationPanel`.

## Track C — World, Creatures & QA
- [ ] `CreatureModelFactory`: 9 creatures × 4 stages × mutation visuals from Parts.
- [ ] `PlotFactory` + `WorldService`: 8 plots, world gen, authored-map detection, idempotent.
- [ ] Populate `AssetConfig` sound ids; author juice.
- [ ] Execute `QA_CHECKLIST.md` in Studio; record results.

## Shared / glue (small PRs, all rebase)
- [ ] Add admin UserIds to `AdminConfig`.
- [ ] Fill `MonetizationConfig` ids from the Creator Dashboard.
- [ ] Confirm pinned tool versions in `rokit.toml` resolve for everyone.

## V2 (do NOT build yet — §4)
Raiding, stealing, shields, trading, leaderboards, collection-book UI, friend fertilization, clans,
marketplace, multi-currency, multi-world. Extension points only.
