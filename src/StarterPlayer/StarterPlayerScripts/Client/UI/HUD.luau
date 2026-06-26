--!strict
-- HUD — always-on counters (§19). TRACK B.
-- Coins, progress-to-next-seed bar, rebirth count, income multiplier, current
-- seed tier, and the Shop button. Large, top-anchored, safe-area aware.
--
-- Display only — every value comes from the server DataSnapshot. The bar's
-- "progress to next seed" is read from SeedTierDefinitions thresholds against the
-- replicated LifetimeCoins; the client never invents an economy number.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SeedTierDefinitions =
	require(Shared:WaitForChild("Definitions"):WaitForChild("SeedTierDefinitions"))

local UITheme = require(script.Parent:WaitForChild("UITheme"))

type Snapshot = {
	Coins: number,
	LifetimeCoins: number,
	Rebirths: number,
	IncomeMultiplier: number,
	HighestSeedTier: number,
	[string]: any,
}

export type HUDController = {
	instance: Frame,
	setData: (snapshot: Snapshot) -> (),
	onShopPressed: (callback: () -> ()) -> (),
}

local HUD = {}

-- Returns the lifetime-coins threshold of the next still-locked tier (or nil if
-- every tier is already unlocked), for the "progress to next seed" bar.
local function nextTierThreshold(snapshot: Snapshot): (number?, string?)
	for tier = 1, SeedTierDefinitions.MaxTier do
		local def = SeedTierDefinitions.get(tier)
		if def then
			local unlocked =
				SeedTierDefinitions.isUnlocked(tier, snapshot.LifetimeCoins, snapshot.Rebirths)
			if not unlocked then
				return def.UnlockLifetimeCoins, def.DisplayName
			end
		end
	end
	return nil, nil
end

-- Compact, readable number formatting for HUD counters (1.2K, 3.4M).
local function abbreviate(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	elseif n < 1000000 then
		return string.format("%.1fK", n / 1000)
	elseif n < 1000000000 then
		return string.format("%.1fM", n / 1000000)
	end
	return string.format("%.1fB", n / 1000000000)
end

local function makeStat(parent: Instance, order: number, label: string): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = label .. "Stat"
	holder.BackgroundColor3 = UITheme.Colors.Panel
	holder.BackgroundTransparency = 0.1
	holder.Size = UDim2.fromScale(0, 1)
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.LayoutOrder = order
	holder.Parent = parent

	UITheme.applyPanel(holder)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = holder

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Size = UDim2.fromScale(0, 1)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.Font = UITheme.Fonts.Number
	value.TextColor3 = UITheme.Colors.Text
	value.TextScaled = false
	value.TextSize = 22
	value.Text = "0"
	value.LayoutOrder = 2
	value.Parent = holder

	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	tag.BackgroundTransparency = 1
	tag.Size = UDim2.fromScale(0, 1)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Font = UITheme.Fonts.Body
	tag.TextColor3 = UITheme.Colors.TextDim
	tag.TextSize = 14
	tag.Text = label
	tag.LayoutOrder = 1
	tag.Parent = holder

	return holder, value
end

function HUD.create(parent: Instance): HUDController
	local root = Instance.new("Frame")
	root.Name = "HUD"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, UITheme.Sizing.SafeAreaPaddingPx)
	root.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0, 64)
	root.Parent = parent

	-- Top row: stats on the left, shop button on the right.
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, UITheme.Sizing.MinButtonHeightPx)
	row.Parent = root

	local statsHolder = Instance.new("Frame")
	statsHolder.Name = "Stats"
	statsHolder.BackgroundTransparency = 1
	statsHolder.Size = UDim2.new(1, -(UITheme.Sizing.MinButtonHeightPx + 110), 1, 0)
	statsHolder.Parent = row

	local statsList = Instance.new("UIListLayout")
	statsList.FillDirection = Enum.FillDirection.Horizontal
	statsList.VerticalAlignment = Enum.VerticalAlignment.Center
	statsList.Padding = UDim.new(0, 8)
	statsList.SortOrder = Enum.SortOrder.LayoutOrder
	statsList.Parent = statsHolder

	local _, coinValue = makeStat(statsHolder, 1, "Coins")
	local _, rebirthValue = makeStat(statsHolder, 2, "Rebirths")
	local _, multValue = makeStat(statsHolder, 3, "Income")
	local _, tierValue = makeStat(statsHolder, 4, "Seed")

	-- Shop button — large, thumb-reachable on the right edge.
	local shopButton = Instance.new("TextButton")
	shopButton.Name = "ShopButton"
	shopButton.AnchorPoint = Vector2.new(1, 0.5)
	shopButton.Position = UDim2.fromScale(1, 0.5)
	shopButton.Size = UDim2.fromOffset(100, UITheme.Sizing.MinButtonHeightPx)
	shopButton.BackgroundColor3 = UITheme.Colors.Accent
	shopButton.Font = UITheme.Fonts.Heading
	shopButton.TextColor3 = UITheme.Colors.Text
	shopButton.TextSize = 20
	shopButton.Text = "SHOP"
	shopButton.AutoButtonColor = true
	shopButton.Parent = row
	UITheme.applyPanel(shopButton)

	-- Progress-to-next-seed bar under the stats.
	local barBack = Instance.new("Frame")
	barBack.Name = "ProgressBar"
	barBack.BackgroundColor3 = UITheme.Colors.Panel
	barBack.Position = UDim2.fromOffset(0, UITheme.Sizing.MinButtonHeightPx + 6)
	barBack.Size = UDim2.new(1, 0, 0, 18)
	barBack.Parent = root
	UITheme.applyPanel(barBack)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UITheme.Colors.AccentAlt
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = barBack
	UITheme.applyPanel(fill)

	local barLabel = Instance.new("TextLabel")
	barLabel.Name = "BarLabel"
	barLabel.BackgroundTransparency = 1
	barLabel.Size = UDim2.fromScale(1, 1)
	barLabel.Font = UITheme.Fonts.Body
	barLabel.TextColor3 = UITheme.Colors.Text
	barLabel.TextSize = 13
	barLabel.Text = ""
	barLabel.Parent = barBack

	local controller: HUDController = {
		instance = root,
		setData = function(snapshot: Snapshot)
			coinValue.Text = abbreviate(snapshot.Coins)
			rebirthValue.Text = tostring(snapshot.Rebirths)
			multValue.Text = string.format("x%.1f", snapshot.IncomeMultiplier)

			local tierDef = SeedTierDefinitions.get(snapshot.HighestSeedTier)
			tierValue.Text = if tierDef
				then tierDef.DisplayName
				else tostring(snapshot.HighestSeedTier)

			local threshold, nextName = nextTierThreshold(snapshot)
			if threshold and threshold > 0 then
				local ratio = math.clamp(snapshot.LifetimeCoins / threshold, 0, 1)
				fill.Size = UDim2.fromScale(ratio, 1)
				barLabel.Text = string.format(
					"%s / %s → %s",
					abbreviate(snapshot.LifetimeCoins),
					abbreviate(threshold),
					nextName or "?"
				)
				barBack.Visible = true
			else
				fill.Size = UDim2.fromScale(1, 1)
				barLabel.Text = "All seeds unlocked!"
				barBack.Visible = true
			end
		end,
		onShopPressed = function(callback: () -> ())
			shopButton.Activated:Connect(callback)
		end,
	}

	return controller
end

return HUD
