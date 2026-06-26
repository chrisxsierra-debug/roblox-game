--!strict
-- SeedPicker — choose which unlocked seed tier to plant (§19). TRACK B.
-- Shows each tier's cost, grow time, base payout, and lock requirement (reads
-- SeedTierDefinitions + EconomyConfig for DISPLAY only).
--
-- This panel sends INTENT only: when a tier is chosen it calls the supplied
-- callback with (slotIndex, tier); the server owns the actual cost/roll/payout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Definitions = Shared:WaitForChild("Definitions")
local SeedTierDefinitions = require(Definitions:WaitForChild("SeedTierDefinitions"))
local TimeUtility = require(Shared:WaitForChild("Utility"):WaitForChild("TimeUtility"))

local UITheme = require(script.Parent:WaitForChild("UITheme"))

type Snapshot = {
	Coins: number,
	LifetimeCoins: number,
	Rebirths: number,
	HighestSeedTier: number,
	[string]: any,
}

export type SeedPickerController = {
	instance: Frame,
	open: (slotIndex: number, snapshot: Snapshot) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	onPlant: (callback: (slotIndex: number, tier: number) -> ()) -> (),
}

local SeedPicker = {}

function SeedPicker.create(parent: Instance): SeedPickerController
	local plantCallbacks: { (slotIndex: number, tier: number) -> () } = {}
	local activeSlot: number? = nil

	-- Dim backdrop that closes the picker when tapped.
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "SeedPickerBackdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Visible = false
	backdrop.ZIndex = 20
	backdrop.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "SeedPicker"
	root.AnchorPoint = Vector2.new(0.5, 1)
	-- Bottom-anchored so the choices sit in the thumb zone (§19).
	root.Position = UDim2.new(0.5, 0, 1, -UITheme.Sizing.SafeAreaPaddingPx)
	root.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0, 280)
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
	title.Text = "Pick a Seed"
	title.ZIndex = 21
	title.Parent = root

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tiers"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 34)
	scroll.Size = UDim2.new(1, 0, 1, -34)
	scroll.ScrollBarThickness = 4
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.ZIndex = 21
	scroll.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	-- One card per tier; its setData(snapshot) refreshes lock/affordability.
	local cardUpdaters: { (snapshot: Snapshot) -> () } = {}

	for tier = 1, SeedTierDefinitions.MaxTier do
		local def = SeedTierDefinitions.get(tier)
		if not def then
			continue
		end

		local card = Instance.new("TextButton")
		card.Name = "Tier" .. tier
		card.Size = UDim2.new(0, 150, 1, -8)
		card.BackgroundColor3 = UITheme.Colors.PanelLight
		card.AutoButtonColor = true
		card.Text = ""
		card.LayoutOrder = tier
		card.ZIndex = 22
		card.Parent = scroll
		UITheme.applyPanel(card)

		local cardPad = Instance.new("UIPadding")
		cardPad.PaddingTop = UDim.new(0, 8)
		cardPad.PaddingBottom = UDim.new(0, 8)
		cardPad.PaddingLeft = UDim.new(0, 8)
		cardPad.PaddingRight = UDim.new(0, 8)
		cardPad.Parent = card

		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0, 24)
		name.Font = UITheme.Fonts.Heading
		name.TextColor3 = UITheme.Colors.Text
		name.TextSize = 18
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = def.DisplayName
		name.ZIndex = 22
		name.Parent = card

		local stats = Instance.new("TextLabel")
		stats.Name = "Stats"
		stats.BackgroundTransparency = 1
		stats.Position = UDim2.fromOffset(0, 28)
		stats.Size = UDim2.new(1, 0, 1, -56)
		stats.Font = UITheme.Fonts.Body
		stats.TextColor3 = UITheme.Colors.TextDim
		stats.TextSize = 14
		stats.TextXAlignment = Enum.TextXAlignment.Left
		stats.TextYAlignment = Enum.TextYAlignment.Top
		stats.TextWrapped = true
		stats.RichText = true
		stats.Text = string.format(
			"Cost: %d\nGrow: %s\nBase: %d",
			def.SeedCost,
			TimeUtility.format(def.GrowDuration),
			def.BaseSellValue
		)
		stats.ZIndex = 22
		stats.Parent = card

		local lockLabel = Instance.new("TextLabel")
		lockLabel.Name = "Lock"
		lockLabel.BackgroundTransparency = 1
		lockLabel.AnchorPoint = Vector2.new(0, 1)
		lockLabel.Position = UDim2.fromScale(0, 1)
		lockLabel.Size = UDim2.new(1, 0, 0, 22)
		lockLabel.Font = UITheme.Fonts.Body
		lockLabel.TextColor3 = UITheme.Colors.Danger
		lockLabel.TextSize = 13
		lockLabel.TextXAlignment = Enum.TextXAlignment.Left
		lockLabel.TextWrapped = true
		lockLabel.Text = ""
		lockLabel.ZIndex = 22
		lockLabel.Parent = card

		card.Activated:Connect(function()
			local slot = activeSlot
			if not slot then
				return
			end
			-- Fire intent only; server validates unlock + affordability.
			for _, cb in plantCallbacks do
				cb(slot, tier)
			end
		end)

		cardUpdaters[tier] = function(snapshot: Snapshot)
			local unlocked =
				SeedTierDefinitions.isUnlocked(tier, snapshot.LifetimeCoins, snapshot.Rebirths)
			local affordable = snapshot.Coins >= def.SeedCost
			if not unlocked then
				card.BackgroundColor3 = UITheme.Colors.Locked
				card.Active = false
				card.AutoButtonColor = false
				lockLabel.TextColor3 = UITheme.Colors.Danger
				lockLabel.Text = string.format("Unlock at %d lifetime", def.UnlockLifetimeCoins)
			elseif not affordable then
				card.BackgroundColor3 = UITheme.Colors.PanelLight
				card.Active = true
				card.AutoButtonColor = true
				lockLabel.TextColor3 = UITheme.Colors.Danger
				lockLabel.Text = "Not enough coins"
			else
				card.BackgroundColor3 = UITheme.Colors.PanelLight
				card.Active = true
				card.AutoButtonColor = true
				lockLabel.TextColor3 = UITheme.Colors.Success
				lockLabel.Text = "Tap to plant"
			end
		end
	end

	local function close()
		activeSlot = nil
		backdrop.Visible = false
	end

	backdrop.Activated:Connect(close)

	local controller: SeedPickerController = {
		instance = root,
		open = function(slotIndex: number, snapshot: Snapshot)
			activeSlot = slotIndex
			title.Text = string.format("Pick a Seed — Slot %d", slotIndex)
			for _, update in cardUpdaters do
				update(snapshot)
			end
			backdrop.Visible = true
		end,
		close = close,
		isOpen = function(): boolean
			return backdrop.Visible
		end,
		onPlant = function(callback: (slotIndex: number, tier: number) -> ())
			table.insert(plantCallbacks, callback)
		end,
	}

	return controller
end

return SeedPicker
