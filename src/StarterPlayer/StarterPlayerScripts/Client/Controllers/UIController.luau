--!strict
-- UIController — owns the ScreenGui and the UI modules (HUD, panels) (§19). TRACK B.
--
-- Builds one ScreenGui under PlayerGui (IgnoreGuiInset, ResetOnSpawn=false),
-- instantiates HUD + SlotPanel + SeedPicker + ShopPanel + RebirthPanel +
-- NotificationPanel, subscribes to every server->client remote, and routes the
-- snapshots to the right module. It keeps the latest DataSnapshot as the SINGLE
-- client state — every other controller reads it from here. Display only: the
-- client never computes a payout/cost (§19).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local HUD = require(UIFolder:WaitForChild("HUD"))
local SlotPanel = require(UIFolder:WaitForChild("SlotPanel"))
local SeedPicker = require(UIFolder:WaitForChild("SeedPicker"))
local ShopPanel = require(UIFolder:WaitForChild("ShopPanel"))
local RebirthPanel = require(UIFolder:WaitForChild("RebirthPanel"))
local NotificationPanel = require(UIFolder:WaitForChild("NotificationPanel"))

type DataSnapshot = Types.DataSnapshot
type FarmSlot = Types.FarmSlot

local localPlayer = Players.LocalPlayer

local UIController = {}
UIController.Name = "UIController"

-- The single client state. Other controllers read this through getSnapshot().
local snapshot: DataSnapshot? = nil

-- UI module controllers (created in Init).
local screenGui: ScreenGui
local hud: any
local slotPanel: any
local seedPicker: any
local shopPanel: any
local rebirthPanel: any
local notifications: any

-- Listeners notified whenever a fresh full snapshot arrives (FarmController,
-- TutorialController subscribe so they can re-render 3D prompts).
local snapshotListeners: { (snapshot: DataSnapshot) -> () } = {}
local slotListeners: { (slotIndex: number, slot: FarmSlot?) -> () } = {}

local _connections: { RBXScriptConnection } = {}

-- ── Public accessors (used by the other controllers) ──────────────────────

function UIController.getSnapshot(): DataSnapshot?
	return snapshot
end

function UIController.getScreenGui(): ScreenGui
	return screenGui
end

function UIController.getSlotPanel(): any
	return slotPanel
end

function UIController.getSeedPicker(): any
	return seedPicker
end

function UIController.getShopPanel(): any
	return shopPanel
end

function UIController.getRebirthPanel(): any
	return rebirthPanel
end

function UIController.getNotifications(): any
	return notifications
end

-- Subscribe to full snapshot updates (DataUpdated).
function UIController.onSnapshot(callback: (snapshot: DataSnapshot) -> ())
	table.insert(snapshotListeners, callback)
	if snapshot then
		callback(snapshot)
	end
end

-- Subscribe to single-slot updates (SlotUpdated).
function UIController.onSlot(callback: (slotIndex: number, slot: FarmSlot?) -> ())
	table.insert(slotListeners, callback)
end

-- Open helpers so FarmController/HUD route through one place.
function UIController.openShop()
	if snapshot then
		shopPanel.open(snapshot)
	end
end

function UIController.openRebirth()
	if snapshot then
		rebirthPanel.open(snapshot)
	end
end

function UIController.closeAll()
	slotPanel.close()
	seedPicker.close()
	shopPanel.close()
	rebirthPanel.close()
end

-- ── Internal routing ──────────────────────────────────────────────────────

local function applySnapshot(newSnapshot: DataSnapshot)
	snapshot = newSnapshot
	hud.setData(newSnapshot)
	-- Keep any open economy panels current.
	if shopPanel.isOpen() then
		shopPanel.setData(newSnapshot)
	end
	for _, listener in snapshotListeners do
		task.spawn(listener, newSnapshot)
	end
end

local function applySlot(slotIndex: number, slot: FarmSlot?)
	-- Patch the locally-held snapshot so client state stays consistent between
	-- full DataUpdated pushes (server remains the authority on the values).
	if snapshot then
		snapshot.Slots[slotIndex] = slot or {}
	end
	if snapshot then
		slotPanel.refresh(slotIndex, slot, snapshot)
	end
	for _, listener in slotListeners do
		task.spawn(listener, slotIndex, slot)
	end
end

function UIController.Init()
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BrainrotFarmUI"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	-- Global safe-area padding so nothing hugs the notch/edges on phones.
	local safe = Instance.new("Frame")
	safe.Name = "SafeArea"
	safe.BackgroundTransparency = 1
	safe.Size = UDim2.fromScale(1, 1)
	safe.Parent = screenGui

	hud = HUD.create(safe)
	slotPanel = SlotPanel.create(safe)
	seedPicker = SeedPicker.create(safe)
	shopPanel = ShopPanel.create(safe)
	rebirthPanel = RebirthPanel.create(safe)
	notifications = NotificationPanel.create(safe)

	-- HUD shop button opens the shop.
	hud.onShopPressed(function()
		UIController.openShop()
	end)

	-- Wire economy intents from the panels straight to the remotes (intent only).
	shopPanel.onBuySlot(function()
		Remotes.Events[Constants.Remotes.BuySlot]:FireServer()
	end)
	shopPanel.onRebirth(function()
		-- Open the explicit confirm dialog rather than firing immediately (§19).
		UIController.openRebirth()
	end)
	shopPanel.onBuyCoinPack(function(packKey: string)
		Remotes.Events[Constants.Remotes.RequestCoinPackPurchase]:FireServer(packKey)
	end)
	shopPanel.onBuyFertilizer(function()
		Remotes.Events[Constants.Remotes.RequestFertilizerPurchase]:FireServer()
	end)

	rebirthPanel.onConfirm(function()
		Remotes.Events[Constants.Remotes.RequestRebirth]:FireServer()
	end)
end

function UIController.Start()
	local events = Remotes.Events

	table.insert(
		_connections,
		events[Constants.Remotes.DataUpdated].OnClientEvent:Connect(
			function(newSnapshot: DataSnapshot)
				applySnapshot(newSnapshot)
			end
		)
	)

	table.insert(
		_connections,
		events[Constants.Remotes.SlotUpdated].OnClientEvent:Connect(
			function(slotIndex: number, slot: FarmSlot?)
				applySlot(slotIndex, slot)
			end
		)
	)

	table.insert(
		_connections,
		events[Constants.Remotes.Notification].OnClientEvent:Connect(
			function(text: string, level: number)
				notifications.push(text, level)
			end
		)
	)

	table.insert(
		_connections,
		events[Constants.Remotes.PurchaseResult].OnClientEvent:Connect(
			function(ok: boolean, message: string)
				notifications.push(message, if ok then 1 else 0)
			end
		)
	)

	-- Pull the current snapshot once, now that our listeners are connected, so an
	-- initial server push fired before we were ready isn't lost (server stays the
	-- authority — this is only a fetch). The snapshot carries PlotId, so listeners
	-- (FarmController) can also recover the plot if FarmAssigned was missed.
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.Functions[Constants.RemoteFunctions.RequestData]:InvokeServer()
		end)
		if ok and result then
			applySnapshot(result)
		end
	end)
end

return UIController
