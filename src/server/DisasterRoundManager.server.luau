--!strict
-- DisasterRoundManager.server.luau
-- Inspired by roblox-game-skill GameManager lifecycle pattern
-- Orchestrates round loop: Intermission -> Tornado Warning -> Active Storm -> Survival Evaluation

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

export type RoundState = "Intermission" | "Warning" | "ActiveStorm" | "PostStorm"

local currentState: RoundState = "Intermission"
local stateTimeRemaining = 15

local function setState(newState: RoundState, duration: number, alertMsg: string?)
	currentState = newState
	stateTimeRemaining = duration

	if alertMsg then
		Network.StormAlert:FireAllClients(alertMsg, duration)
	end
	Network.RoundStateChanged:FireAllClients(newState, duration)

	if newState == "Warning" then
		Network.SirenState:FireAllClients(true)
	elseif newState == "Intermission" or newState == "PostStorm" then
		Network.SirenState:FireAllClients(false)
	end
end

-- Reward survivors when storm ends
local function awardSurvivors()
	local survivors = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				table.insert(survivors, player.Name)
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local cash = leaderstats:FindFirstChild("ResearchPoints") or leaderstats:FindFirstChild("Cash")
					if cash and cash:IsA("IntValue") then
						cash.Value += 75
					end
					local survived = leaderstats:FindFirstChild("Survivals")
					if survived and survived:IsA("IntValue") then
						survived.Value += 1
					end
				end
			end
		end
	end

	if #survivors > 0 then
		Network.StormAlert:FireAllClients(`🏆 STORM PASSED! {#survivors} survivors awarded +75 Research Points!`, 8)
	else
		Network.StormAlert:FireAllClients("💨 The storm claimed all chasers. Prepare for the next wave!", 8)
	end
end

-- Main Round Loop
task.spawn(function()
	task.wait(2)
	while true do
		-- 1. Intermission
		setState("Intermission", 15, "🌤️ INTERMISSION: Prepare gear & scout vehicles at the depot!")
		while stateTimeRemaining > 0 do
			task.wait(1)
			stateTimeRemaining -= 1
		end

		-- 2. Severe Storm Warning
		setState("Warning", 10, "🚨 TORNADO WARNING: Doppler radar detects severe mesocyclone rotation!")
		while stateTimeRemaining > 0 do
			task.wait(1)
			stateTimeRemaining -= 1
		end

		-- 3. Active Storm Phase
		setState("ActiveStorm", 80, "🌪️ EF5 WEDGE TOUCHDOWN! Seek reinforced shelter or chase for science!")
		while stateTimeRemaining > 0 do
			task.wait(1)
			stateTimeRemaining -= 1
		end

		-- 4. Post-Storm / Payout
		setState("PostStorm", 10)
		awardSurvivors()
		while stateTimeRemaining > 0 do
			task.wait(1)
			stateTimeRemaining -= 1
		end
	end
end)

print("[DisasterRoundManager] Automated disaster round cycle initialized.")
