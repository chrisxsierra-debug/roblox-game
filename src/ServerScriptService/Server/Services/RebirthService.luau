--!strict
-- RebirthService — rebirth flow (§10, §17). TRACK A.
--
-- Requirement (server-computed): EconomyConfig.getRebirthRequirement(rebirths).
-- On rebirth: reset Coins->20, UnlockedSlots->2, clear Slots; PRESERVE
-- LifetimeCoins, HighestSeedTier, Tutorial, Purchases; +1 Rebirth (+0.5x income).
-- A short per-player cooldown prevents a double-fire from completing twice (§17).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local Utility = Server:WaitForChild("Utility")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local RateLimiterModule = require(Utility:WaitForChild("RateLimiter"))

local RebirthService = {}
RebirthService.Name = "RebirthService"

local limiter = RateLimiterModule.new()

-- Short anti-double-fire cooldown (seconds) after a successful rebirth.
local REBIRTH_COOLDOWN = 3
local lastRebirthClock: { [number]: number } = {}

-- True if the player currently meets the rebirth requirement.
function RebirthService.canRebirth(userId: number): (boolean, string?)
	local data = PlayerDataService.get(userId)
	if not data then
		return false, "no_data"
	end
	local requirement = EconomyConfig.getRebirthRequirement(data.Rebirths)
	if data.Coins < requirement then
		return false, "cannot_afford"
	end
	return true, nil
end

-- Retained for signature compatibility. The flow now relies on a server-side
-- cooldown (below) rather than a client-held token, so the client just sends
-- RequestRebirth() and confirms via its own dialog (contract §3).
function RebirthService.requestConfirmation(_player: Player): string?
	return nil
end

-- Perform the rebirth: reset/preserve per the rules, +1 Rebirth, re-check unlocks
-- (rebirth can unlock Tier 5), persist immediately, replicate.
-- `_token` is accepted for signature compatibility but unused (cooldown-guarded).
function RebirthService.perform(player: Player, _token: string?): (boolean, string?)
	local userId = player.UserId

	-- Anti-double-fire cooldown.
	local last = lastRebirthClock[userId]
	if last and os.clock() - last < REBIRTH_COOLDOWN then
		return false, "cooldown"
	end

	local data = PlayerDataService.get(userId)
	if not data then
		return false, "no_data"
	end

	if not TutorialService.allowsAction(player, "Rebirth") then
		return false, "tutorial_locked"
	end

	local ok, err = RebirthService.canRebirth(userId)
	if not ok then
		return false, err
	end

	lastRebirthClock[userId] = os.clock()

	-- Reset (preserve LifetimeCoins, HighestSeedTier, Tutorial, Purchases, Stats).
	data.Rebirths += 1
	data.Coins = EconomyConfig.RebirthResetCoins
	data.UnlockedSlots = EconomyConfig.RebirthResetSlots
	local newSlots: { [number]: any } = {}
	for i = 1, data.UnlockedSlots do
		newSlots[i] = {}
	end
	data.Slots = newSlots

	-- Rebirth can unlock a new tier (e.g. Tier 5 on first rebirth, §10).
	EconomyService.refreshSeedUnlocks(userId)

	PlayerDataService.markDirty(userId)
	-- Save immediately so a hard reset survives a crash right after rebirth.
	PlayerDataService.save(player, "Rebirth")

	Remotes.Events[Constants.Remotes.Notification]:FireClient(
		player,
		`Rebirth! You are now Rebirth {data.Rebirths}.`,
		2
	)
	PlayerDataService.replicate(player)
	return true, nil
end

function RebirthService.Init()
	Remotes.Events[Constants.Remotes.RequestRebirth].OnServerEvent:Connect(function(player)
		local key = `{player.UserId}:RequestRebirth`
		if not limiter:allow(key, Constants.RateLimits.RequestRebirth) then
			return
		end
		local ok, err = RebirthService.perform(player)
		if not ok and err == "cannot_afford" then
			Remotes.Events[Constants.Remotes.Notification]:FireClient(
				player,
				"You need more coins to rebirth.",
				0
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiter:clear(tostring(player.UserId))
		lastRebirthClock[player.UserId] = nil
	end)
end

function RebirthService.Start() end

return RebirthService
