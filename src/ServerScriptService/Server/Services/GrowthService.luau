--!strict
-- GrowthService — server-authoritative growth timing (§9, §18).
-- TRACK A. STUB.
--
-- Responsibilities:
--   * On plant: compute combined growth-speed multiplier (tutorial / 2x pass /
--     fertilizer) and set ReadyAt = PlantedAt + EconomyConfig.getGrowthDuration(...).
--   * Determine readiness from timestamps ONLY (never per-crop loops, §29).
--   * Provide stage index (0..GrowthStageCount-1) for cosmetic replication.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))

local GrowthService = {}
GrowthService.Name = "GrowthService"

-- Compute the combined growth-speed multiplier applied at PLANT time (§18):
--   tutorial accelerator (if the tutorial crop is active) × 2x pass (if owned).
-- The 2x pass affects only FUTURE crops, which is why the multiplier is stored in
-- the slot at plant time (callers persist GrowthService → slot.GrowthSpeedMultiplier).
function GrowthService.computeSpeedMultiplier(hasDoubleGrowth: boolean): number
	local mult = 1
	if hasDoubleGrowth then
		mult *= MonetizationConfig.GamePasses.DoubleGrowth.GrowthMultiplier
	end
	return mult
end

-- Absolute ReadyAt for a crop planted at `plantedAt`, given the seed's base grow
-- duration and the (already-combined) speed multiplier. Uses EconomyConfig so all
-- the math stays in the single source of truth.
function GrowthService.computeReadyAt(
	plantedAt: number,
	baseDuration: number,
	speedMultiplier: number
): number
	local duration = EconomyConfig.getGrowthDuration(baseDuration, speedMultiplier)
	return plantedAt + math.floor(duration + 0.5)
end

-- Cosmetic stage index for a crop, based on absolute time (§9).
-- 0 = Egg ... (GrowthStageCount-1) = Full.
function GrowthService.getStageIndex(plantedAt: number, readyAt: number, now: number): number
	if now >= readyAt then
		return GameConfig.GrowthStageCount - 1
	end
	local total = math.max(1, readyAt - plantedAt)
	local elapsed = math.clamp(now - plantedAt, 0, total)
	local fraction = elapsed / total
	return math.floor(fraction * (GameConfig.GrowthStageCount - 1))
end

function GrowthService.Init() end
function GrowthService.Start() end

return GrowthService
