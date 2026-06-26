--!strict
-- ShopPanel — buy slot, rebirth, passes, and coin products (§19, §23). TRACK B.
-- Hide any pass/product whose MonetizationConfig id is 0 (§23). Close button.
--
-- Sends intent only. BuySlot/RequestRebirth carry no payload (server owns cost);
-- pass/product rows fire their request remotes which the server turns into the real
-- MarketplaceService prompt. The client never computes a price.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))

local UITheme = require(script.Parent:WaitForChild("UITheme"))

type Snapshot = {
	UnlockedSlots: number,
	NextSlotCost: number?,
	RebirthRequirement: number,
	Coins: number,
	Passes: { [string]: boolean },
	[string]: any,
}

export type ShopPanelController = {
	instance: Frame,
	open: (snapshot: Snapshot) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	setData: (snapshot: Snapshot) -> (),
	onBuySlot: (callback: () -> ()) -> (),
	onRebirth: (callback: () -> ()) -> (),
	onBuyCoinPack: (callback: (packKey: string) -> ()) -> (),
	onBuyFertilizer: (callback: () -> ()) -> (),
	setMonetizationGate: (gate: () -> boolean) -> (),
}

local ShopPanel = {}

-- A clickable row with a title, a description, and a right-side action button.
local function makeRow(parent: Instance, order: number): (Frame, TextLabel, TextLabel, TextButton)
	local row = Instance.new("Frame")
	row.Name = "Row" .. order
	row.BackgroundColor3 = UITheme.Colors.PanelLight
	row.Size = UDim2.new(1, 0, 0, 72)
	row.LayoutOrder = order
	row.ZIndex = 22
	row.Parent = parent
	UITheme.applyPanel(row)

	local rpad = Instance.new("UIPadding")
	rpad.PaddingLeft = UDim.new(0, 12)
	rpad.PaddingRight = UDim.new(0, 12)
	rpad.PaddingTop = UDim.new(0, 8)
	rpad.PaddingBottom = UDim.new(0, 8)
	rpad.Parent = row

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, -120, 0, 24)
	titleLabel.Font = UITheme.Fonts.Heading
	titleLabel.TextColor3 = UITheme.Colors.Text
	titleLabel.TextSize = 18
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = ""
	titleLabel.ZIndex = 22
	titleLabel.Parent = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "Desc"
	descLabel.BackgroundTransparency = 1
	descLabel.Position = UDim2.fromOffset(0, 26)
	descLabel.Size = UDim2.new(1, -120, 1, -26)
	descLabel.Font = UITheme.Fonts.Body
	descLabel.TextColor3 = UITheme.Colors.TextDim
	descLabel.TextSize = 14
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.TextWrapped = true
	descLabel.Text = ""
	descLabel.ZIndex = 22
	descLabel.Parent = row

	local button = Instance.new("TextButton")
	button.Name = "Action"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.fromScale(1, 0.5)
	button.Size = UDim2.fromOffset(104, UITheme.Sizing.MinButtonHeightPx)
	button.BackgroundColor3 = UITheme.Colors.Accent
	button.Font = UITheme.Fonts.Heading
	button.TextColor3 = UITheme.Colors.Text
	button.TextSize = 16
	button.Text = "Buy"
	button.ZIndex = 22
	button.Parent = row
	UITheme.applyPanel(button)

	return row, titleLabel, descLabel, button
end

