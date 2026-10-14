--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Zone = require(Packages:WaitForChild("ZonePlus"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))
local Config = require(Shared:WaitForChild("FunnelRunnersConfig"))

local function initializeBunkerZone()
	local bunkerParts = CollectionService:GetTagged("StormBunker")
	for _, part in bunkerParts do
		if part:IsA("BasePart") then
			local zone = Zone.new(part)

			zone.playerEntered:Connect(function(player: Player)
				local char = player.Character
				if char then
					char:SetAttribute("IsSheltered", true)
					Network.BunkerShelterState:FireClient(player, true)

					local leaderstats = player:FindFirstChild("leaderstats")
					if leaderstats then
						local stormsVal = leaderstats:FindFirstChild("Storms") :: IntValue
						local tokensVal = leaderstats:FindFirstChild("Tokens") :: IntValue
						if stormsVal then stormsVal.Value += 1 end
						if tokensVal then tokensVal.Value += 100 end
					end
					print(string.format("[BunkerService] %s entered Underground Shelter. Status: 100%% SAFE.", player.Name))
				end
			end)

			zone.playerExited:Connect(function(player: Player)
				local char = player.Character
				if char then
					char:SetAttribute("IsSheltered", false)
					Network.BunkerShelterState:FireClient(player, false)
					print(string.format("[BunkerService] %s exited shelter. Status: EXPOSED TO SEVERE WEATHER.", player.Name))
				end
			end)
		end
	end
end

task.defer(initializeBunkerZone)
