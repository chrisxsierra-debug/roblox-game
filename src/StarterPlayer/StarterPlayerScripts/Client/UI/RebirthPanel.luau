--!strict
-- RebirthPanel — rebirth confirmation dialog (§10, §19). TRACK B.
-- Shows the server-computed requirement and what resets vs persists; requires an
-- explicit confirm before firing RequestRebirth.
--
-- The requirement and affordability are read from the DataSnapshot — the client
-- never computes them. Confirm fires RequestRebirth() (no payload); the server
-- validates affordability + cooldown.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local EconomyConfig = require(Config:WaitForChild("EconomyConfig"))

local UITheme = require(script.Parent:WaitForChild("UITheme"))

type Snapshot = {
	Coins: number,
	Rebirths: number,
	RebirthRequirement: number,
	[string]: any,
}

export type RebirthPanelController = {
	instance: Frame,
	open: (snapshot: Snapshot) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	onConfirm: (callback: () -> ()) -> (),
}

local RebirthPanel = {}

function RebirthPanel.create(parent: Instance): RebirthPanelController
	local confirmCallbacks: { () -> () } = {}

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "RebirthBackdrop"
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.4
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.Visible = false
	backdrop.ZIndex = 30
	backdrop.Parent = parent

	local root = Instance.new("Frame")
	root.Name = "RebirthPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0, 360)
	root.BackgroundColor3 = UITheme.Colors.Panel
	root.ZIndex = 31
	root.Parent = backdrop
	UITheme.applyPanel(root)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 16)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Font = UITheme.Fonts.Heading
	title.TextColor3 = UITheme.Colors.Accent
	title.TextSize = 28
	title.Text = "Rebirth?"
	title.LayoutOrder = 1
	title.ZIndex = 31
	title.Parent = root

	local requirement = Instance.new("TextLabel")
	requirement.Name = "Requirement"
	requirement.BackgroundTransparency = 1
	requirement.Size = UDim2.new(1, 0, 0, 26)
	requirement.Font = UITheme.Fonts.Number
	requirement.TextColor3 = UITheme.Colors.Coin
	requirement.TextSize = 18
	requirement.Text = ""
	requirement.LayoutOrder = 2
	requirement.ZIndex = 31
	requirement.Parent = root

	local resets = Instance.new("TextLabel")
	resets.Name = "Resets"
	resets.BackgroundTransparency = 1
	resets.Size = UDim2.new(1, 0, 0, 120)
	resets.Font = UITheme.Fonts.Body
	resets.TextColor3 = UITheme.Colors.Text
	resets.TextSize = 15
	resets.TextXAlignment = Enum.TextXAlignment.Left
	resets.TextYAlignment = Enum.TextYAlignment.Top
	resets.TextWrapped = true
	resets.RichText = true
	resets.Text = string.format(
		"<b>Resets:</b> Coins → %d, Slots → %d, all crops cleared.\n\n"
			.. "<b>Keeps:</b> Lifetime Coins, every seed unlock, and your rebirth bonus."
			.. " Each rebirth adds <b>+50%%</b> permanent income.",
		EconomyConfig.RebirthResetCoins,
		EconomyConfig.RebirthResetSlots
	)
	resets.LayoutOrder = 3
	resets.ZIndex = 31
	resets.Parent = root

	-- Button row: explicit Cancel + Confirm (§19 requires explicit confirm).
	local buttonRow = Instance.new("Frame")
	buttonRow.Name = "Buttons"
	buttonRow.BackgroundTransparency = 1
	buttonRow.Size = UDim2.new(1, 0, 0, UITheme.Sizing.MinButtonHeightPx)
	buttonRow.LayoutOrder = 4
	buttonRow.ZIndex = 31
	buttonRow.Parent = root

	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.Padding = UDim.new(0, 12)
	rowList.Parent = buttonRow

	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "Cancel"
	cancelButton.Size = UDim2.new(0.5, -6, 1, 0)
	cancelButton.BackgroundColor3 = UITheme.Colors.PanelLight
	cancelButton.Font = UITheme.Fonts.Heading
	cancelButton.TextColor3 = UITheme.Colors.Text
	cancelButton.TextSize = 18
	cancelButton.Text = "Cancel"
	cancelButton.ZIndex = 32
	cancelButton.Parent = buttonRow
	UITheme.applyPanel(cancelButton)

	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "Confirm"
	confirmButton.Size = UDim2.new(0.5, -6, 1, 0)
	confirmButton.BackgroundColor3 = UITheme.Colors.Accent
	confirmButton.Font = UITheme.Fonts.Heading
	confirmButton.TextColor3 = UITheme.Colors.Text
	confirmButton.TextSize = 18
	confirmButton.Text = "Rebirth!"
	confirmButton.ZIndex = 32
	confirmButton.Parent = buttonRow
	UITheme.applyPanel(confirmButton)

	local function close()
		backdrop.Visible = false
	end

	cancelButton.Activated:Connect(close)
	backdrop.Activated:Connect(close)

	confirmButton.Activated:Connect(function()
		if not confirmButton.Active then
			return
		end
		close()
		for _, cb in confirmCallbacks do
			cb()
		end
	end)

	local controller: RebirthPanelController = {
		instance = root,
		open = function(snapshot: Snapshot)
			local need = snapshot.RebirthRequirement
			local canRebirth = snapshot.Coins >= need
			requirement.Text =
				string.format("Requires %d coins (you have %d)", need, snapshot.Coins)
			requirement.TextColor3 = if canRebirth
				then UITheme.Colors.Success
				else UITheme.Colors.Danger
			confirmButton.Active = canRebirth
			confirmButton.AutoButtonColor = canRebirth
			confirmButton.BackgroundColor3 = if canRebirth
				then UITheme.Colors.Accent
				else UITheme.Colors.Locked
			backdrop.Visible = true
		end,
		close = close,
		isOpen = function(): boolean
			return backdrop.Visible
		end,
		onConfirm = function(callback: () -> ())
			table.insert(confirmCallbacks, callback)
		end,
	}

	return controller
end

return RebirthPanel