function ShopPanel.create(parent: Instance): ShopPanelController
	local buySlotCallbacks: { () -> () } = {}
	local rebirthCallbacks: { () -> () } = {}
	local coinPackCallbacks: { (packKey: string) -> () } = {}
	local fertilizerCallbacks: { () -> () } = {}

	-- Monetization gate: returns true when Robux prompts are allowed. UIController
	-- points this at TutorialController so no purchase happens mid-tutorial (§6).
	local canPrompt: () -> boolean = function()
		return true
	end

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "ShopBackdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Visible = false
	backdrop.ZIndex = 20
	backdrop.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "ShopPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0.85, 0)
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
	title.Size = UDim2.new(1, -48, 0, 32)
	title.Font = UITheme.Fonts.Heading
	title.TextColor3 = UITheme.Colors.Text
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Shop"
	title.ZIndex = 21
	title.Parent = root

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.BackgroundColor3 = UITheme.Colors.Danger
	closeButton.Font = UITheme.Fonts.Heading
	closeButton.TextColor3 = UITheme.Colors.Text
	closeButton.TextSize = 22
	closeButton.Text = "X"
	closeButton.ZIndex = 22
	closeButton.Parent = root
	UITheme.applyPanel(closeButton)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 40)
	scroll.Size = UDim2.new(1, 0, 1, -40)
	scroll.ScrollBarThickness = 5
	scroll.CanvasSize = UDim2.fromScale(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ZIndex = 21
	scroll.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	-- ── Slot row (BuySlot) ────────────────────────────────────────────────
	local _, slotTitle, slotDesc, slotButton = makeRow(scroll, 1)
	slotTitle.Text = "Buy Next Slot"
	slotButton.Activated:Connect(function()
		for _, cb in buySlotCallbacks do
			cb()
		end
	end)

	-- ── Rebirth row ───────────────────────────────────────────────────────
	local _, rebirthTitle, rebirthDesc, rebirthButton = makeRow(scroll, 2)
	rebirthTitle.Text = "Rebirth"
	rebirthButton.Text = "Rebirth"
	rebirthButton.BackgroundColor3 = UITheme.Colors.Accent
	rebirthButton.Activated:Connect(function()
		for _, cb in rebirthCallbacks do
			cb()
		end
	end)

	-- ── Game pass rows (hidden when Id == 0) ──────────────────────────────
	local passOrder = 3
	for _, key in { "DoubleGrowth", "AutoCollect", "GoldenPlotVIP" } do
		local pass = MonetizationConfig.GamePasses[key]
		if pass and MonetizationConfig.isConfigured(pass.Id) then
			local _, passTitle, passDesc, passButton = makeRow(scroll, passOrder)
			local passId = pass.Id
			passTitle.Text = pass.Name
			passDesc.Text = string.format("Game Pass • R$%d", pass.SuggestedRobux)
			passButton.Text = "Robux"
			passButton.BackgroundColor3 = UITheme.Colors.Coin
			passButton.TextColor3 = Color3.new(0.1, 0.1, 0.1)
			-- Game passes are bought through the platform prompt, not a gameplay
			-- remote (the contract has no pass-purchase intent). Prompt directly;
			-- the server's MonetizationService is the authority on ownership.
			passButton.Activated:Connect(function()
				if not canPrompt() then
					return
				end
				-- IDs may be placeholder in Studio; fail silently per §23.
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(localPlayer, passId)
				end)
			end)
			passOrder += 1
		end
	end

	-- ── Fertilizer product (hidden when Id == 0) ──────────────────────────
	local fertilizer = MonetizationConfig.Products.FertilizerPack
	if fertilizer and MonetizationConfig.isConfigured(fertilizer.Id) then
		local _, fTitle, fDesc, fButton = makeRow(scroll, passOrder)
		fTitle.Text = fertilizer.Name
		fDesc.Text =
			string.format("%d charges • R$%d", fertilizer.Charges, fertilizer.SuggestedRobux)
		fButton.Text = "Robux"
		fButton.BackgroundColor3 = UITheme.Colors.Coin
		fButton.TextColor3 = Color3.new(0.1, 0.1, 0.1)
		fButton.Activated:Connect(function()
			if not canPrompt() then
				return
			end
			for _, cb in fertilizerCallbacks do
				cb()
			end
		end)
		passOrder += 1
	end

	-- ── Coin packs (hidden when Id == 0) ──────────────────────────────────
	for _, packKey in { "CoinPackSmall", "CoinPackMedium", "CoinPackLarge" } do
		local pack = MonetizationConfig.Products[packKey]
		if pack and MonetizationConfig.isConfigured(pack.Id) then
			local _, packTitle, packDesc, packButton = makeRow(scroll, passOrder)
			packTitle.Text = pack.Name
			packDesc.Text = string.format("+%d coins • R$%d", pack.Coins, pack.SuggestedRobux)
			packButton.Text = "Robux"
			packButton.BackgroundColor3 = UITheme.Colors.Coin
			packButton.TextColor3 = Color3.new(0.1, 0.1, 0.1)
			packButton.Activated:Connect(function()
				if not canPrompt() then
					return
				end
				for _, cb in coinPackCallbacks do
					cb(packKey)
				end
			end)
			passOrder += 1
		end
	end

	local function setData(snapshot: Snapshot)
		-- Slot row: read NextSlotCost from the server snapshot (never compute it).
		if snapshot.NextSlotCost ~= nil then
			slotDesc.Text = string.format(
				"Slot %d • %d coins",
				snapshot.UnlockedSlots + 1,
				snapshot.NextSlotCost
			)
			local affordable = snapshot.Coins >= snapshot.NextSlotCost
			slotButton.Text = "Buy"
			slotButton.Active = affordable
			slotButton.AutoButtonColor = affordable
			slotButton.BackgroundColor3 = if affordable
				then UITheme.Colors.Accent
				else UITheme.Colors.Locked
		else
			slotDesc.Text = "All slots unlocked!"
			slotButton.Text = "MAX"
			slotButton.Active = false
			slotButton.AutoButtonColor = false
			slotButton.BackgroundColor3 = UITheme.Colors.Locked
		end

		-- Rebirth row: requirement comes straight from the snapshot.
		local canRebirth = snapshot.Coins >= snapshot.RebirthRequirement
		rebirthDesc.Text =
			string.format("Needs %d coins • +50%% income", snapshot.RebirthRequirement)
		rebirthButton.Active = canRebirth
		rebirthButton.AutoButtonColor = canRebirth
		rebirthButton.BackgroundColor3 = if canRebirth
			then UITheme.Colors.Accent
			else UITheme.Colors.Locked
	end

	local function close()
		backdrop.Visible = false
	end

	closeButton.Activated:Connect(close)
	backdrop.Activated:Connect(close)

	local controller: ShopPanelController = {
		instance = root,
		open = function(snapshot: Snapshot)
			setData(snapshot)
			backdrop.Visible = true
		end,
		close = close,
		isOpen = function(): boolean
			return backdrop.Visible
		end,
		setData = setData,
		onBuySlot = function(callback: () -> ())
			table.insert(buySlotCallbacks, callback)
		end,
		onRebirth = function(callback: () -> ())
			table.insert(rebirthCallbacks, callback)
		end,
		onBuyCoinPack = function(callback: (packKey: string) -> ())
			table.insert(coinPackCallbacks, callback)
		end,
		onBuyFertilizer = function(callback: () -> ())
			table.insert(fertilizerCallbacks, callback)
		end,
		setMonetizationGate = function(gate: () -> boolean)
			canPrompt = gate
		end,
	}

	return controller
end

return ShopPanel
