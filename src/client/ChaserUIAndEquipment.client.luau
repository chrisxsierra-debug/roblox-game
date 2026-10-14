--!strict
-- ChaserUIAndEquipment.client.luau
-- Inspired by roblox-game-skill FlashlightController & GUI systems
-- Handles emergency alert banners and player storm flashlight (Key: F)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

-- 1. Create Top Alert Banner ScreenGui
local alertGui = Instance.new("ScreenGui")
alertGui.Name = "StormAlertGui"
alertGui.ResetOnSpawn = false
alertGui.Parent = playerGui

local alertBanner = Instance.new("Frame")
alertBanner.Name = "AlertBanner"
alertBanner.Size = UDim2.new(0.6, 0, 0, 50)
alertBanner.Position = UDim2.new(0.2, 0, 0, -60) -- Starts hidden offscreen
alertBanner.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
alertBanner.BackgroundTransparency = 0.15
alertBanner.BorderSizePixel = 0
alertBanner.Parent = alertGui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = alertBanner

local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(255, 60, 60)
bannerStroke.Thickness = 2
bannerStroke.Parent = alertBanner

local alertLabel = Instance.new("TextLabel")
alertLabel.Name = "AlertText"
alertLabel.Size = UDim2.new(1, -20, 1, 0)
alertLabel.Position = UDim2.new(0, 10, 0, 0)
alertLabel.BackgroundTransparency = 1
alertLabel.Text = "WEATHER NOTICE"
alertLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
alertLabel.TextScaled = true
alertLabel.Font = Enum.Font.GothamBold
alertLabel.Parent = alertBanner

-- Handle alert display
Network.StormAlert.OnClientEvent:Connect(function(message: string, duration: number)
	alertLabel.Text = message

	-- Determine border color based on warning vs calm
	if string.find(message, "WARNING") or string.find(message, "TOUCHDOWN") then
		bannerStroke.Color = Color3.fromRGB(255, 50, 50)
		-- Warning beep sound
		local alertTone = Instance.new("Sound")
		alertTone.SoundId = "rbxassetid://9114223846"
		alertTone.Volume = 0.5
		alertTone.Parent = SoundService
		alertTone:Play()
		task.delay(1.5, function() alertTone:Destroy() end)
	else
		bannerStroke.Color = Color3.fromRGB(80, 200, 120)
	end

	-- Slide down
	TweenService:Create(alertBanner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0, 15)
	}):Play()

	-- Slide up after duration
	task.delay(math.max(duration - 0.5, 3), function()
		TweenService:Create(alertBanner, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.2, 0, 0, -60)
		}):Play()
	end)
end)

-- 2. Chaser Storm Flashlight System (F key)
local flashlightOn = false
local currentSpotlight: SpotLight? = nil

local function toggleFlashlight()
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	flashlightOn = not flashlightOn

	-- Click sound
	local click = Instance.new("Sound")
	click.SoundId = "rbxassetid://9114221160"
	click.Volume = 0.6
	click.Parent = root
	click:Play()
	task.delay(0.5, function() click:Destroy() end)

	if flashlightOn then
		local light = Instance.new("SpotLight")
		light.Name = "ChaserFlashlightBeam"
		light.Brightness = 8
		light.Range = 90
		light.Angle = 65
		light.Color = Color3.fromRGB(245, 248, 255)
		light.Face = Enum.NormalId.Front
		light.Shadows = true
		light.Parent = root
		currentSpotlight = light
	else
		if currentSpotlight then
			currentSpotlight:Destroy()
			currentSpotlight = nil
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F then
		toggleFlashlight()
	end
end)

-- Mobile Flashlight Button
if UserInputService.TouchEnabled then
	local flashBtn = Instance.new("TextButton")
	flashBtn.Name = "FlashlightButton"
	flashBtn.Size = UDim2.new(0, 60, 0, 60)
	flashBtn.Position = UDim2.new(0.85, -30, 0.7, 0)
	flashBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 45)
	flashBtn.Text = "🔦"
	flashBtn.TextSize = 28
	flashBtn.Parent = alertGui
	Instance.new("UICorner", flashBtn).CornerRadius = UDim.new(0.5, 0)
	flashBtn.MouseButton1Click:Connect(toggleFlashlight)
end

print("[ChaserUIAndEquipment] Storm alerts & chaser flashlight (F) active.")
