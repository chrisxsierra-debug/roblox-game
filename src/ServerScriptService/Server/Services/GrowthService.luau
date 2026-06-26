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

local GrowthService = {}
GrowthService.Name = "GrowthService"

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
