# QA Checklist

## Automated (run now, no Studio)
- [x] `lune run tests/run` — pure-logic tests (economy, definitions, utilities). **Status recorded in
      DEVELOPMENT_LOG / PR.**
- [ ] `selene src` — static analysis clean.
- [ ] `stylua --check src tests` — formatting clean.
- [ ] `rojo build default.project.json -o build.rbxlx` — project maps to a valid place.

## Manual — Studio required (Mode A) — ALL currently **UNVERIFIED**
The robloxstudio plugin is disconnected, so none of the below has been tested. Track C runs these once
Studio is connected (§30, §32).

### Core loop
- [ ] First join assigns a plot and teleports the player to it.
- [ ] Tutorial starts; free guaranteed Common egg; 15s grow; +20 coins on harvest.
- [ ] Plant a Tier 1 seed → 4 visible growth stages → reveal creature + mutation.
- [ ] Harvest a ready crop → coins increase by the server-computed payout.
- [ ] **Early harvest is rejected** (server refuses before `ReadyAt`).
- [ ] Insufficient coins → plant/buy rejected.
- [ ] Locked seed tier / locked slot → rejected.

### Economy & progression
- [ ] Buy slot deducts the correct cost and adds open dirt.
- [ ] Seed tier unlocks at the right LifetimeCoins.
- [ ] Rebirth resets Coins→20, slots→2, clears crops; preserves LifetimeCoins, unlocks, tutorial,
      purchases; multiplier persists.

### Persistence
- [ ] Rejoin restores coins, slots, rebirths, and in-progress growth.
- [ ] **Offline growth**: a crop matures while logged out (advances by real elapsed time, capped 8h).
- [ ] **Failed data load** cannot overwrite existing data (simulate via AdminService dev command).
- [ ] Player leaving / server closing saves correctly.

### Multiplayer & security
- [ ] Two players claim separate plots simultaneously.
- [ ] A player **cannot** plant/harvest/buy on another player's slot.
- [ ] Invalid remote arguments are rejected (fire malformed payloads via the MCP `execute_luau` /
      command bar).
- [ ] Rate limiting blocks spammed remotes.

### Monetization
- [ ] Pass/product buttons with id 0 are hidden; no errors.
- [ ] Auto-Collect harvests ready crops on its interval.
- [ ] VIP applies its +15% **once**.
- [ ] Instant Grow receipt cannot be replayed for a duplicate grant.

### Platform
- [ ] Mobile emulator: thumb-reachable, readable, no tiny targets.
- [ ] Gamepad navigation works.
