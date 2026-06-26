--!strict
-- FarmService — the core plant/harvest loop + remote handlers (§5, §17).
-- TRACK A. The heart of the server: validates every PlantSeed and HarvestSlot
-- request and rolls creature/mutation on the server.
--
-- PlantSeed validation (§17): data loaded; owns plot; slot index integer in
--   1..UnlockedSlots; slot empty; seed tier exists + unlocked; can afford; not
--   rate-limited; tutorial allows it. Then: deduct cost, roll creature (weighted
--   within tier via WeightedRandom), roll mutation, compute ReadyAt, store slot,
--   mark dirty, replicate sanitized slot.
-- HarvestSlot validation (§17): valid slot; owned; has crop; now >= ReadyAt;
--   not already harvested; valid defs; not rate-limited. Then: compute payout via
--   EconomyConfig.computePayout, add coins + lifetime, update stats, check unlocks,
--   clear slot, mark dirty, trigger effects, replicate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local SeedTierDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("SeedTierDefinitions"))
local CreatureDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("CreatureDefinitions"))
local MutationDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("MutationDefinitions"))
local WeightedRandom = require(Shared:WaitForChild("Utility"):WaitForChild("WeightedRandom"))
local TableUtility = require(Shared:WaitForChild("Utility"):WaitForChild("TableUtility"))
local Types = require(Shared:WaitForChild("Types"))

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local Utility = Server:WaitForChild("Utility")

