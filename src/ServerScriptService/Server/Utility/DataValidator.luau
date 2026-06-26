--!strict
-- DataValidator — sanitize/clamp loaded profile data (§14). TRACK A.
--
-- Responsibilities: coerce malformed numbers, clamp to sane ranges, repair
-- duplicate/oversized Slots arrays, prune the ProcessedReceipts map, and ensure
-- required fields exist (pair with TableUtility.reconcile against the default).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local SeedTierDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("SeedTierDefinitions"))
local CreatureDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("CreatureDefinitions"))
local MutationDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("MutationDefinitions"))

local DataValidator = {}

-- Receipts older than this (relative to the largest receipt timestamp) are pruned,
-- and the map is hard-capped to avoid unbounded growth (§24).
local MAX_PROCESSED_RECEIPTS = 200

-- Coerce a value to a finite number within [min, max], falling back to default.
function DataValidator.sanitizeNumber(value: any, default: number, min: number, max: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return default
	end
	return math.clamp(value, min, max)
end

-- Coerce a value to a finite, non-negative INTEGER within [min, max].
local function sanitizeInt(value: any, default: number, min: number, max: number): number
	local n = DataValidator.sanitizeNumber(value, default, min, max)
	return math.floor(n)
end

-- Validate a single slot. An invalid/partial crop is reset to empty (all nil).
-- Returns the sanitized slot and whether it was repaired.
local function sanitizeSlot(slot: any): ({ [string]: any }, boolean)
	if type(slot) ~= "table" then
		return {}, true
	end

	local seedTier = slot.SeedTierId
	-- An empty slot has no SeedTierId.
	if seedTier == nil then
		-- Empty slot: ensure no stray crop fields remain.
		local hadStrays = slot.CreatureId ~= nil
			or slot.MutationId ~= nil
			or slot.PlantedAt ~= nil
			or slot.ReadyAt ~= nil
			or slot.GrowthSpeedMultiplier ~= nil
		return {}, hadStrays
	end

	local repaired = false

	-- SeedTier must be a valid, defined tier.
	if type(seedTier) ~= "number" or seedTier % 1 ~= 0 or not SeedTierDefinitions.get(seedTier) then
		return {}, true
	end

	-- A planted crop must have valid creature + mutation + timestamps. If any are
	-- malformed we cannot trust the crop, so reset the slot to empty.
	local creatureId = slot.CreatureId
	local mutationId = slot.MutationId
	if
		type(creatureId) ~= "string"
		or not CreatureDefinitions.get(creatureId)
		or type(mutationId) ~= "string"
		or not MutationDefinitions.get(mutationId)
	then
		return {}, true
	end

	local plantedAt = slot.PlantedAt
	local readyAt = slot.ReadyAt
	if type(plantedAt) ~= "number" or type(readyAt) ~= "number" or readyAt < plantedAt then
		return {}, true
	end

	local growthMult = slot.GrowthSpeedMultiplier
	local sanitizedMult: number?
	if growthMult ~= nil then
		sanitizedMult = DataValidator.sanitizeNumber(growthMult, 1, 0.001, 1000)
		if sanitizedMult ~= growthMult then
			repaired = true
		end
	end

	return {
		SeedTierId = seedTier,
		CreatureId = creatureId,
		MutationId = mutationId,
		PlantedAt = math.floor(plantedAt),
		ReadyAt = math.floor(readyAt),
		GrowthSpeedMultiplier = sanitizedMult,
	},
		repaired
end

-- Prune the ProcessedReceipts map: drop non-number entries and hard-cap its size,
-- keeping the most-recent timestamps. Returns the (new) map and whether it changed.
local function pruneReceipts(receipts: any): ({ [string]: number }, boolean)
	if type(receipts) ~= "table" then
		return {}, true
	end

	local entries: { { key: string, ts: number } } = {}
	local changed = false
	for key, ts in receipts do
		if type(key) == "string" and type(ts) == "number" and ts == ts then
			table.insert(entries, { key = key, ts = ts })
		else
			changed = true
		end
	end

	if #entries > MAX_PROCESSED_RECEIPTS then
		table.sort(entries, function(a, b)
			return a.ts > b.ts
		end)
		while #entries > MAX_PROCESSED_RECEIPTS do
			table.remove(entries)
		end
		changed = true
	end

	local result: { [string]: number } = {}
	for _, entry in entries do
		result[entry.key] = entry.ts
	end
	return result, changed
end

-- Full-profile sanitize (§14): clamp numbers, fix slot array length to the
-- UnlockedSlots bound, repair malformed crops, prune receipts. Returns the
-- (mutated) data and whether anything was repaired.
function DataValidator.sanitizeProfile(data: any): (any, boolean)
	if type(data) ~= "table" then
		-- Caller will reconcile a fresh default over this, but signal a repair.
		return {}, true
	end

	local repaired = false

	-- ── Scalar economy fields ────────────────────────────────────────────
	local coins = DataValidator.sanitizeNumber(data.Coins, EconomyConfig.StartingCoins, 0, 1e15)
	if coins ~= data.Coins then
		repaired = true
	end
	data.Coins = math.floor(coins)

	local lifetime = DataValidator.sanitizeNumber(data.LifetimeCoins, 0, 0, 1e15)
	if lifetime ~= data.LifetimeCoins then
		repaired = true
	end
	data.LifetimeCoins = math.floor(lifetime)

	-- LifetimeCoins must never be less than current Coins floor for unlock sanity,
	-- but we do not force it up — a fresh profile legitimately has more Coins than
	-- Lifetime only via admin/defaults; leave as clamped.

	local rebirths = sanitizeInt(data.Rebirths, 0, 0, 1e6)
	if rebirths ~= data.Rebirths then
		repaired = true
	end
	data.Rebirths = rebirths

	local unlocked = sanitizeInt(
		data.UnlockedSlots,
		EconomyConfig.StartingSlots,
		EconomyConfig.StartingSlots,
		EconomyConfig.MaxSlots
	)
	if unlocked ~= data.UnlockedSlots then
		repaired = true
	end
	data.UnlockedSlots = unlocked

	local highestTier = sanitizeInt(data.HighestSeedTier, 1, 1, SeedTierDefinitions.MaxTier)
	if highestTier ~= data.HighestSeedTier then
		repaired = true
	end
	data.HighestSeedTier = highestTier

	local fertilizer = sanitizeInt(data.FertilizerCharges, 0, 0, 1e9)
	if fertilizer ~= data.FertilizerCharges then
		repaired = true
	end
	data.FertilizerCharges = fertilizer

	local lastSeen = DataValidator.sanitizeNumber(data.LastSeenAt, 0, 0, 1e15)
	if lastSeen ~= data.LastSeenAt then
		repaired = true
	end
	data.LastSeenAt = math.floor(lastSeen)

	-- ── Slots array: exactly UnlockedSlots entries ───────────────────────
	if type(data.Slots) ~= "table" then
		data.Slots = {}
		repaired = true
	end

	local newSlots: { [number]: any } = {}
	for i = 1, data.UnlockedSlots do
		local sanitized, slotRepaired = sanitizeSlot(data.Slots[i])
		newSlots[i] = sanitized
		if slotRepaired then
			repaired = true
		end
	end
	-- Drop any trailing/duplicate entries beyond UnlockedSlots.
	if #data.Slots ~= data.UnlockedSlots then
		repaired = true
	end
	data.Slots = newSlots

	-- ── Statistics ───────────────────────────────────────────────────────
	if type(data.Statistics) ~= "table" then
		data.Statistics = {}
		repaired = true
	end
	local stats = data.Statistics
	stats.TotalPlanted = sanitizeInt(stats.TotalPlanted, 0, 0, 1e15)
	stats.TotalHarvested = sanitizeInt(stats.TotalHarvested, 0, 0, 1e15)
	stats.TotalCoinsEarned = sanitizeInt(stats.TotalCoinsEarned, 0, 0, 1e15)
	stats.HighestMutationRank = sanitizeInt(stats.HighestMutationRank, 0, 0, 1e6)
	stats.PlaySeconds = sanitizeInt(stats.PlaySeconds, 0, 0, 1e15)

	-- ── Settings ─────────────────────────────────────────────────────────
	if type(data.Settings) ~= "table" then
		data.Settings = { MusicVolume = 0.5, SoundVolume = 0.5, ReducedEffects = false }
		repaired = true
	end
	local settings = data.Settings
	settings.MusicVolume = DataValidator.sanitizeNumber(settings.MusicVolume, 0.5, 0, 1)
	settings.SoundVolume = DataValidator.sanitizeNumber(settings.SoundVolume, 0.5, 0, 1)
	if type(settings.ReducedEffects) ~= "boolean" then
		settings.ReducedEffects = false
		repaired = true
	end

	-- ── Tutorial ─────────────────────────────────────────────────────────
	if type(data.Tutorial) ~= "table" then
		data.Tutorial = { Completed = false, Step = 0 }
		repaired = true
	end
	local tutorial = data.Tutorial
	if type(tutorial.Completed) ~= "boolean" then
		tutorial.Completed = false
		repaired = true
	end
	tutorial.Step = sanitizeInt(tutorial.Step, 0, 0, 1000)

	-- ── Purchases / receipts ─────────────────────────────────────────────
	if type(data.Purchases) ~= "table" then
		data.Purchases = { ProcessedReceipts = {} }
		repaired = true
	end
	local prunedReceipts, receiptsChanged = pruneReceipts(data.Purchases.ProcessedReceipts)
	data.Purchases.ProcessedReceipts = prunedReceipts
	if receiptsChanged then
		repaired = true
	end

	-- ── DataVersion ──────────────────────────────────────────────────────
	if data.DataVersion ~= GameConfig.DataVersion then
		-- Migration is the caller's job; record only that a value was off.
		data.DataVersion = GameConfig.DataVersion
		repaired = true
	end

	return data, repaired
end

return DataValidator
