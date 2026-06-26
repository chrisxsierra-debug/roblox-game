--!strict
-- SlotPanel — contextual panel for a tapped slot (§19). TRACK B.
-- Empty -> hand off to SeedPicker (handled by FarmController). Growing -> creature
-- name + progress + remaining + stage. Ready -> full creature + mutation + estimated
-- payout (informational only) + large Harvest button + "READY!".
--
-- Every displayed number is read from the replicated slot + Definitions for DISPLAY
-- only. The estimated payout is computed from EconomyConfig purely to inform the
-- player; the server recomputes the real payout on harvest (§19, §28).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Definitions = Shared:WaitForChild("Definitions")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))
local CreatureDefinitions = require(Definitions:WaitForChild("CreatureDefinitions"))
local MutationDefinitions = require(Definitions:WaitForChild("MutationDefinitions"))
local SeedTierDefinitions = require(Definitions:WaitForChild("SeedTierDefinitions"))
local TimeUtility = require(Shared:WaitForChild("Utility"):WaitForChild("TimeUtility"))

local UITheme = require(script.Parent:WaitForChild("UITheme"))

type Slot = {
	SeedTierId: number?,
	CreatureId: string?,
	MutationId: string?,
	PlantedAt: number?,
	ReadyAt: number?,
	GrowthSpeedMultiplier: number?,
}

type Snapshot = {
	Rebirths: number,
	Passes: { [string]: boolean },
	[string]: any,
}

export type SlotPanelController = {
	instance: Frame,
	open: (slotIndex: number, slot: Slot, snapshot: Snapshot) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	-- Re-renders the currently open slot from a fresh slot/snapshot, if it matches.
	refresh: (slotIndex: number, slot: Slot?, snapshot: Snapshot) -> (),
	onHarvest: (callback: (slotIndex: number) -> ()) -> (),
	onFertilizer: (callback: (slotIndex: number) -> ()) -> (),
	onInstantGrow: (callback: (slotIndex: number) -> ()) -> (),
}

local SlotPanel = {}

-- Informational-only payout estimate. The server owns the real value (§19).
local function estimatePayout(slot: Slot, snapshot: Snapshot): number?
	if not slot.SeedTierId or not slot.CreatureId or not slot.MutationId then
		return nil
	end
	local tierDef = SeedTierDefinitions.get(slot.SeedTierId)
	local creature = CreatureDefinitions.get(slot.CreatureId)
	local mutation = MutationDefinitions.get(slot.MutationId)
	if not tierDef or not creature or not mutation then
		return nil
	end
	local hasVIP = snapshot.Passes ~= nil and snapshot.Passes.GoldenPlotVIP == true
	return EconomyConfig.computePayout(
		tierDef.BaseSellValue,
		creature.BaseValueMultiplier,
		mutation.ValueMultiplier,
		snapshot.Rebirths,
		hasVIP
	)
end

