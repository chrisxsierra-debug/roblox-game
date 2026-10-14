--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ProfileService = require(Packages:WaitForChild("ProfileService"))

local ProfileTemplate = {
	ResearchTokens = 50,
	StormsSurvived = 0,
	ProbesDeployed = 0,
	ChaserRank = "Novice Spotter",
}

local ProfileStore = ProfileService.GetProfileStore("StormChaser_v1", ProfileTemplate)
local Profiles = {}

local function initializeLeaderstats(player: Player, data: typeof(ProfileTemplate))
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local tokens = Instance.new("IntValue")
	tokens.Name = "Tokens"
	tokens.Value = data.ResearchTokens
	tokens.Parent = leaderstats

	local storms = Instance.new("IntValue")
	storms.Name = "Storms"
	storms.Value = data.StormsSurvived
	storms.Parent = leaderstats

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Value = data.ChaserRank
	rank.Parent = leaderstats
end

local function onPlayerAdded(player: Player)
	local profileKey = "Chaser_" .. player.UserId
	local profile
	if RunService:IsStudio() then
		profile = ProfileStore.Mock:LoadProfileAsync(profileKey)
	else
		profile = ProfileStore:LoadProfileAsync(profileKey)
	end

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()
		profile:ListenToRelease(function()
			Profiles[player] = nil
			player:Kick("Profile loaded on another server.")
		end)

		if player:IsDescendantOf(Players) then
			Profiles[player] = profile
			initializeLeaderstats(player, profile.Data)
			print("[StormDataService] Loaded profile for chaser:", player.Name)
		else
			profile:Release()
		end
	else
		player:Kick("Failed to load storm chaser profile.")
	end
end

local function onPlayerRemoving(player: Player)
	local profile = Profiles[player]
	if profile ~= nil then
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats then
			local tokens = leaderstats:FindFirstChild("Tokens") :: IntValue
			local storms = leaderstats:FindFirstChild("Storms") :: IntValue
			if tokens then profile.Data.ResearchTokens = tokens.Value end
			if storms then profile.Data.StormsSurvived = storms.Value end
		end
		profile:Release()
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

