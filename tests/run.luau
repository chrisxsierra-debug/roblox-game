--!strict
-- Pure-logic test runner for Brainrot Farm (§30).
-- Run with:  lune run tests/run
--
-- These cover the DEPENDENCY-FREE shared modules (Config, Definitions, Utility).
-- Server/client code that needs Roblox instances is tested in Studio (see
-- QA_CHECKLIST.md), not here.

local process = require("@lune/process")

-- ── modules under test (relative to this file) ────────────────────────────
local EconomyConfig = require("../src/ReplicatedStorage/Shared/Config/EconomyConfig")
local SeedTierDefinitions =
	require("../src/ReplicatedStorage/Shared/Definitions/SeedTierDefinitions")
local MutationDefinitions =
	require("../src/ReplicatedStorage/Shared/Definitions/MutationDefinitions")
local CreatureDefinitions =
	require("../src/ReplicatedStorage/Shared/Definitions/CreatureDefinitions")
local WeightedRandom = require("../src/ReplicatedStorage/Shared/Utility/WeightedRandom")
local TableUtility = require("../src/ReplicatedStorage/Shared/Utility/TableUtility")
local TimeUtility = require("../src/ReplicatedStorage/Shared/Utility/TimeUtility")

-- ── tiny test harness ─────────────────────────────────────────────────────
local passed = 0
local failed = 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
		print(string.format("  ok   %s", name))
	else
		failed += 1
		print(string.format("  FAIL %s", name))
	end
end

