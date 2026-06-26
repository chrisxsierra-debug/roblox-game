--!strict
-- EconomyService — coins, slot purchases, seed unlocks (§10, §17).
-- TRACK A. Reads EconomyConfig + SeedTierDefinitions (server-only require).
--
-- Responsibilities:
--   * addCoins / trySpend with clamping; keep LifetimeCoins in sync on earn.
--   * BuySlot validation (§17): < MaxSlots, cost matches server config, can afford.
--   * Re-check seed-tier unlocks whenever LifetimeCoins increases (§10).
--   * NEVER trust client-sent amounts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local SeedTierDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("SeedTierDefinitions"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local Utility = Server:WaitForChild("Utility")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local RateLimiterModule = require(Utility:WaitForChild("RateLimiter"))

local EconomyService = {}
EconomyService.Name = "EconomyService"

local limiter = RateLimiterModule.new()

-- Re-check which seed tiers are unlocked and bump HighestSeedTier (only ever grows).
-- Returns true if HighestSeedTier changed.
function EconomyService.refreshSeedUnlocks(userId: number): boolean
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	local highest = data.HighestSeedTier
	for tier = highest + 1, SeedTierDefinitions.MaxTier do
		if SeedTierDefinitions.isUnlocked(tier, data.LifetimeCoins, data.Rebirths) then
			highest = tier
		end
	end
	if highest ~= data.HighestSeedTier then
		data.HighestSeedTier = highest
		PlayerDataService.markDirty(userId)
		return true
	end
	return false
end

-- Add coins. On a positive earn, also bump LifetimeCoins + TotalCoinsEarned and
-- re-check seed unlocks (§10). `isEarning` distinguishes earned income (counts
-- toward lifetime/unlocks) from non-earn grants (e.g. refunds) which do not.
function EconomyService.addCoins(userId: number, amount: number, isEarning: boolean)
	local data = PlayerDataService.get(userId)
	if not data then
		return
	end
	if type(amount) ~= "number" or amount ~= amount then
		return
	end
	amount = math.floor(amount)
	if amount == 0 then
		return
	end

	data.Coins = math.max(0, data.Coins + amount)

	if isEarning and amount > 0 then
		data.LifetimeCoins += amount
		data.Statistics.TotalCoinsEarned += amount
		EconomyService.refreshSeedUnlocks(userId)
	end

	PlayerDataService.markDirty(userId)
end

-- Spend coins if affordable. Returns whether the spend happened.
function EconomyService.trySpend(userId: number, amount: number): boolean
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	if data.Coins < amount then
		return false
	end
	data.Coins -= amount
	PlayerDataService.markDirty(userId)
	return true
end

-- BuySlot (§17): validate next slot < MaxSlots, cost from config, affordable, then
-- spend + increment UnlockedSlots and grow the Slots array with an empty slot.
-- Returns ok, errorCode.
function EconomyService.buySlot(userId: number): (boolean, string?)
	local data = PlayerDataService.get(userId)
	if not data then
		return false, "no_data"
	end

	local nextSlot = data.UnlockedSlots + 1
	if nextSlot > EconomyConfig.MaxSlots then
		return false, "max_slots"
	end

	local cost = EconomyConfig.getSlotCost(nextSlot)
	if cost == nil then
		return false, "no_cost"
	end

	if data.Coins < cost then
		return false, "cannot_afford"
	end

	data.Coins -= cost
	data.UnlockedSlots = nextSlot
	-- Keep the Slots array length aligned with UnlockedSlots (§schema).
	data.Slots[nextSlot] = {}
	PlayerDataService.markDirty(userId)
	return true, nil
end

function EconomyService.Init()
	Remotes.Events[Constants.Remotes.BuySlot].OnServerEvent:Connect(function(player)
		local key = `{player.UserId}:BuySlot`
		if not limiter:allow(key, Constants.RateLimits.BuySlot) then
			return
		end
		-- BuySlot is gated during the tutorial.
		if not TutorialService.allowsAction(player, "BuySlot") then
			Remotes.Events[Constants.Remotes.Notification]:FireClient(
				player,
				"Finish the tutorial first!",
				0
			)
			return
		end
		local ok, err = EconomyService.buySlot(player.UserId)
		if ok then
			PlayerDataService.replicate(player)
		elseif err == "cannot_afford" then
			Remotes.Events[Constants.Remotes.Notification]:FireClient(
				player,
				"Not enough coins for the next slot.",
				0
			)
		elseif err == "max_slots" then
			Remotes.Events[Constants.Remotes.Notification]:FireClient(
				player,
				"All slots unlocked!",
				0
			)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		limiter:clear(tostring(player.UserId))
	end)
end

function EconomyService.Start() end

return EconomyService
