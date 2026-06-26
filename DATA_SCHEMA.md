# Data Schema

Canonical types live in [`src/ReplicatedStorage/Shared/Types.luau`](src/ReplicatedStorage/Shared/Types.luau).
`os.time()` (absolute seconds) everywhere. **Never** store Instances, Color3s, functions, or
metatables in saved data (§13).

## PlayerData
```
DataVersion      number          schema version (current = GameConfig.DataVersion)
Coins            number          spendable currency
LifetimeCoins    number          total ever earned; drives seed unlocks; NEVER reset on rebirth
Rebirths         number          income multiplier = 1 + Rebirths * 0.5
UnlockedSlots    number          2..12
HighestSeedTier  number          highest seed tier ever unlocked
Slots            {FarmSlot}       one entry per grow slot
Tutorial         {Completed, Step}
Statistics       {TotalPlanted, TotalHarvested, TotalCoinsEarned, HighestMutationRank, PlaySeconds}
Settings         {MusicVolume, SoundVolume, ReducedEffects}
Purchases        {ProcessedReceipts: {[receiptId]: timestamp}}   pruned to cap growth (§24)
FertilizerCharges number
LastSeenAt       number          os.time() at last save (for "crops kept growing" message)
```

## FarmSlot
```
SeedTierId            number?   nil = empty (open dirt)
CreatureId            string?   rolled on the server at plant time
MutationId            string?   rolled on the server at plant time
PlantedAt             number?   os.time() when planted
ReadyAt               number?   os.time() when finished (absolute → offline growth §15)
GrowthSpeedMultiplier number?   combined multiplier applied at plant (§18)
```
An empty slot has all crop fields `nil`. The client may send only a slot index + seed tier; the server
loads the authoritative slot from its session cache (§12).

## DataStore (§14)
- Name from `GameConfig.getDataStoreName()` — separate **DEV** and **PROD** stores; version in the name.
- `UpdateAsync` + pcall + exponential backoff, up to `GameConfig.MaxDataStoreRetries`.
- **Failed-load guard:** if a load fails after retries, mark the session load-failed, show a friendly
  error, block gameplay requests, remove the player safely, and **never** save that session.
- Reconcile against the default profile (`TableUtility.reconcile`); migrate old `DataVersion`s
  (include an example v0→v1); sanitize/clamp numbers; repair duplicate slots; prune receipts.
- Save on autosave (60s), `PlayerRemoving`, `BindToClose`, and after rebirth.
