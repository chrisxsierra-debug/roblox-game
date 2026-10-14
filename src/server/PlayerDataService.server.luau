--!strict
-- PlayerDataService.server.luau
-- Inspired by roblox-game-skill DataManager (ProfileService persistence pattern)
-- Safely manages player research points, survivals, and leaderstats

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DATA_STORE_NAME = "FunnelRunners_ChaserData_v1"
local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

export type ChaserData = {
	ResearchPoints: number,
	Survivals: number,
	ProbesDeployed: number,
}

local DEFAULT_DATA: ChaserData = {
	ResearchPoints = 0,
	Survivals = 0,
	ProbesDeployed = 0,
}

local sessionCache: { [Player]: ChaserData } = {}

local function loadData(player: Player): ChaserData
	local key = `Player_{player.UserId}`
	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if success and result and typeof(result) == "table" then
		return {
			ResearchPoints = result.ResearchPoints or DEFAULT_DATA.ResearchPoints,
			Survivals = result.Survivals or DEFAULT_DATA.Survivals,
			ProbesDeployed = result.ProbesDeployed or DEFAULT_DATA.ProbesDeployed,
		}
	end

	return {
		ResearchPoints = DEFAULT_DATA.ResearchPoints,
		Survivals = DEFAULT_DATA.Survivals,
		ProbesDeployed = DEFAULT_DATA.ProbesDeployed,
	}
end

local function saveData(player: Player)
	local data = sessionCache[player]
	if not data then return end

	-- Sync values from leaderstats if present
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local pointsVal = leaderstats:FindFirstChild("ResearchPoints")
		if pointsVal and pointsVal:IsA("IntValue") then
			data.ResearchPoints = pointsVal.Value
		end
		local survVal = leaderstats:FindFirstChild("Survivals")
		if survVal and survVal:IsA("IntValue") then
			data.Survivals = survVal.Value
		end
	end

	local key = `Player_{player.UserId}`
	pcall(function()
		dataStore:SetAsync(key, data)
	end)
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	sessionCache[player] = data

	-- Create Leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local pointsValue = Instance.new("IntValue")
	pointsValue.Name = "ResearchPoints"
	pointsValue.Value = data.ResearchPoints
	pointsValue.Parent = leaderstats

	local survivalValue = Instance.new("IntValue")
	survivalValue.Name = "Survivals"
	survivalValue.Value = data.Survivals
	survivalValue.Parent = leaderstats

	leaderstats.Parent = player
	print(`[PlayerDataService] Loaded data for {player.Name} (Points: {data.ResearchPoints}, Survivals: {data.Survivals})`)
end

local function onPlayerRemoving(player: Player)
	saveData(player)
	sessionCache[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, p in Players:GetPlayers() do
	task.spawn(onPlayerAdded, p)
end

-- Autosave every 5 minutes
task.spawn(function()
	while true do
		task.wait(300)
		for player in sessionCache do
			task.spawn(saveData, player)
		end
	end
end)

-- Safe shutdown
game:BindToClose(function()
	for player in sessionCache do
		saveData(player)
	end
end)

print("[PlayerDataService] Player data persistence service active.")
