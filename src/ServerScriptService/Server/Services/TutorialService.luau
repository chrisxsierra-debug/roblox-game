--!strict
-- TutorialService — first-time onboarding (§6). TRACK A (logic) + TRACK B (UI).
--
-- Flow (persisted in PlayerData.Tutorial so it survives reconnect):
--   Step 0: welcome — guide the player to plant their first (tutorial) crop.
--   Step 1: tutorial crop planted — guaranteed Common, 15s grow, no mutation luck.
--   Step 2: tutorial crop harvested — +20 coins granted (handled by FarmService).
--   Step 3: planted a normal Tier 1 — introduce the slot shop.
--   Completed: tutorial done; all gating lifts.
-- No Robux prompts during the tutorial (enforced by MonetizationService checking
-- allowsAction / Completed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local PlayerDataService = require(Server:WaitForChild("Services"):WaitForChild("PlayerDataService"))

local TutorialService = {}
TutorialService.Name = "TutorialService"

-- Named steps (kept in sync with the persisted PlayerData.Tutorial.Step).
TutorialService.Steps = {
	Welcome = 0,
	PlantedTutorialCrop = 1,
	HarvestedTutorialCrop = 2,
	PlantedFirstReal = 3,
}

local PROMPTS: { [number]: string } = {
	[0] = "Welcome! Tap your first plot to plant a free egg.",
	[1] = "Nice! Watch it grow… it'll be ready in a few seconds.",
	[2] = "Harvest it to reveal your creature and earn coins!",
	[3] = "Plant another seed, then open the shop to unlock more slots.",
}

-- The tutorial crop is forced: a guaranteed Common (Tier 1) creature with no
-- mutation luck and the tutorial grow duration. FarmService asks for these.
function TutorialService.isTutorialActive(userId: number): boolean
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	return not data.Tutorial.Completed
end

-- True while the player is on the very first guaranteed-egg step (no mutation luck,
-- guaranteed Common, free, tutorial grow duration apply on THIS plant).
function TutorialService.isGuaranteedPlantStep(userId: number): boolean
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	return not data.Tutorial.Completed and data.Tutorial.Step == TutorialService.Steps.Welcome
end

-- Replicate the current tutorial state to the client (§16 TutorialUpdated).
function TutorialService.replicate(player: Player)
	local data = PlayerDataService.get(player.UserId)
	if not data then
		return
	end
	local step = data.Tutorial.Step
	local completed = data.Tutorial.Completed
	local prompt = if completed then nil else PROMPTS[step]
	Remotes.Events[Constants.Remotes.TutorialUpdated]:FireClient(player, step, completed, prompt)
end

-- Advance to a specific step (monotonic — never moves backwards), persisting +
-- replicating. Reaching past the last step completes the tutorial.
function TutorialService.advance(player: Player, toStep: number)
	local data = PlayerDataService.get(player.UserId)
	if not data then
		return
	end
	if data.Tutorial.Completed then
		return
	end
	if toStep <= data.Tutorial.Step and toStep ~= 0 then
		return
	end

	data.Tutorial.Step = toStep
	if toStep > TutorialService.Steps.PlantedFirstReal then
		data.Tutorial.Completed = true
	end
	PlayerDataService.markDirty(player.UserId)
	TutorialService.replicate(player)
end

-- Called by FarmService after a successful plant/harvest so the tutorial can step.
function TutorialService.notifyPlanted(player: Player, wasTutorialCrop: boolean)
	local data = PlayerDataService.get(player.UserId)
	if not data or data.Tutorial.Completed then
		return
	end
	if wasTutorialCrop and data.Tutorial.Step == TutorialService.Steps.Welcome then
		TutorialService.advance(player, TutorialService.Steps.PlantedTutorialCrop)
	elseif data.Tutorial.Step == TutorialService.Steps.HarvestedTutorialCrop then
		-- Planted a normal Tier 1 after the tutorial harvest → finish onboarding.
		TutorialService.advance(player, TutorialService.Steps.PlantedFirstReal + 1)
	end
end

function TutorialService.notifyHarvested(player: Player)
	local data = PlayerDataService.get(player.UserId)
	if not data or data.Tutorial.Completed then
		return
	end
	if data.Tutorial.Step == TutorialService.Steps.PlantedTutorialCrop then
		TutorialService.advance(player, TutorialService.Steps.HarvestedTutorialCrop)
	end
end

-- True if the given action is allowed in the player's current tutorial step.
-- Default-allow once the tutorial is completed (§6).
function TutorialService.allowsAction(player: Player, action: string): boolean
	local data = PlayerDataService.get(player.UserId)
	if not data then
		return false
	end
	if data.Tutorial.Completed then
		return true
	end

	local step = data.Tutorial.Step
	if action == "Plant" then
		-- Planting allowed at Welcome (the tutorial egg) and after the tutorial
		-- harvest (the first real plant). Disallowed while waiting to harvest.
		return step == TutorialService.Steps.Welcome
			or step == TutorialService.Steps.HarvestedTutorialCrop
	elseif action == "Harvest" then
		-- Harvest allowed once the tutorial crop is planted.
		return step >= TutorialService.Steps.PlantedTutorialCrop
	elseif action == "BuySlot" or action == "Rebirth" then
		-- Gated until the tutorial completes.
		return false
	end
	return true
end

local function onPlayerAdded(player: Player)
	local data = PlayerDataService.waitForData(player)
	if not data then
		return
	end
	if player.Parent ~= Players then
		return
	end
	TutorialService.replicate(player)
end

function TutorialService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function TutorialService.Start() end

return TutorialService
