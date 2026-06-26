--!strict
-- FarmController — turns player input on slots into remote intents (§19, §20). TRACK B.
--
-- On FarmAssigned(plotId) it locates the player's plot in Workspace and each
-- grow-slot anchor by Constants.Tags.GrowSlot + the SlotIndex/PlotId attributes
-- (INTEGRATION_CONTRACT §4). Tapping/clicking a slot opens the SeedPicker (empty),
-- shows growing info, or shows a Harvest button (ready). It fires PlantSeed /
-- HarvestSlot — intent only; the server owns every value. Keyboard: E nearest slot,
-- B shop, R rebirth, Esc close. Gamepad via ContextActionService. The 4 cosmetic
-- growth stages animate locally from the replicated PlantedAt/ReadyAt timestamps;
-- the server is the authority on readiness.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))
local TimeUtility = require(Shared:WaitForChild("Utility"):WaitForChild("TimeUtility"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))

type DataSnapshot = Types.DataSnapshot
type FarmSlot = Types.FarmSlot

local localPlayer = Players.LocalPlayer

local FarmController = {}
FarmController.Name = "FarmController"

local STAGE_COUNT = GameConfig.GrowthStageCount

-- Plot/slot discovery state.
local assignedPlotId: number? = nil
local slotAnchors: { [number]: BasePart } = {}
local slotConnections: { [number]: RBXScriptConnection } = {}
local slotBillboards: { [number]: BillboardGui } = {}
-- The last cosmetic stage index shown per slot, to drive StageChange bounce.
local lastStageShown: { [number]: number } = {}

local discoveryConnections: { RBXScriptConnection } = {}

-- ── Helpers ────────────────────────────────────────────────────────────────

local function getSlot(slotIndex: number): FarmSlot?
	local snapshot = UIController.getSnapshot()
	if not snapshot then
		return nil
	end
	local slot = snapshot.Slots[slotIndex]
	if not slot or not slot.SeedTierId then
		return nil
	end
	return slot
end

-- Cosmetic stage index 1..STAGE_COUNT from replicated timestamps. The server owns
-- readiness; this is display only (§9).
local function computeStageIndex(slot: FarmSlot, now: number): number
	if not slot.PlantedAt or not slot.ReadyAt then
		return 1
	end
	local duration = math.max(1, slot.ReadyAt - slot.PlantedAt)
	local elapsed = math.clamp(now - slot.PlantedAt, 0, duration)
	local ratio = elapsed / duration
	local stage = math.floor(ratio * STAGE_COUNT) + 1
	return math.clamp(stage, 1, STAGE_COUNT)
end

-- Opens the right panel for a tapped slot.
local function openSlot(slotIndex: number)
	local snapshot = UIController.getSnapshot()
	if not snapshot then
		return
	end
	-- Respect unlocked-slot count: locked slots do nothing.
	if slotIndex > snapshot.UnlockedSlots then
		UIController.getNotifications().push("That slot isn't unlocked yet.", 0)
		return
	end

	local slot = getSlot(slotIndex)
	if not slot then
		-- Empty → choose a seed.
		UIController.getSeedPicker().open(slotIndex, snapshot)
	else
		-- Growing or ready → show the slot panel (Harvest when ready).
		UIController.getSlotPanel().open(slotIndex, slot, snapshot)
	end
end

local function fireHarvest(slotIndex: number)
	Remotes.Events[Constants.Remotes.HarvestSlot]:FireServer(slotIndex)
end

local function firePlant(slotIndex: number, tier: number)
	Remotes.Events[Constants.Remotes.PlantSeed]:FireServer(slotIndex, tier)
end

-- ── 3D slot discovery (INTEGRATION_CONTRACT §4) ────────────────────────────

local function clearSlots()
	for _, conn in slotConnections do
		conn:Disconnect()
	end
	for _, billboard in slotBillboards do
		billboard:Destroy()
	end
	table.clear(slotConnections)
	table.clear(slotBillboards)
	table.clear(slotAnchors)
	table.clear(lastStageShown)
