--!strict
-- AdminService — Studio-only test commands (§27). TRACK A. STUB.
--
-- Allowed ONLY in Studio (RunService:IsStudio()) AND for AdminConfig.AdminUserIds.
-- NEVER execute arbitrary Luau. Log every admin action.
-- Commands: give coins, set lifetime coins, unlock tier, buy all slots, force
-- crop ready, spawn creature/mutation, reset tutorial, trigger rebirth eligibility,
-- print profile, force save, clear/rebuild plot, simulate failed data load (dev).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("Config"):WaitForChild("AdminConfig"))

local AdminService = {}
AdminService.Name = "AdminService"

function AdminService.canUse(userId: number): boolean
	if not RunService:IsStudio() and not AdminConfig.AllowInLiveServers then
		return false
	end
	return AdminConfig.isAdmin(userId)
end

function AdminService.Init()
	-- TODO(Track A): register a guarded command channel (chat command or bindable).
end

function AdminService.Start() end

return AdminService
