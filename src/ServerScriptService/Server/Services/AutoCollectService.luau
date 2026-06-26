--!strict
-- AutoCollectService — auto-harvest for the Auto-Collect pass (§23, §29). TRACK A. STUB.
--
-- Runs ONE central loop every GameConfig.AutoCollectIntervalSeconds (NOT per crop).
-- For each online player who owns the pass, harvest any ready crops via FarmService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local AutoCollectService = {}
AutoCollectService.Name = "AutoCollectService"

function AutoCollectService.Init() end

function AutoCollectService.Start()
	-- TODO(Track A): single task.spawn loop on GameConfig.AutoCollectIntervalSeconds.
	local _ = GameConfig.AutoCollectIntervalSeconds
end

return AutoCollectService