end

-- Attaches a click detector + a READY billboard anchor to a discovered slot part.
local function bindSlot(part: BasePart, slotIndex: number)
	if slotAnchors[slotIndex] then
		return
	end
	slotAnchors[slotIndex] = part

	local detector = part:FindFirstChildOfClass("ClickDetector")
	if not detector then
		detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 32
		detector.Parent = part
	end
	slotConnections[slotIndex] = detector.MouseClick:Connect(function()
		openSlot(slotIndex)
	end)

	-- A small billboard above the slot for READY / growth labels (UI only — the
	-- creature model itself is server-spawned, §4).
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SlotStatus"
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(245, 245, 250)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = ""
	label.Parent = billboard

	slotBillboards[slotIndex] = billboard
end

-- True if this tagged part belongs to the player's assigned plot.
local function partBelongsToPlot(part: Instance): boolean
	if not assignedPlotId then
		return false
	end
	return part:GetAttribute(Constants.Attributes.PlotId) == assignedPlotId
end

local function tryBindTaggedPart(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	if not partBelongsToPlot(inst) then
		return
	end
	local slotIndex = inst:GetAttribute(Constants.Attributes.SlotIndex)
	if typeof(slotIndex) == "number" then
		bindSlot(inst, slotIndex)
	end
end

local function discoverSlots()
	clearSlots()
	for _, inst in CollectionService:GetTagged(Constants.Tags.GrowSlot) do
		tryBindTaggedPart(inst)
	end
end

local function onFarmAssigned(plotId: number)
	assignedPlotId = plotId

	for _, conn in discoveryConnections do
		conn:Disconnect()
	end
	table.clear(discoveryConnections)

	-- Slots may stream in after assignment; keep listening for new tagged parts.
	table.insert(
		discoveryConnections,
		CollectionService:GetInstanceAddedSignal(Constants.Tags.GrowSlot):Connect(tryBindTaggedPart)
	)

	-- The world is generated server-side; wait for the generated folder, then scan.
	-- (If it never appears we still scan whatever is already tagged.)
	task.spawn(function()
		Workspace:WaitForChild(Constants.World.GeneratedFolder, 30)
		discoverSlots()
	end)
end

-- ── Cosmetic per-frame animation of growth stages + READY billboards ───────

local function updateBillboards()
	local snapshot = UIController.getSnapshot()
	if not snapshot then
		return
	end
	local now = TimeUtility.now()

	for slotIndex, billboard in slotBillboards do
		local label = billboard:FindFirstChild("Label") :: TextLabel?
		if not label then
			continue
		end
		local slot = snapshot.Slots[slotIndex]
		if not slot or not slot.SeedTierId then
			label.Text = ""
			billboard.Enabled = false
			lastStageShown[slotIndex] = nil
			continue
		end

		billboard.Enabled = true
		local ready = slot.ReadyAt ~= nil and TimeUtility.isReady(slot.ReadyAt, now)
		if ready then
			label.Text = "READY!"
			label.TextColor3 = Color3.fromRGB(110, 220, 130)
		else
			local remaining = TimeUtility.remaining(slot.ReadyAt or now, now)
			label.Text = TimeUtility.format(remaining)
			label.TextColor3 = Color3.fromRGB(245, 245, 250)

			-- Detect a cosmetic stage change to trigger a local bounce/sparkle.
			local stage = computeStageIndex(slot, now)
			local prev = lastStageShown[slotIndex]
			if prev ~= nil and stage > prev then
				FarmController.onStageChangedLocally(slotIndex, stage)
			end
			lastStageShown[slotIndex] = stage
		end
	end
end

-- Hook other controllers (EffectsController) may override; default is a no-op so
-- a local stage change always has a safe sink.
function FarmController.onStageChangedLocally(_slotIndex: number, _stage: number) end

-- Lets EffectsController register for locally-detected stage changes.
function FarmController.setStageChangeHandler(handler: (slotIndex: number, stage: number) -> ())
	FarmController.onStageChangedLocally = handler
end

-- Position of the player's character root, for "nearest slot" keyboard input.
local function nearestSlotIndex(): number?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		-- No character → default to the first known slot.
		for slotIndex in slotAnchors do
			return slotIndex
		end
		return nil
	end

	local best: number? = nil
	local bestDist = math.huge
	for slotIndex, part in slotAnchors do
		local dist = (part.Position - root.Position).Magnitude
		if dist < bestDist then
			bestDist = dist
			best = slotIndex
		end
	end
	return best
end

-- ── Keyboard + gamepad (§20) ───────────────────────────────────────────────

local ACTION_INTERACT = "BrainrotInteractSlot"
local ACTION_SHOP = "BrainrotOpenShop"
local ACTION_REBIRTH = "BrainrotOpenRebirth"
local ACTION_CLOSE = "BrainrotClosePanel"

local function interactNearest()
	local slotIndex = nearestSlotIndex()
	if slotIndex then
		-- If the nearest slot is ready, harvest directly for snappy play; else open.
		local slot = getSlot(slotIndex)
		if slot and slot.ReadyAt and TimeUtility.isReady(slot.ReadyAt, TimeUtility.now()) then
			fireHarvest(slotIndex)
		else
			openSlot(slotIndex)
		end
	end
end

local function onAction(actionName: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if actionName == ACTION_INTERACT then
		interactNearest()
	elseif actionName == ACTION_SHOP then
		UIController.openShop()
	elseif actionName == ACTION_REBIRTH then
		UIController.openRebirth()
	elseif actionName == ACTION_CLOSE then
		UIController.closeAll()
	end
	return Enum.ContextActionResult.Sink
end

local function bindInputs()
	ContextActionService:BindAction(
		ACTION_INTERACT,
		onAction,
		false,
		Enum.KeyCode.E,
		Enum.KeyCode.ButtonA
	)
	ContextActionService:BindAction(
		ACTION_SHOP,
		onAction,
		false,
		Enum.KeyCode.B,
		Enum.KeyCode.ButtonY
	)
	ContextActionService:BindAction(
		ACTION_REBIRTH,
		onAction,
		false,
		Enum.KeyCode.R,
		Enum.KeyCode.ButtonX
	)
	ContextActionService:BindAction(
		ACTION_CLOSE,
		onAction,
		false,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)
end

-- ── Lifecycle ──────────────────────────────────────────────────────────────

function FarmController.Init()
	-- Wire the SeedPicker/SlotPanel intents (created by UIController) to remotes.
	UIController.getSeedPicker().onPlant(function(slotIndex: number, tier: number)
		firePlant(slotIndex, tier)
		UIController.getSeedPicker().close()
	end)

	UIController.getSlotPanel().onHarvest(function(slotIndex: number)
		fireHarvest(slotIndex)
		UIController.getSlotPanel().close()
	end)

	UIController.getSlotPanel().onFertilizer(function()
		Remotes.Events[Constants.Remotes.RequestFertilizerPurchase]:FireServer()
	end)

	UIController.getSlotPanel().onInstantGrow(function(slotIndex: number)
		Remotes.Events[Constants.Remotes.RequestInstantGrowPurchase]:FireServer(slotIndex)
	end)
end

function FarmController.Start()
	table.insert(
		discoveryConnections,
		Remotes.Events[Constants.Remotes.FarmAssigned].OnClientEvent:Connect(onFarmAssigned)
	)

	bindInputs()

	-- Drive cosmetic billboards/stage detection from a throttled render loop.
	-- (Touch taps on a slot are handled natively by each slot's ClickDetector, so
	-- mobile needs no extra input wiring here — §20.)
	local accumulator = 0
	table.insert(
		discoveryConnections,
		RunService.RenderStepped:Connect(function(dt: number)
			accumulator += dt
			if accumulator >= 0.25 then
				accumulator = 0
				updateBillboards()
			end
		end)
	)
end

return FarmController