function SlotPanel.create(parent: Instance): SlotPanelController
	local harvestCallbacks: { (slotIndex: number) -> () } = {}
	local fertilizerCallbacks: { (slotIndex: number) -> () } = {}
	local instantGrowCallbacks: { (slotIndex: number) -> () } = {}

	local activeSlotIndex: number? = nil

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "SlotPanelBackdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Visible = false
	backdrop.ZIndex = 20
	backdrop.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "SlotPanel"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -UITheme.Sizing.SafeAreaPaddingPx)
	root.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0, 260)
	root.BackgroundColor3 = UITheme.Colors.Panel
	root.ZIndex = 21
	root.Parent = backdrop
	UITheme.applyPanel(root)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 28)
	title.Font = UITheme.Fonts.Heading
	title.TextColor3 = UITheme.Colors.Text
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Slot"
	title.ZIndex = 21
	title.Parent = root

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(0, 30)
	subtitle.Size = UDim2.new(1, 0, 0, 64)
	subtitle.Font = UITheme.Fonts.Body
	subtitle.TextColor3 = UITheme.Colors.TextDim
	subtitle.TextSize = 16
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.TextWrapped = true
	subtitle.RichText = true
	subtitle.Text = ""
	subtitle.ZIndex = 21
	subtitle.Parent = root

	-- Growth progress bar.
	local barBack = Instance.new("Frame")
	barBack.Name = "ProgressBar"
	barBack.BackgroundColor3 = UITheme.Colors.PanelLight
	barBack.Position = UDim2.fromOffset(0, 100)
	barBack.Size = UDim2.new(1, 0, 0, 22)
	barBack.ZIndex = 21
	barBack.Parent = root
	UITheme.applyPanel(barBack)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UITheme.Colors.AccentAlt
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 21
	fill.Parent = barBack
	UITheme.applyPanel(fill)

	local barLabel = Instance.new("TextLabel")
	barLabel.Name = "BarLabel"
	barLabel.BackgroundTransparency = 1
	barLabel.Size = UDim2.fromScale(1, 1)
	barLabel.Font = UITheme.Fonts.Body
	barLabel.TextColor3 = UITheme.Colors.Text
	barLabel.TextSize = 14
	barLabel.Text = ""
	barLabel.ZIndex = 22
	barLabel.Parent = barBack

	-- Action button (Harvest when ready). Large tap target.
	local harvestButton = Instance.new("TextButton")
	harvestButton.Name = "HarvestButton"
	harvestButton.AnchorPoint = Vector2.new(0.5, 1)
	harvestButton.Position = UDim2.fromScale(0.5, 1)
	harvestButton.Size = UDim2.new(1, 0, 0, UITheme.Sizing.MinButtonHeightPx)
	harvestButton.BackgroundColor3 = UITheme.Colors.Success
	harvestButton.Font = UITheme.Fonts.Heading
	harvestButton.TextColor3 = UITheme.Colors.Text
	harvestButton.TextSize = 22
	harvestButton.Text = "HARVEST"
	harvestButton.Visible = false
	harvestButton.ZIndex = 22
	harvestButton.Parent = root
	UITheme.applyPanel(harvestButton)

	-- Secondary row: Fertilizer + Instant Grow (speed-ups while growing).
	local speedRow = Instance.new("Frame")
	speedRow.Name = "SpeedRow"
	speedRow.BackgroundTransparency = 1
	speedRow.AnchorPoint = Vector2.new(0.5, 1)
	speedRow.Position = UDim2.fromScale(0.5, 1)
	speedRow.Size = UDim2.new(1, 0, 0, UITheme.Sizing.MinButtonHeightPx)
	speedRow.Visible = false
	speedRow.ZIndex = 22
	speedRow.Parent = root

	local speedList = Instance.new("UIListLayout")
	speedList.FillDirection = Enum.FillDirection.Horizontal
	speedList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	speedList.Padding = UDim.new(0, 10)
	speedList.Parent = speedRow

	local function makeSpeedButton(text: string): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, -5, 1, 0)
		btn.BackgroundColor3 = UITheme.Colors.Accent
		btn.Font = UITheme.Fonts.Body
		btn.TextColor3 = UITheme.Colors.Text
		btn.TextSize = 16
		btn.Text = text
		btn.ZIndex = 22
		btn.Parent = speedRow
		UITheme.applyPanel(btn)
		return btn
	end

	local fertilizerButton = makeSpeedButton("Fertilizer")
	local instantGrowButton = makeSpeedButton("Instant Grow")

	local function fireAll(list: { (slotIndex: number) -> () })
		local slot = activeSlotIndex
		if not slot then
			return
		end
		for _, cb in list do
			cb(slot)
		end
	end

	harvestButton.Activated:Connect(function()
		fireAll(harvestCallbacks)
	end)
	fertilizerButton.Activated:Connect(function()
		fireAll(fertilizerCallbacks)
	end)
	instantGrowButton.Activated:Connect(function()
		fireAll(instantGrowCallbacks)
	end)

	local function render(slotIndex: number, slot: Slot, snapshot: Snapshot)
		title.Text = string.format("Slot %d", slotIndex)

		local creature = if slot.CreatureId then CreatureDefinitions.get(slot.CreatureId) else nil
		local creatureName = if creature then creature.DisplayName else "Mystery Egg"
		local now = TimeUtility.now()
		local ready = slot.ReadyAt ~= nil and TimeUtility.isReady(slot.ReadyAt, now)

		if ready then
			local mutation = if slot.MutationId
				then MutationDefinitions.get(slot.MutationId)
				else nil
			local mutationName = if mutation and mutation.Id ~= "Normal"
				then mutation.DisplayName
				else nil
			local payout = estimatePayout(slot, snapshot)
			local lines = { string.format("<b>%s</b> is ready!", creatureName) }
			if mutationName then
				table.insert(lines, string.format("Mutation: <b>%s</b>", mutationName))
			end
			if payout then
				table.insert(lines, string.format("Est. payout: ~%d coins", payout))
			end
			subtitle.Text = table.concat(lines, "\n")

			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = UITheme.Colors.Success
			barLabel.Text = "READY!"

			harvestButton.Visible = true
			speedRow.Visible = false
		else
			local planted = slot.PlantedAt or now
			local readyAt = slot.ReadyAt or now
			local duration = math.max(1, readyAt - planted)
			local elapsed = math.clamp(now - planted, 0, duration)
			local ratio = elapsed / duration
			local remaining = TimeUtility.remaining(readyAt, now)

			local tierDef = if slot.SeedTierId
				then SeedTierDefinitions.get(slot.SeedTierId)
				else nil
			local tierName = if tierDef then tierDef.DisplayName else "?"
			subtitle.Text = string.format("Growing a <b>%s</b> seed...", tierName)

			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = UITheme.Colors.AccentAlt
			barLabel.Text = string.format(
				"%d%%  •  %s left",
				math.floor(ratio * 100),
				TimeUtility.format(remaining)
			)

			harvestButton.Visible = false
			speedRow.Visible = true
		end
	end

	local function close()
		activeSlotIndex = nil
		backdrop.Visible = false
	end

	backdrop.Activated:Connect(close)

	local controller: SlotPanelController = {
		instance = root,
		open = function(slotIndex: number, slot: Slot, snapshot: Snapshot)
			activeSlotIndex = slotIndex
			render(slotIndex, slot, snapshot)
			backdrop.Visible = true
		end,
		close = close,
		isOpen = function(): boolean
			return backdrop.Visible
		end,
		refresh = function(slotIndex: number, slot: Slot?, snapshot: Snapshot)
			if not backdrop.Visible or activeSlotIndex ~= slotIndex then
				return
			end
			if not slot or not slot.SeedTierId then
				-- Slot emptied (harvested) while open — close.
				close()
				return
			end
			render(slotIndex, slot, snapshot)
		end,
		onHarvest = function(callback: (slotIndex: number) -> ())
			table.insert(harvestCallbacks, callback)
		end,
		onFertilizer = function(callback: (slotIndex: number) -> ())
			table.insert(fertilizerCallbacks, callback)
		end,
		onInstantGrow = function(callback: (slotIndex: number) -> ())
			table.insert(instantGrowCallbacks, callback)
		end,
	}

	return controller
end

return SlotPanel
