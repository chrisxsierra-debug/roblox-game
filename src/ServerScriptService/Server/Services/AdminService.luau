--!strict
-- AdminService — Studio-only test commands (§27). TRACK A.
--
-- Allowed ONLY in Studio (RunService:IsStudio()) AND for AdminConfig.AdminUserIds
-- (or in a live server if AdminConfig.AllowInLiveServers). NEVER executes arbitrary
-- Luau — only a fixed, named command table. Every admin action is logged.
--
-- Commands (typed in chat, prefixed with "/bf "):
--   /bf givecoins <n>          add n coins (earned)
--   /bf setlifetime <n>        set LifetimeCoins (re-checks unlocks)
--   /bf unlocktier <t>         set HighestSeedTier to t
--   /bf buyallslots            unlock all slots (free)
--   /bf ready                  force all crops ready now
--   /bf resettutorial          clear tutorial progress
--   /bf rebirthready           set coins to the rebirth requirement
--   /bf profile                print the caller's profile to the server log
--   /bf save                   force a save

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AdminConfig = require(Shared:WaitForChild("Config"):WaitForChild("AdminConfig"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local SeedTierDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("SeedTierDefinitions"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))

local AdminService = {}
AdminService.Name = "AdminService"

local PREFIX = "/bf "

function AdminService.canUse(userId: number): boolean
	if not RunService:IsStudio() and not AdminConfig.AllowInLiveServers then
		return false
	end
	return AdminConfig.isAdmin(userId)
end

local function toNumber(arg: string?): number?
	if not arg then
		return nil
	end
	return tonumber(arg)
end

-- The fixed command table. Each handler receives (player, data, args).
local commands: { [string]: (Player, any, { string }) -> () } = {}

commands.givecoins = function(player, _data, args)
	local n = toNumber(args[1]) or 0
	EconomyService.addCoins(player.UserId, n, true)
	PlayerDataService.replicate(player)
end

commands.setlifetime = function(player, data, args)
	local n = toNumber(args[1])
	if n then
		data.LifetimeCoins = math.max(0, math.floor(n))
		EconomyService.refreshSeedUnlocks(player.UserId)
		PlayerDataService.markDirty(player.UserId)
		PlayerDataService.replicate(player)
	end
end

commands.unlocktier = function(player, data, args)
	local t = toNumber(args[1])
	if t then
		data.HighestSeedTier = math.clamp(math.floor(t), 1, SeedTierDefinitions.MaxTier)
		PlayerDataService.markDirty(player.UserId)
		PlayerDataService.replicate(player)
	end
end

commands.buyallslots = function(player, data, _args)
	for i = data.UnlockedSlots + 1, EconomyConfig.MaxSlots do
		data.Slots[i] = {}
	end
	data.UnlockedSlots = EconomyConfig.MaxSlots
	PlayerDataService.markDirty(player.UserId)
	PlayerDataService.replicate(player)
end

commands.ready = function(player, data, _args)
	local now = os.time()
	for i = 1, data.UnlockedSlots do
		local slot = data.Slots[i]
		if slot and slot.SeedTierId ~= nil then
			slot.ReadyAt = now
		end
	end
	PlayerDataService.markDirty(player.UserId)
	PlayerDataService.replicate(player)
end

commands.resettutorial = function(player, data, _args)
	data.Tutorial.Completed = false
	data.Tutorial.Step = 0
	PlayerDataService.markDirty(player.UserId)
	PlayerDataService.replicate(player)
end

commands.rebirthready = function(player, data, _args)
	data.Coins = EconomyConfig.getRebirthRequirement(data.Rebirths)
	PlayerDataService.markDirty(player.UserId)
	PlayerDataService.replicate(player)
end

commands.profile = function(_player, data, _args)
	print("[AdminService] profile:", data)
end

commands.save = function(player, _data, _args)
	PlayerDataService.save(player, "AdminSave")
end

local function handleChat(player: Player, message: string)
	if not AdminService.canUse(player.UserId) then
		return
	end
	if message:sub(1, #PREFIX) ~= PREFIX then
		return
	end

	local rest = message:sub(#PREFIX + 1)
	local parts: { string } = {}
	for token in rest:gmatch("%S+") do
		table.insert(parts, token)
	end
	local name = parts[1]
	if not name then
		return
	end
	table.remove(parts, 1)

	local handler = commands[name:lower()]
	if not handler then
		warn(`[AdminService] unknown command: {name}`)
		return
	end

	local data = PlayerDataService.get(player.UserId)
	if not data then
		return
	end

	print(
		`[AdminService] {player.Name} ({player.UserId}) ran /bf {name} {table.concat(parts, " ")}`
	)
	local ok, err = pcall(handler, player, data, parts)
	if not ok then
		warn(`[AdminService] command {name} errored: {err}`)
	end
end

function AdminService.Init()
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			handleChat(player, message)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.Chatted:Connect(function(message)
			handleChat(player, message)
		end)
	end
end

function AdminService.Start() end

return AdminService
