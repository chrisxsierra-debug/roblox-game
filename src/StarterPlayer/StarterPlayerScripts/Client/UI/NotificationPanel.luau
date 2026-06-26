--!strict
-- NotificationPanel — transient toasts + milestone messages (§25). TRACK B.
-- Renders Notification events (mutation reveals, milestones, "your crops kept
-- growing" return message). Non-blocking, auto-dismiss. Level 0 info, 1 toast,
-- 2 big.

local TweenService = game:GetService("TweenService")

local UITheme = require(script.Parent:WaitForChild("UITheme"))

export type NotificationController = {
	instance: Frame,
	push: (text: string, level: number) -> (),
}

local NotificationPanel = {}

local DISMISS_SECONDS = { [0] = 2.5, [1] = 3.5, [2] = 5.0 }

local function levelColor(level: number): Color3
	if level >= 2 then
		return UITheme.Colors.Accent
	elseif level == 1 then
		return UITheme.Colors.PanelLight
	end
	return UITheme.Colors.Panel
end

function NotificationPanel.create(parent: Instance): NotificationController
	local root = Instance.new("Frame")
	root.Name = "NotificationPanel"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0)
	-- Sits below the HUD, centered horizontally, stacking downward.
	root.Position = UDim2.new(0.5, 0, 0, 140)
	root.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.ZIndex = 40
	root.Parent = parent

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	local nextOrder = 0

	local function push(text: string, level: number)
		level = math.clamp(math.floor(level or 0), 0, 2)
		nextOrder += 1

		local toast = Instance.new("TextLabel")
		toast.Name = "Toast"
		toast.AutomaticSize = Enum.AutomaticSize.Y
		toast.Size = UDim2.fromScale(if level >= 2 then 1 else 0.85, 0)
		toast.BackgroundColor3 = levelColor(level)
		toast.BackgroundTransparency = 0
		toast.Font = if level >= 2 then UITheme.Fonts.Heading else UITheme.Fonts.Body
		toast.TextColor3 = UITheme.Colors.Text
		toast.TextSize = if level >= 2 then 22 else 16
		toast.TextWrapped = true
		toast.Text = text
		toast.LayoutOrder = nextOrder
		toast.ZIndex = 41
		toast.Parent = root
		UITheme.applyPanel(toast)

		local tpad = Instance.new("UIPadding")
		tpad.PaddingTop = UDim.new(0, 8)
		tpad.PaddingBottom = UDim.new(0, 8)
		tpad.PaddingLeft = UDim.new(0, 12)
		tpad.PaddingRight = UDim.new(0, 12)
		tpad.Parent = toast

		-- Gentle fade-in (no rapid flashing per §28).
		toast.TextTransparency = 1
		toast.BackgroundTransparency = 1
		local fadeIn = TweenService:Create(
			toast,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0, BackgroundTransparency = 0 }
		)
		fadeIn:Play()

		local dismissAfter = DISMISS_SECONDS[level] or 3
		task.delay(dismissAfter, function()
			if not toast.Parent then
				return
			end
			local fadeOut = TweenService:Create(
				toast,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1, BackgroundTransparency = 1 }
			)
			fadeOut.Completed:Connect(function()
				toast:Destroy()
			end)
			fadeOut:Play()
		end)
	end

	local controller: NotificationController = {
		instance = root,
		push = push,
	}

	return controller
end

return NotificationPanel
