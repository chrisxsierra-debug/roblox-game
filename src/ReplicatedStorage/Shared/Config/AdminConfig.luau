--!strict
-- AdminConfig — who may run the Studio-only admin commands (§27).
-- Admin commands only run in Studio AND for these UserIds. Never arbitrary Luau.

local AdminConfig = {}

-- Add teammate UserIds here. Example: { 1234567, 7654321 }
AdminConfig.AdminUserIds = {} :: { number }

-- When true, admin commands are also allowed in a live (non-Studio) server for
-- the listed UserIds. Keep false for production safety.
AdminConfig.AllowInLiveServers = false

function AdminConfig.isAdmin(userId: number): boolean
	for _, id in AdminConfig.AdminUserIds do
		if id == userId then
			return true
		end
	end
	return false
end

return AdminConfig