local function approx(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- ── EconomyConfig ─────────────────────────────────────────────────────────
print("EconomyConfig")
check(
	"slots 1 and 2 are free",
	EconomyConfig.getSlotCost(1) == 0 and EconomyConfig.getSlotCost(2) == 0
)
check("slot 3 costs 50", EconomyConfig.getSlotCost(3) == 50)
check("slot 12 costs 175000", EconomyConfig.getSlotCost(12) == 175000)
check("slot 13 is nil (beyond max)", EconomyConfig.getSlotCost(13) == nil)
check("income multiplier at 0 rebirths is 1", approx(EconomyConfig.getIncomeMultiplier(0), 1))
check("income multiplier at 2 rebirths is 2", approx(EconomyConfig.getIncomeMultiplier(2), 2))
check("rebirth req at 0 is 10000", EconomyConfig.getRebirthRequirement(0) == 10000)
check("rebirth req at 1 is 40000", EconomyConfig.getRebirthRequirement(1) == 40000)
check("growth duration halves with 2x", approx(EconomyConfig.getGrowthDuration(30, 2), 15))
check("growth duration safe with 0 mult", approx(EconomyConfig.getGrowthDuration(30, 0), 30))
check("payout base case = 10", EconomyConfig.computePayout(10, 1, 1, 0, false) == 10)
check("payout scales with rebirths", EconomyConfig.computePayout(10, 1, 1, 2, false) == 20)
check(
	"payout applies VIP once",
	EconomyConfig.computePayout(10, 1, 1, 2, true) == math.floor(20 * 1.15)
)
check("payout floors", EconomyConfig.computePayout(10, 1.1, 1, 0, false) == 11)

-- ── SeedTierDefinitions ───────────────────────────────────────────────────
print("SeedTierDefinitions")
check("max tier is 5", SeedTierDefinitions.MaxTier == 5)
check("tier 1 grows in 30s", (SeedTierDefinitions.get(1) :: any).GrowDuration == 30)
check("tier 5 base value 3000", (SeedTierDefinitions.get(5) :: any).BaseSellValue == 3000)
check("tier 1 always unlocked", SeedTierDefinitions.isUnlocked(1, 0, 0))
check(
	"tier 2 needs 100 lifetime",
	not SeedTierDefinitions.isUnlocked(2, 99, 0) and SeedTierDefinitions.isUnlocked(2, 100, 0)
)
check("tier 5 unlocks on first rebirth", SeedTierDefinitions.isUnlocked(5, 0, 1))
check("tier 5 unlocks at 15000 lifetime", SeedTierDefinitions.isUnlocked(5, 15000, 0))

-- ── MutationDefinitions ───────────────────────────────────────────────────
print("MutationDefinitions")
check("weights total 100", approx(MutationDefinitions.totalWeight(), 100))
check("Normal exists with 1x", (MutationDefinitions.get("Normal") :: any).ValueMultiplier == 1)
check("Glitched is 25x", (MutationDefinitions.get("Glitched") :: any).ValueMultiplier == 25)
check("five mutations defined", #MutationDefinitions.List == 5)

-- ── CreatureDefinitions ───────────────────────────────────────────────────
print("CreatureDefinitions")
check("nine creatures defined", #CreatureDefinitions.List == 9)
check("tier 1 has 3 creatures", #CreatureDefinitions.getByTier(1) == 3)
check("tier 5 has 1 creature", #CreatureDefinitions.getByTier(5) == 1)
do
	local seen = {}
	local uniqueIds = true
	local validStageColors = true
	local positiveWeights = true
	for _, c in CreatureDefinitions.List do
		if seen[c.Id] then
			uniqueIds = false
		end
		seen[c.Id] = true
		if #c.StageColors ~= 4 then
			validStageColors = false
		end
		if c.BaseWeight <= 0 then
			positiveWeights = false
		end
	end
	check("creature ids are unique", uniqueIds)
	check("each creature has 4 stage colors", validStageColors)
	check("creature weights are positive", positiveWeights)
end

-- ── WeightedRandom ────────────────────────────────────────────────────────
print("WeightedRandom")
do
	local items = { { Weight = 1 }, { Weight = 1 }, { Weight = 8 } }
	local getW = function(i: { Weight: number })
		return i.Weight
	end
	check("total weight sums", WeightedRandom.totalWeight(items, getW) == 10)
	local _, firstIndex = WeightedRandom.choose(items, getW, function()
		return 0
	end)
	check("rng 0 picks first", firstIndex == 1)
	local _, lastIndex = WeightedRandom.choose(items, getW, function()
		return 0.999999
	end)
	check("rng ~1 picks last", lastIndex == 3)
	local _, midIndex = WeightedRandom.choose(items, getW, function()
		return 0.5
	end)
	check("rng 0.5 lands in heavy bucket", midIndex == 3)
end

-- ── TableUtility ──────────────────────────────────────────────────────────
print("TableUtility")
do
	local original = { a = 1, nested = { b = 2 } }
	local copy = TableUtility.deepCopy(original)
	copy.nested.b = 99
	check("deepCopy is independent", original.nested.b == 2)

	local data = { Coins = 5 }
	local changed = TableUtility.reconcile(data, { Coins = 0, Rebirths = 0, Nested = { X = 1 } })
	check("reconcile fills missing keys", data.Rebirths == 0 and (data :: any).Nested.X == 1)
	check("reconcile reports change", changed == true)
	check("reconcile keeps existing", data.Coins == 5)

	local merged = TableUtility.merge({ a = 1, b = 2 }, { b = 3 })
	check("merge overrides", merged.a == 1 and merged.b == 3)
end

-- ── TimeUtility ───────────────────────────────────────────────────────────
print("TimeUtility")
check("isReady true at readyAt", TimeUtility.isReady(100, 100))
check("isReady false before", not TimeUtility.isReady(100, 99))
check("remaining clamps to 0", TimeUtility.remaining(100, 150) == 0)
check("remaining counts down", TimeUtility.remaining(100, 60) == 40)
check("format seconds", TimeUtility.format(45) == "45s")
check("format minutes", TimeUtility.format(95) == "1m 35s")
check("format hours", TimeUtility.format(3600) == "1h 0m")

-- ── summary ───────────────────────────────────────────────────────────────
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end
process.exit(0)
