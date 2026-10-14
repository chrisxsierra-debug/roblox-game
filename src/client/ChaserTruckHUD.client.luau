--!strict
-- ChaserTruckHUD.client.luau
-- Inspired by roblox-game-skill GUI & vehicle controller patterns
-- Displays dynamic Speedometer (MPH), Nitro Boost (Shift), and Hydraulic Anchors (X) when driving

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

-- Create Vehicle HUD
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "ChaserTruckHUD"
hudGui.ResetOnSpawn = false
hudGui.Parent = playerGui

local dashboard = Instance.new("Frame")
dashboard.Name = "Dashboard"
dashboard.Size = UDim2.new(0, 260, 0, 100)
dashboard.Position = UDim2.new(0.5, -130, 1, 20) -- Offscreen bottom when walking
dashboard.BackgroundColor3 = Color3.fromRGB(15, 20, 26)
dashboard.BackgroundTransparency = 0.2
dashboard.BorderSizePixel = 0
dashboard.Parent = hudGui

Instance.new("UICorner", dashboard).CornerRadius = UDim.new(0, 12)
local dashStroke = Instance.new("UIStroke")
dashStroke.Color = Color3.fromRGB(0, 180, 255)
dashStroke.Thickness = 2
dashStroke.Parent = dashboard

-- Speedometer Label
local speedLabel = Instance.new("TextLabel")
speedLabel.Name = "SpeedLabel"
speedLabel.Size = UDim2.new(0.5, 0, 0.6, 0)
speedLabel.Position = UDim2.new(0, 10, 0, 5)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "0"
speedLabel.TextColor3 = Color3.fromRGB(240, 250, 255)
speedLabel.TextScaled = true
speedLabel.Font = Enum.Font.GothamBold
speedLabel.Parent = dashboard

local mphUnit = Instance.new("TextLabel")
mphUnit.Name = "MphUnit"
mphUnit.Size = UDim2.new(0.5, 0, 0.3, 0)
mphUnit.Position = UDim2.new(0, 10, 0.6, 0)
mphUnit.BackgroundTransparency = 1
mphUnit.Text = "MPH"
mphUnit.TextColor3 = Color3.fromRGB(130, 160, 180)
mphUnit.TextScaled = true
mphUnit.Font = Enum.Font.Gotham
mphUnit.Parent = dashboard

-- Nitro Button / Status
local nitroBtn = Instance.new("TextButton")
nitroBtn.Name = "NitroButton"
nitroBtn.Size = UDim2.new(0.45, 0, 0.4, 0)
nitroBtn.Position = UDim2.new(0.52, 0, 0.1, 0)
nitroBtn.BackgroundColor3 = Color3.fromRGB(20, 45, 75)
nitroBtn.Text = "⚡ NITRO (Shift)"
nitroBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
nitroBtn.TextScaled = true
nitroBtn.Font = Enum.Font.GothamBold
nitroBtn.Parent = dashboard
Instance.new("UICorner", nitroBtn).CornerRadius = UDim.new(0, 8)

-- Anchor Button / Status
local anchorBtn = Instance.new("TextButton")
anchorBtn.Name = "AnchorButton"
anchorBtn.Size = UDim2.new(0.45, 0, 0.4, 0)
anchorBtn.Position = UDim2.new(0.52, 0, 0.52, 0)
anchorBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 20)
anchorBtn.Text = "⚓ SPIKES (X)"
anchorBtn.TextColor3 = Color3.fromRGB(255, 170, 50)
anchorBtn.TextScaled = true
anchorBtn.Font = Enum.Font.GothamBold
anchorBtn.Parent = dashboard
Instance.new("UICorner", anchorBtn).CornerRadius = UDim.new(0, 8)

local inVehicle = false
local currentSeat: VehicleSeat? = nil

local function fireNitro()
	if not inVehicle then return end
	Network.TruckNitroRequest:FireServer()
end

local function fireAnchor()
	if not inVehicle then return end
	Network.TruckAnchorRequest:FireServer()
end

nitroBtn.MouseButton1Click:Connect(fireNitro)
anchorBtn.MouseButton1Click:Connect(fireAnchor)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inVehicle then return end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		fireNitro()
	elseif input.KeyCode == Enum.KeyCode.X then
		fireAnchor()
	end
end)

-- Monitor Seated State & Velocity
RunService.RenderStepped:Connect(function()
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local seat = humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		if not inVehicle then
			inVehicle = true
			currentSeat = seat
			-- Slide up
			TweenService:Create(dashboard, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -130, 1, -115)
			}):Play()
		end

		-- Calculate MPH (studs/sec to approximate MPH)
		local truckModel = seat.Parent :: Model?
		if truckModel and truckModel.PrimaryPart then
			local speedStuds = truckModel.PrimaryPart.AssemblyLinearVelocity.Magnitude
			local mph = math.floor(speedStuds * 0.68)
			speedLabel.Text = tostring(mph)

			local isNitro = truckModel:GetAttribute("NitroActive") == true
			local isAnchored = truckModel:GetAttribute("AnchoredSpikes") == true

			if isNitro then
				nitroBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
				nitroBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				nitroBtn.Text = "🔥 BOOSTING!"
			else
				nitroBtn.BackgroundColor3 = Color3.fromRGB(20, 45, 75)
				nitroBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
				nitroBtn.Text = "⚡ NITRO (Shift)"
			end

			if isAnchored then
				anchorBtn.BackgroundColor3 = Color3.fromRGB(255, 120, 0)
				anchorBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				anchorBtn.Text = "🔒 LOCKED (X)"
				dashStroke.Color = Color3.fromRGB(255, 140, 20)
			else
				anchorBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 20)
				anchorBtn.TextColor3 = Color3.fromRGB(255, 170, 50)
				anchorBtn.Text = "⚓ SPIKES (X)"
				dashStroke.Color = Color3.fromRGB(0, 180, 255)
			end
		end
	else
		if inVehicle then
			inVehicle = false
			currentSeat = nil
			-- Slide down
			TweenService:Create(dashboard, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, -130, 1, 20)
			}):Play()
		end
	end
end)

print("[ChaserTruckHUD] Truck dashboard HUD initialized (Speedometer, Nitro, Anchor Spikes).")

