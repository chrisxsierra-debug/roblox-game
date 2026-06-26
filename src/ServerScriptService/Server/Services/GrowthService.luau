--!strict
-- GrowthService — server-authoritative growth timing + visual staging (§9, §18, §29).
-- TRACK A.
--
-- Responsibilities:
--   * computeSpeedMultiplier / computeReadyAt: set ReadyAt = PlantedAt + duration at
--     PLANT time (the 2x pass affects only future crops; stored per-slot).
--   * getStageIndex: pure stage math (0..GrowthStageCount-1) from absolute timestamps.
--   * A SINGLE central sweep (§29 — never one loop per crop) advances each growing
--     creature's model through its visual stages and fires the Ready effect once.
-- Readiness for HARVEST is decided by FarmService from timestamps; this service only
-- drives cosmetics (the model + the Ready glow), so it is never authoritative for coins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local WorldService = require(Services:WaitForChild("WorldService"))
local CreatureModelFactory =
	require(Server:WaitForChild("Factories"):WaitForChild("CreatureModelFactory"))

local GrowthService = {}
GrowthService.Name = "GrowthService"

local FINAL_STAGE = GameConfig.GrowthStageCount - 1
local SWEEP_INTERVAL = 2 -- seconds; stages last several seconds even at Tier 1 (30s/4)

-- Compute the combined growth-speed multiplier applied at PLANT time (§18):
--   the 2x Growth pass (if owned). The tutorial uses a fixed grow duration instead
--   of a multiplier, and fertilizer (a future per-crop reduction) is applied later,
--   so neither is folded in here. Stored per-slot so the pass only affects new crops.
function GrowthService.computeSpeedMultiplier(hasDoubleGrowth: boolean): number
	local mult = 1
	if hasDoubleGrowth then
		mult *= MonetizationConfig.GamePasses.DoubleGrowth.GrowthMultiplier
	end
	return mult
end

-- Absolute ReadyAt for a crop planted at `plantedAt`, given the seed's base grow
-- duration and the (already-combined) speed multiplier. The duration is clamped to
-- OfflineGrowthCapSeconds — the max supported grow duration (§15); a no-op for the
-- current tiers (all < 8h) but it enforces the ceiling for future content.
function GrowthService.computeReadyAt(
	plantedAt: number,
	baseDuration: number,
	speedMultiplier: number
): number
	local duration = EconomyConfig.getGrowthDuration(baseDuration, speedMultiplier)
	duration = math.min(duration, EconomyConfig.OfflineGrowthCapSeconds)
	return plantedAt + math.floor(duration + 0.5)
end

-- Cosmetic stage index for a crop, based on absolute time (§9).
-- 0 = Egg ... (GrowthStageCount-1) = Full.
function GrowthService.getStageIndex(plantedAt: number, readyAt: number, now: number): number
	if now >= readyAt then
		return FINAL_STAGE
	end
	local total = math.max(1, readyAt - plantedAt)
	local elapsed = math.clamp(now - plantedAt, 0, total)
	local fraction = elapsed / total
	return math.floor(fraction * FINAL_STAGE)
end

-- ── Central visual-staging sweep ────────────────────────────────────────────
-- userId -> slotIndex -> { plantedAt, stage } we last applied to the 3D model.
local tracked: { [number]: { [number]: { plantedAt: number, stage: number } } } = {}

local function fireReady(player: Player, slotIndex: number)
	local payload: Types.EffectPayload = { Kind = Constants.Effects.Ready, SlotIndex = slotIndex }
	Remotes.Events[Constants.Remotes.PlayEffect]:FireClient(player, payload)
end

local function setModelStage(plotId: number, slotIndex: number, stage: number)
	pcall(function()
		local anchor = WorldService.getSlotAnchor(plotId, slotIndex)
		if not anchor then
			return
		end
		local model = anchor:FindFirstChild("CreatureModel")
		if model and model:IsA("Model") then
			CreatureModelFactory.updateStage(model, stage)
		end
	end)
end

local function sweepPlayer(player: Player)
	local userId = player.UserId
	local data = PlayerDataService.get(userId)
	if not data then
		return
	end
	local plotId = PlotService.getPlotId(userId)
	if not plotId then
		return
	end

	local bySlot = tracked[userId]
	if not bySlot then
		bySlot = {}
		tracked[userId] = bySlot
	end

	local now = os.time()
	for slotIndex = 1, data.UnlockedSlots do
		local slot = data.Slots[slotIndex]
		if not slot or slot.SeedTierId == nil or not slot.PlantedAt or not slot.ReadyAt then
			bySlot[slotIndex] = nil -- empty/cleared slot: forget tracking
		else
			local stage = GrowthService.getStageIndex(slot.PlantedAt, slot.ReadyAt, now)
			local record = bySlot[slotIndex]
			if not record or record.plantedAt ~= slot.PlantedAt then
				-- New (or replanted) crop: sync the model and arm Ready detection.
				setModelStage(plotId, slotIndex, stage)
				bySlot[slotIndex] = { plantedAt = slot.PlantedAt, stage = stage }
				if stage >= FINAL_STAGE then
					fireReady(player, slotIndex)
				end
			elseif stage > record.stage then
				setModelStage(plotId, slotIndex, stage)
				if stage >= FINAL_STAGE and record.stage < FINAL_STAGE then
					fireReady(player, slotIndex)
				end
				record.stage = stage
			end
		end
	end
end

function GrowthService.Init()
	Players.PlayerRemoving:Connect(function(player)
		tracked[player.UserId] = nil
	end)
end

function GrowthService.Start()
	task.spawn(function()
		while true do
			task.wait(SWEEP_INTERVAL)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(sweepPlayer, player)
				if not ok then
					warn(`[GrowthService] sweep errored for {player.Name}: {err}`)
				end
			end
		end
	end)
end

return GrowthService
