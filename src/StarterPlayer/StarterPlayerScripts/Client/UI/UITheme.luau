--!strict
-- UITheme — shared colors, fonts, and sizing for a mobile-first UI (§19). TRACK B.
-- Fully implemented so every UI module pulls from one consistent theme.

local UITheme = {}

UITheme.Colors = {
	Background = Color3.fromRGB(28, 26, 38),
	Panel = Color3.fromRGB(40, 38, 56),
	PanelLight = Color3.fromRGB(56, 52, 78),
	Accent = Color3.fromRGB(150, 90, 245), -- brand purple
	AccentAlt = Color3.fromRGB(90, 230, 255),
	Coin = Color3.fromRGB(255, 215, 0),
	Success = Color3.fromRGB(110, 220, 130),
	Danger = Color3.fromRGB(235, 90, 110),
	Locked = Color3.fromRGB(90, 88, 100),
	Text = Color3.fromRGB(245, 245, 250),
	TextDim = Color3.fromRGB(180, 178, 195),
}

UITheme.Fonts = {
	Heading = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Number = Enum.Font.GothamBold,
}

-- Sizing aimed at thumb-reachable mobile targets (§19, §20).
UITheme.Sizing = {
	CornerRadius = UDim.new(0, 12),
	MinButtonHeightPx = 56, -- comfortable tap target
	HudPaddingPx = 12,
	SafeAreaPaddingPx = 16,
}

-- Helper: apply a rounded corner + padding to a frame using the theme.
function UITheme.applyPanel(frame: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UITheme.Sizing.CornerRadius
	corner.Parent = frame
end

return UITheme
