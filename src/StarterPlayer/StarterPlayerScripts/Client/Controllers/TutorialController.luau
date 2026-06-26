--!strict
-- TutorialController — drives the onboarding UI from TutorialUpdated events (§6, §25). TRACK B.
-- Highlights the first slot, shows the welcome + step prompts, and never shows
-- Robux prompts during the tutorial. Display only — the server owns tutorial state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))
local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

local TutorialController = {}
TutorialController.Name = "TutorialController"

-- True while the tutorial is incomplete; consulted to suppress Robux prompts (§6).
local tutorialActive = true

local promptBanner: TextLabel? = nil
local highlighting = false

-- Other controllers ask this before opening any monetization flow mid-tutorial.
function TutorialController.isTutorialActive(): boolean
	return tutorialActive
end

local function ensureBanner(): TextLabel
	if promptBanner then
		return promptBanner
	end
	local screenGui = UIController.getScreenGui()

	local banner = Instance.new("TextLabel")
	banner.Name = "TutorialBanner"
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -(UITheme.Sizing.SafeAreaPaddingPx + 300))
	banner.Size = UDim2.new(1, -UITheme.Sizing.SafeAreaPaddingPx * 2, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.BackgroundColor3 = UITheme.Colors.Accent
	banner.Font = UITheme.Fonts.Heading
	banner.TextColor3 = UITheme.Colors.Text
	banner.TextSize = 18
	banner.TextWrapped = true
	banner.Text = ""
	banner.Visible = false
	banner.ZIndex = 50
	banner.Parent = screenGui

	UITheme.applyPanel(banner)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = banner

	promptBanner = banner
	return banner
end

-- A gentle pulsing highlight over the player's first grow slot in 3D, so the
-- newcomer knows where to tap (§6). Display-only Highlight instance.
local function highlightFirstSlot()
	if highlighting then
		return
	end
	highlighting = true

	task.spawn(function()
		local deadline = os.clock() + 30
		while os.clock() < deadline and tutorialActive do
			for _, inst in CollectionService:GetTagged(Constants.Tags.GrowSlot) do
				if
					inst:IsA("BasePart")
					and inst:GetAttribute(Constants.Attributes.SlotIndex) == 1
				then
					if not inst:FindFirstChild("TutorialHighlight") then
						local hl = Instance.new("Highlight")
						hl.Name = "TutorialHighlight"
						hl.FillColor = UITheme.Colors.Accent
						hl.FillTransparency = 0.6
						hl.OutlineColor = UITheme.Colors.AccentAlt
						hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						hl.Parent = inst
					end
					highlighting = false
					return
				end
			end
			task.wait(0.5)
		end
		highlighting = false
	end)
end

local function clearHighlight()
	for _, inst in CollectionService:GetTagged(Constants.Tags.GrowSlot) do
		local hl = inst:FindFirstChild("TutorialHighlight")
		if hl then
			hl:Destroy()
		end
	end
end

local function onTutorialUpdated(step: number, completed: boolean, prompt: string?)
	tutorialActive = not completed

	local banner = ensureBanner()
	if completed then
		banner.Text = "Tutorial complete — happy farming!"
		banner.Visible = true
		clearHighlight()
		task.delay(4, function()
			if promptBanner then
				promptBanner.Visible = false
			end
		end)
		return
	end

	-- Welcome on the first step; otherwise show the server-provided step prompt.
	local text = prompt
	if not text or text == "" then
		if step <= 1 then
			text = "Welcome! Tap the glowing slot to plant your first seed."
		else
			text = string.format("Step %d", step)
		end
	end
	banner.Text = text
	banner.Visible = true

	-- Always keep slot 1 highlighted until the tutorial finishes.
	highlightFirstSlot()
end

function TutorialController.Init() end

function TutorialController.Start()
	-- Suppress Robux prompts while the tutorial is active (§6). The ShopPanel asks
	-- this gate before opening any platform purchase.
	local shopPanel = UIController.getShopPanel()
	if shopPanel and shopPanel.setMonetizationGate then
		shopPanel.setMonetizationGate(function(): boolean
			return not tutorialActive
		end)
	end

	Remotes.Events[Constants.Remotes.TutorialUpdated].OnClientEvent:Connect(onTutorialUpdated)
end

return TutorialController
