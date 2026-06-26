--!strict
-- AutoCollectService — auto-harvest for the Auto-Collect pass (§23, §29). TRACK A.
--
-- Runs ONE central loop every GameConfig.AutoCollectIntervalSeconds (NOT per crop).
-- For each online player who owns the pass, harvest any ready crops via FarmService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local FarmService = require(Services:WaitForChild("FarmService"))

local AutoCollectService = {}
AutoCollectService.Name = "AutoCollectService"

local running = false

local function tick()
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		if not PlayerDataService.isLoaded(userId) then
			continue
		end
		-- Pass ownership is read from the transient cache (set by MonetizationService).
		local ownership = PlayerDataService.getPasses(userId)
		if not ownership.AutoCollect then
			continue
		end

		local data = PlayerDataService.get(userId)
		if not data then
			continue
		end

		local now = os.time()
		for slotIndex = 1, data.UnlockedSlots do
			local slot = data.Slots[slotIndex]
			if slot and slot.SeedTierId ~= nil and slot.ReadyAt and now >= slot.ReadyAt then
				-- FarmService re-validates ownership/readiness; safe to call directly.
				FarmService.harvestInternal(player, slotIndex)
			end
		end
	end
end

function AutoCollectService.Init() end

function AutoCollectService.Start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while running do
			task.wait(GameConfig.AutoCollectIntervalSeconds)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[AutoCollectService] tick errored: {err}`)
			end
		end
	end)
end

return AutoCollectService