local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local GrowthService = require(Services:WaitForChild("GrowthService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local WorldService = require(Services:WaitForChild("WorldService"))

local RemoteValidator = require(Utility:WaitForChild("RemoteValidator"))
local RateLimiterModule = require(Utility:WaitForChild("RateLimiter"))

-- CreatureModelFactory (Track C) — we only CALL it.
local CreatureModelFactory =
	require(Server:WaitForChild("Factories"):WaitForChild("CreatureModelFactory"))

local FarmService = {}
FarmService.Name = "FarmService"

local limiter = RateLimiterModule.new()

-- ── Helpers ─────────────────────────────────────────────────────────────────
local function fireSlotUpdated(player: Player, slotIndex: number, slot: Types.FarmSlot?)
	local sanitized: Types.FarmSlot? = nil
	if slot and slot.SeedTierId then
		sanitized = TableUtility.deepCopy(slot)
	end
	Remotes.Events[Constants.Remotes.SlotUpdated]:FireClient(player, slotIndex, sanitized)
end

local function fireEffect(player: Player, payload: Types.EffectPayload)
	Remotes.Events[Constants.Remotes.PlayEffect]:FireClient(player, payload)
end

local function notify(player: Player, text: string, level: number)
	Remotes.Events[Constants.Remotes.Notification]:FireClient(player, text, level)
end

-- Resolve the slot anchor BasePart via the World seam (Track C), or nil.
local function getSlotAnchor(userId: number, slotIndex: number): BasePart?
	local plotId = PlotService.getPlotId(userId)
	if not plotId then
		return nil
	end
	local anchor: BasePart? = nil
	pcall(function()
		anchor = WorldService.getSlotAnchor(plotId, slotIndex)
	end)
	return anchor
end

-- Spawn (or respawn) the server-authoritative creature model on the slot anchor so
-- it replicates (§4). Track C's CreatureModelFactory.spawnAt pins + cleans up.
-- Best-effort; never errors the gameplay path.
local function spawnCreatureModel(
	userId: number,
	slotIndex: number,
	creatureId: string,
	mutationId: string
)
	local anchor = getSlotAnchor(userId, slotIndex)
	if not anchor then
		return
	end
	pcall(function()
		CreatureModelFactory.spawnAt(anchor, creatureId, mutationId, 0)
	end)
end

local function removeCreatureModel(userId: number, slotIndex: number)
	local anchor = getSlotAnchor(userId, slotIndex)
	if not anchor then
		return
	end
	pcall(function()
		-- The factory names spawned models "CreatureModel" and parents them on the
		-- anchor; clear it the same way the world does.
		for _, child in anchor:GetChildren() do
			if child:IsA("Model") and child.Name == "CreatureModel" then
				child:Destroy()
			end
		end
	end)
end

-- ── Plant ─────────────────────────────────────────────────────────────────────
function FarmService.plant(player: Player, slotIndex: number, seedTier: number): (boolean, string?)
	local userId = player.UserId

	local data = PlayerDataService.get(userId)
	if not data then
		return false, "no_data"
	end

	-- Shape/range (slot bounded by UnlockedSlots, tier by MaxTier).
	if
		not RemoteValidator.validatePlant(
			slotIndex,
			seedTier,
			data.UnlockedSlots,
			SeedTierDefinitions.MaxTier
		)
	then
		return false, "bad_args"
	end

	-- Ownership.
	if not PlotService.ownsSlot(userId, slotIndex) then
		return false, "not_owned"
	end

	-- Tutorial gating.
	if not TutorialService.allowsAction(player, "Plant") then
		return false, "tutorial_locked"
	end

	-- Slot must be empty.
	local slot = data.Slots[slotIndex]
	if slot and slot.SeedTierId ~= nil then
		return false, "slot_occupied"
	end

	-- Tutorial forces the first plant: guaranteed Common, Tier 1, free, tutorial dur.
	local isGuaranteed = TutorialService.isGuaranteedPlantStep(userId)
	local effectiveTier = seedTier
	if isGuaranteed then
		effectiveTier = 1
	end

	local tierDef = SeedTierDefinitions.get(effectiveTier)
	if not tierDef then
		return false, "bad_tier"
	end

	-- Tier must be unlocked (skip the check for the guaranteed tutorial Tier 1).
	if
		not isGuaranteed
		and not SeedTierDefinitions.isUnlocked(effectiveTier, data.LifetimeCoins, data.Rebirths)
	then
		return false, "tier_locked"
	end

	-- Affordability (tutorial egg is free).
	local cost = if isGuaranteed then 0 else tierDef.SeedCost
	if cost > 0 then
		if not EconomyService.trySpend(userId, cost) then
			return false, "cannot_afford"
		end
	end

	-- Roll the creature (weighted within tier). The guaranteed tutorial crop is PINNED
	-- to a fixed Common (candidates[1]) so the first reveal is consistent for everyone.
	local candidates = CreatureDefinitions.getByTier(effectiveTier)
	if #candidates == 0 then
		-- Refund and abort if a tier somehow has no creatures.
		if cost > 0 then
			EconomyService.addCoins(userId, cost, false)
		end
		return false, "no_creatures"
	end
	local creature = if isGuaranteed
		then candidates[1]
		else (WeightedRandom.choose(candidates, function(c)
			return c.BaseWeight
		end))

	-- Roll the mutation (no mutation luck on the tutorial crop → forced Normal).
	local mutationId = "Normal"
	if not isGuaranteed then
		local mutation = WeightedRandom.choose(MutationDefinitions.List, function(m)
			return m.Weight
		end)
		mutationId = mutation.Id
	end

	-- Combined speed multiplier at plant time (§18). 2x pass affects future crops;
	-- the tutorial uses the fixed tutorial grow duration.
	local ownership = PlayerDataService.getPasses(userId)
	local speedMult = GrowthService.computeSpeedMultiplier(ownership.DoubleGrowth)

	local plantedAt = os.time()
	local baseDuration = if isGuaranteed
		then EconomyConfig.TutorialGrowDuration
		else tierDef.GrowDuration
	local readyAt = GrowthService.computeReadyAt(plantedAt, baseDuration, speedMult)

	local newSlot: Types.FarmSlot = {
		SeedTierId = effectiveTier,
		CreatureId = creature.Id,
		MutationId = mutationId,
		PlantedAt = plantedAt,
		ReadyAt = readyAt,
		GrowthSpeedMultiplier = speedMult,
	}
	data.Slots[slotIndex] = newSlot
	data.Statistics.TotalPlanted += 1
	PlayerDataService.markDirty(userId)

	-- Spawn the (server-owned) model so it replicates; the client animates stages.
	spawnCreatureModel(userId, slotIndex, creature.Id, mutationId)

	-- Replicate this one slot + the plant juice.
	fireSlotUpdated(player, slotIndex, newSlot)
	fireEffect(player, { Kind = Constants.Effects.Plant, SlotIndex = slotIndex })

	-- Tutorial progression.
	TutorialService.notifyPlanted(player, isGuaranteed)

	return true, nil
end

-- ── Harvest ─────────────────────────────────────────────────────────────────
-- Internal harvest used by both the remote handler and AutoCollectService.
-- `silent` suppresses the per-harvest replicate/effects bundle for batch use.
function FarmService.harvestInternal(player: Player, slotIndex: number): (boolean, number?)
	local userId = player.UserId

	local data = PlayerDataService.get(userId)
	if not data then
		return false, nil
	end

	if not RemoteValidator.validateSlotIndex(slotIndex, data.UnlockedSlots) then
		return false, nil
	end
	if not PlotService.ownsSlot(userId, slotIndex) then
		return false, nil
	end
	if not TutorialService.allowsAction(player, "Harvest") then
		return false, nil
	end

	local slot = data.Slots[slotIndex]
	if not slot or slot.SeedTierId == nil then
		return false, nil
	end
	if not slot.CreatureId or not slot.MutationId or not slot.ReadyAt or not slot.PlantedAt then
		return false, nil
	end

	-- Server-authoritative readiness from absolute timestamps (§9).
	if os.time() < slot.ReadyAt then
		return false, nil
	end

	local tierDef = SeedTierDefinitions.get(slot.SeedTierId)
	local creatureDef = CreatureDefinitions.get(slot.CreatureId)
	local mutationDef = MutationDefinitions.get(slot.MutationId)
	if not tierDef or not creatureDef or not mutationDef then
		-- Corrupt crop: clear it so the slot is recoverable, no payout.
		data.Slots[slotIndex] = {}
		PlayerDataService.markDirty(userId)
		fireSlotUpdated(player, slotIndex, nil)
		return false, nil
	end

	local ownership = PlayerDataService.getPasses(userId)
	-- The guaranteed tutorial crop pays a fixed reward (§6), not a rolled payout. Check
	-- BEFORE notifyHarvested advances the step out of PlantedTutorialCrop.
	local payout: number
	if TutorialService.isGuaranteedHarvestStep(userId) then
		payout = EconomyConfig.TutorialReward
	else
		payout = EconomyConfig.computePayout(
			tierDef.BaseSellValue,
			creatureDef.BaseValueMultiplier,
			mutationDef.ValueMultiplier,
			data.Rebirths,
			ownership.GoldenPlotVIP
		)
	end

	-- Apply economy (earn → bumps LifetimeCoins + re-checks unlocks).
	EconomyService.addCoins(userId, payout, true)

	-- Stats.
	data.Statistics.TotalHarvested += 1
	local rank = 0
	for index, m in MutationDefinitions.List do
		if m.Id == mutationDef.Id then
			rank = index - 1
			break
		end
	end
	if rank > data.Statistics.HighestMutationRank then
		data.Statistics.HighestMutationRank = rank
	end

	-- Clear the slot + remove the model.
	local creatureId = slot.CreatureId
	local mutationId = slot.MutationId
	data.Slots[slotIndex] = {}
	PlayerDataService.markDirty(userId)
	removeCreatureModel(userId, slotIndex)

	-- Replicate + juice.
	fireSlotUpdated(player, slotIndex, nil)
	fireEffect(player, {
		Kind = Constants.Effects.Harvest,
		SlotIndex = slotIndex,
		CreatureId = creatureId,
		MutationId = mutationId,
		Amount = payout,
	})

	-- Rare mutation reveal + (server-side) announcement.
	if mutationDef.AnnouncementLevel and mutationDef.AnnouncementLevel >= 1 then
		fireEffect(player, {
			Kind = Constants.Effects.Mutation,
			SlotIndex = slotIndex,
			MutationId = mutationId,
		})
		if mutationDef.RevealMessage ~= "" then
			notify(player, mutationDef.RevealMessage, mutationDef.AnnouncementLevel)
		end
	end

	-- Tutorial progression + full snapshot refresh.
	TutorialService.notifyHarvested(player)
	PlayerDataService.replicate(player)

	return true, payout
end

function FarmService.harvest(player: Player, slotIndex: number): (boolean, number?)
	return FarmService.harvestInternal(player, slotIndex)
end

-- ── Remote wiring ──────────────────────────────────────────────────────────
function FarmService.Init()
	Remotes.Events[Constants.Remotes.PlantSeed].OnServerEvent:Connect(
		function(player, slotIndex, seedTier)
			local key = `{player.UserId}:PlantSeed`
			if not limiter:allow(key, Constants.RateLimits.PlantSeed) then
				return
			end
			-- Coarse arg-type guard before any data access.
			if type(slotIndex) ~= "number" or type(seedTier) ~= "number" then
				return
			end
			local ok, err = FarmService.plant(player, slotIndex, seedTier)
			if not ok and err and err ~= "bad_args" then
				notify(player, "Could not plant: " .. err, 0)
			end
		end
	)

	Remotes.Events[Constants.Remotes.HarvestSlot].OnServerEvent:Connect(function(player, slotIndex)
		local key = `{player.UserId}:HarvestSlot`
		if not limiter:allow(key, Constants.RateLimits.HarvestSlot) then
			return
		end
		if type(slotIndex) ~= "number" then
			return
		end
		FarmService.harvest(player, slotIndex)
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiter:clear(tostring(player.UserId))
	end)
end

function FarmService.Start() end

return FarmService
