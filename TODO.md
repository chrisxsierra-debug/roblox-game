# TODO

The playable vertical slice is **implemented** (server/world/client) and the data layer uses
**ProfileStore** session-locking. Static gates are green (selene/stylua/lune/rojo). Nothing has been
runtime-tested in Studio yet — that's the top remaining item. See [`TASK_SPLIT.md`](TASK_SPLIT.md) for
ownership and [`QA_CHECKLIST.md`](QA_CHECKLIST.md) for the Studio test pass.

## Top priority — Studio (Mode A)
- [ ] Open Studio with the Rojo/robloxstudio plugin, sync, and run `QA_CHECKLIST.md` end to end.
      Enable Studio API access so ProfileStore uses the real DataStore (else it runs in mock mode).
- [ ] Tune the three headline balance values first: tutorial grow duration, starting slot count,
      Tier-1 profit/grow time.

## Known gaps from the adversarial review (do before a monetized launch)
- [ ] **Fertilizer is not consumable.** `RequestFertilizerPurchase` grants `FertilizerCharges`, but no
      flow ever spends a charge / reduces a crop's remaining time. It's harmless today because the
      product Id defaults to 0 (the button is hidden), but **do not configure the FertilizerPack Id**
      until a "use fertilizer on a slot" path exists (new remote + handler + UI), or repurpose the
      product to apply the reduction directly on purchase like Instant Grow.
- [ ] **Instant-Grow fallback** currently grants a Fertilizer pack if the targeted slot vanished between
      prompt and receipt (and fertilizer does nothing yet). Improve to complete the player's first
      growing crop instead, or refund-equivalent with a clear `Notification`. (Also gated by Id 0.)
- [ ] **Settings UI.** The server `UpdateSettings` handler + `ReducedEffects` snapshot field exist and
      are wired, but there's no client settings panel that fires `UpdateSettings`. Build one (Track B).
- [ ] `MonetizationService` fires one `SlotUpdated` with the live slot table instead of a deep copy —
      route it through the same helper as `FarmService` for convention (cosmetic; Roblox serializes on
      send so there's no aliasing bug).

## Polish / V1.1
- [ ] Server-emit `StageChange` juice too (currently client-driven locally; the model staging itself is
      now server-driven via the GrowthService sweep).
- [ ] Fill `MonetizationConfig` + `AssetConfig` ids from the Creator Dashboard (all default 0).
- [ ] Add admin UserIds to `AdminConfig`.

## V2 (do NOT build yet — §4)
Raiding, stealing, shields, trading, leaderboards, collection-book UI, friend fertilization, clans,
marketplace, multi-currency, multi-world. Extension points only.
