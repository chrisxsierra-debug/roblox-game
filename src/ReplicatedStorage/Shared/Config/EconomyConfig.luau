--!strict
-- EconomyConfig — the single source of truth for every economy/progression number.
--
-- IMPORTANT: this module is intentionally DEPENDENCY-FREE (it `require`s nothing and
-- touches no Roblox-only globals) so it can be unit-tested with Lune outside Studio.
-- Seed-tier numbers live in Definitions/SeedTierDefinitions; the formulas here take
-- their inputs as parameters so this module never has to require that one.
--
-- Owner of CONSUMING this config: Track A (server economy/rebirth) + Track B (UI display).
-- See TASK_SPLIT.md.

local EconomyConfig = {}

-- ── Starting profile (§10) ────────────────────────────────────────────────
EconomyConfig.StartingCoins = 20
EconomyConfig.StartingSlots = 2
EconomyConfig.MaxSlots = 12
EconomyConfig.StartingSeedTier = 1
EconomyConfig.StartingRebirths = 0

-- ── Multipliers (§10) ─────────────────────────────────────────────────────
EconomyConfig.RebirthMultiplierPerLevel = 0.5 -- income = 1 + rebirths * 0.5
EconomyConfig.VIPIncomeMultiplier = 1.15 -- Golden Plot VIP; applied at most ONCE

-- ── Rebirth (§10) ─────────────────────────────────────────────────────────
EconomyConfig.RebirthBaseRequirement = 10000 -- requirement = 10000 * (rebirths + 1)^2
EconomyConfig.RebirthResetCoins = 20
EconomyConfig.RebirthResetSlots = 2

-- ── Offline growth (§15) ──────────────────────────────────────────────────
EconomyConfig.OfflineGrowthCapSeconds = 8 * 60 * 60 -- 8 hours

-- ── Tutorial (§6) ─────────────────────────────────────────────────────────
EconomyConfig.TutorialGrowDuration = 15 -- seconds, guaranteed Common
EconomyConfig.TutorialReward = 20 -- coins from the first guaranteed harvest

-- ── Slot costs (§10) ──────────────────────────────────────────────────────
-- Slots 1 and 2 are free. This array is the cost to buy slot N for N = 3..12,
-- indexed as SlotCosts[N - 2].
EconomyConfig.SlotCosts = {
	50, -- slot 3
	150, -- slot 4
	400, -- slot 5
	1000, -- slot 6
	2500, -- slot 7
	6000, -- slot 8
	15000, -- slot 9
	35000, -- slot 10
	80000, -- slot 11
	175000, -- slot 12
}

-- ── Pure helper functions ─────────────────────────────────────────────────

-- Cost in Coins to unlock `slotIndex` (1-based). Free slots return 0.
-- Returns nil if the slot index is out of the supported 1..MaxSlots range.
function EconomyConfig.getSlotCost(slotIndex: number): number?
	if slotIndex <= EconomyConfig.StartingSlots then
		return 0
	end
	if slotIndex > EconomyConfig.MaxSlots then
		return nil
	end
	return EconomyConfig.SlotCosts[slotIndex - EconomyConfig.StartingSlots]
end

-- Permanent income multiplier from rebirths: 1 + rebirths * 0.5
function EconomyConfig.getIncomeMultiplier(rebirths: number): number
	return 1 + rebirths * EconomyConfig.RebirthMultiplierPerLevel
end

-- Current Coins required to perform the next rebirth: 10000 * (rebirths + 1)^2
function EconomyConfig.getRebirthRequirement(rebirths: number): number
	return EconomyConfig.RebirthBaseRequirement * (rebirths + 1) ^ 2
end

-- Adjusted grow duration after applying a combined growth-speed multiplier (§18).
function EconomyConfig.getGrowthDuration(baseDuration: number, speedMultiplier: number): number
	local mult = if speedMultiplier and speedMultiplier > 0 then speedMultiplier else 1
	return baseDuration / mult
end

-- Final harvest payout (§10):
--   base × creature × mutation × rebirthMultiplier × (VIP if owned)
-- Returns a floored integer number of Coins.
function EconomyConfig.computePayout(
	baseSellValue: number,
	creatureValueMultiplier: number,
	mutationValueMultiplier: number,
	rebirths: number,
	hasVIP: boolean
): number
	local total = baseSellValue
		* creatureValueMultiplier
		* mutationValueMultiplier
		* EconomyConfig.getIncomeMultiplier(rebirths)
	if hasVIP then
		total = total * EconomyConfig.VIPIncomeMultiplier
	end
	return math.floor(total)
end

return EconomyConfig
