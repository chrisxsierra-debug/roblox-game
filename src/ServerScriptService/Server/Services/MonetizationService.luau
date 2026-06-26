--!strict
-- MonetizationService — game passes + ProcessReceipt (§23, §24). TRACK A.
--
-- Game passes: cache ownership of DoubleGrowth / AutoCollect / GoldenPlotVIP and
-- push it to PlayerDataService.setPasses (transient — avoids a require cycle, since
-- PlayerDataService must NOT require this service).
-- ProcessReceipt is server-authoritative, idempotent, retry-safe, logged (§24). For
-- the slot-targeted Instant Grow product we store a short-lived pending-purchase
-- context; on receipt we verify the slot still belongs to the player, grant once,
-- record the receipt id, and clear the context. If the slot is gone we apply a safe
-- fallback (a stored Instant-Grow token in FertilizerCharges-equivalent? no — we just
-- skip and still record the receipt so the player isn't charged twice with no grant
-- being lost: we grant the closest equivalent, see below).
-- Any product/pass whose id is 0 is skipped (MonetizationConfig.isConfigured).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Services = Server:WaitForChild("Services")
local Utility = Server:WaitForChild("Utility")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local GrowthService = require(Services:WaitForChild("GrowthService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local RateLimiterModule = require(Utility:WaitForChild("RateLimiter"))

local MonetizationService = {}
MonetizationService.Name = "MonetizationService"

local limiter = RateLimiterModule.new()

-- userId -> { [passKey]: boolean } cached pass ownership.
local passCache: { [number]: { [string]: boolean } } = {}

-- Short-lived pending Instant-Grow context: userId -> slotIndex (set just before
-- prompting the product purchase, consumed in ProcessReceipt).
local pendingInstantGrow: { [number]: number } = {}

-- Map MonetizationConfig.Products keys → product id, for ProcessReceipt routing.
local function productById(): { [number]: string }
	local map: { [number]: string } = {}
	for key, def in MonetizationConfig.Products do
		if MonetizationConfig.isConfigured(def.Id) then
			map[def.Id] = key
		end
	end
	return map
end

-- ── Pass ownership ───────────────────────────────────────────────────────────
function MonetizationService.ownsPass(userId: number, passKey: string): boolean
	local cache = passCache[userId]
	if not cache then
		return false
	end
	return cache[passKey] == true
end

-- Query each configured pass once and cache it; push the result to PlayerData.
function MonetizationService.refreshPasses(player: Player)
	local userId = player.UserId
	local cache = passCache[userId] or {}

	for passKey, def in MonetizationConfig.GamePasses do
		if MonetizationConfig.isConfigured(def.Id) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(userId, def.Id)
			end)
			if ok then
				cache[passKey] = owns == true
			else
				cache[passKey] = cache[passKey] == true
			end
		else
			cache[passKey] = false
		end
	end

	passCache[userId] = cache

	-- Push to the transient pass cache the rest of the server reads (§contract).
	PlayerDataService.setPasses(userId, {
		DoubleGrowth = cache.DoubleGrowth == true,
		AutoCollect = cache.AutoCollect == true,
		GoldenPlotVIP = cache.GoldenPlotVIP == true,
	})

	-- Re-replicate so the client sees pass-derived display values.
	if PlayerDataService.isLoaded(userId) then
		PlayerDataService.replicate(player)
	end
end

-- ── Grants ─────────────────────────────────────────────────────────────────
-- Complete one planted, not-yet-ready slot (Instant Grow). Returns success.
local function grantInstantGrow(userId: number, slotIndex: number): boolean
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	local slot = data.Slots[slotIndex]
	if not slot or slot.SeedTierId == nil or not slot.PlantedAt then
		return false
	end
	-- Force ready now.
	slot.ReadyAt = os.time()
	PlayerDataService.markDirty(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Remotes.Events[Constants.Remotes.SlotUpdated]:FireClient(player, slotIndex, slot)
	end
	return true
end

local function grantFertilizer(userId: number): boolean
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	data.FertilizerCharges += MonetizationConfig.Products.FertilizerPack.Charges
	PlayerDataService.markDirty(userId)
	local _ = GrowthService -- fertilizer consumption logic lives with growth math
	return true
end

local function grantCoinPack(userId: number, productKey: string): boolean
	local def = MonetizationConfig.Products[productKey]
	if not def or not def.Coins then
		return false
	end
	-- Coin packs are a paid grant: count toward LifetimeCoins (earned currency).
	EconomyService.addCoins(userId, def.Coins, true)
	return true
end

-- Route a granted product to its effect. Returns whether the grant fully applied.
local function applyProduct(userId: number, productKey: string): boolean
	if productKey == "InstantGrow" then
		local slotIndex = pendingInstantGrow[userId]
		pendingInstantGrow[userId] = nil
		if slotIndex and grantInstantGrow(userId, slotIndex) then
			return true
		end
		-- Safe fallback: the targeted slot is gone (harvested / emptied between
		-- prompt and receipt). Grant a fertilizer pack-equivalent so the purchase
		-- is honored rather than lost, and the receipt is still recorded.
		return grantFertilizer(userId)
	elseif productKey == "FertilizerPack" then
		return grantFertilizer(userId)
	elseif productKey:sub(1, 8) == "CoinPack" then
		return grantCoinPack(userId, productKey)
	end
	return false
end

-- ── ProcessReceipt (idempotent, §24) ─────────────────────────────────────────
function MonetizationService.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local userId = receiptInfo.PlayerId
	local purchaseId = tostring(receiptInfo.PurchaseId)
	local productId = receiptInfo.ProductId

	local data = PlayerDataService.get(userId)
	if not data then
		-- Player not loaded → not granted; ask Roblox to retry later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency: already granted this exact purchase id?
	if data.Purchases.ProcessedReceipts[purchaseId] ~= nil then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productKey = productById()[productId]
	if not productKey then
		-- Unknown / unconfigured product id: do not grant, but don't endlessly retry.
		warn(`[MonetizationService] receipt for unknown product {productId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok = applyProduct(userId, productKey)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Record the receipt FIRST in the live session, then save, so a retry after a
	-- crash sees it as already-granted.
	data.Purchases.ProcessedReceipts[purchaseId] = os.time()
	PlayerDataService.markDirty(userId)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		PlayerDataService.save(player, "Receipt")
		Remotes.Events[Constants.Remotes.PurchaseResult]:FireClient(
			player,
			true,
			`Purchase complete: {MonetizationConfig.Products[productKey].Name}`
		)
		PlayerDataService.replicate(player)
	end

	print(`[MonetizationService] granted {productKey} to {userId} (receipt {purchaseId})`)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ── Purchase intent handlers (client → server) ───────────────────────────────
local function promptProduct(player: Player, productKey: string)
	local def = MonetizationConfig.Products[productKey]
	if not def or not MonetizationConfig.isConfigured(def.Id) then
		-- id 0: feature not configured; tell the client, never error.
		Remotes.Events[Constants.Remotes.PurchaseResult]:FireClient(
			player,
			false,
			"That item isn't available yet."
		)
		return
	end
	-- No Robux prompts during the tutorial (§6).
	if not TutorialService.allowsAction(player, "Purchase") then
		return
	end
	pcall(function()
		MarketplaceService:PromptProductPurchase(player, def.Id)
	end)
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local decision = Enum.ProductPurchaseDecision.NotProcessedYet
		local ok, result = pcall(function()
			return MonetizationService.processReceipt(receiptInfo)
		end)
		if ok and typeof(result) == "EnumItem" then
			decision = result
		else
			warn(`[MonetizationService] ProcessReceipt errored: {result}`)
		end
		return decision
	end

	Remotes.Events[Constants.Remotes.RequestInstantGrowPurchase].OnServerEvent:Connect(
		function(player, slotIndex)
			if not limiter:allow(`{player.UserId}:Instant`, Constants.RateLimits.Default) then
				return
			end
			if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
				return
			end
			if not PlotService.ownsSlot(player.UserId, slotIndex) then
				return
			end
			-- Store the short-lived context, then prompt.
			pendingInstantGrow[player.UserId] = slotIndex
			promptProduct(player, "InstantGrow")
		end
	)

	Remotes.Events[Constants.Remotes.RequestFertilizerPurchase].OnServerEvent:Connect(
		function(player)
			if not limiter:allow(`{player.UserId}:Fert`, Constants.RateLimits.Default) then
				return
			end
			promptProduct(player, "FertilizerPack")
		end
	)

	Remotes.Events[Constants.Remotes.RequestCoinPackPurchase].OnServerEvent:Connect(
		function(player, packKey)
			if not limiter:allow(`{player.UserId}:Coin`, Constants.RateLimits.Default) then
				return
			end
			if type(packKey) ~= "string" then
				return
			end
			-- Only allow the known coin-pack keys.
			if
				packKey ~= "CoinPackSmall"
				and packKey ~= "CoinPackMedium"
				and packKey ~= "CoinPackLarge"
			then
				return
			end
			promptProduct(player, packKey)
		end
	)

	local function onAdded(player: Player)
		task.spawn(function()
			local data = PlayerDataService.waitForData(player)
			if not data then
				return
			end
			MonetizationService.refreshPasses(player)
		end)
	end

	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		passCache[player.UserId] = nil
		pendingInstantGrow[player.UserId] = nil
		limiter:clear(tostring(player.UserId))
	end)
end

function MonetizationService.Start() end

return MonetizationService
