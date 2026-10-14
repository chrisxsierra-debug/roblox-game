--!strict
-- ChaserFlashlightController.client.luau
-- Inspired by roblox-game-skill FlashlightController
-- Provides heavy-duty storm-chaser headlamp / spotlight toggled with 'F' key

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local flashlightOn = false
local currentSpotlight: SpotLight? = nil
local currentFillLight: PointLight? = nil

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
		light.Brightness = 10
		light.Range = 140
		light.Angle = 70
		light.Color = Color3.fromRGB(255, 252, 240)
		light.Face = Enum.NormalId.Front
		light.Shadows = true
		light.Parent = root
		currentSpotlight = light

		local fill = Instance.new("PointLight")
		fill.Name = "ChaserFlashlightFill"
		fill.Brightness = 1.2
		fill.Range = 20
		fill.Color = Color3.fromRGB(255, 250, 235)
		fill.Parent = root
		currentFillLight = fill
	else
		if currentSpotlight then
			currentSpotlight:Destroy()
			currentSpotlight = nil
		end
		if currentFillLight then
			currentFillLight:Destroy()
			currentFillLight = nil
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
	local pgui = player:WaitForChild("PlayerGui")
	local sg = Instance.new("ScreenGui")
	sg.Name = "FlashlightMobileGui"
	sg.ResetOnSpawn = false
	sg.Parent = pgui

	local flashBtn = Instance.new("TextButton")
	flashBtn.Name = "FlashlightButton"
	flashBtn.Size = UDim2.new(0, 50, 0, 50)
	flashBtn.Position = UDim2.new(0.9, -60, 0.7, 0)
	flashBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	flashBtn.Text = "🔦"
	flashBtn.TextSize = 24
	flashBtn.Parent = sg
	Instance.new("UICorner", flashBtn).CornerRadius = UDim.new(0.5, 0)
	flashBtn.MouseButton1Click:Connect(toggleFlashlight)
end

print("[ChaserFlashlightController] Chaser Flashlight active (Press F to toggle).")

