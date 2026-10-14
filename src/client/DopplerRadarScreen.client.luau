--!strict
-- DopplerRadarScreen.client.luau
-- Implements ADopplerRadar client HUD, sweep radar widget, signal distortion, and tornado warnings

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DopplerRadarHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- --- Circular Doppler Radar Unit (Bottom-Right) ---
local radarContainer = Instance.new("Frame")
radarContainer.Name = "RadarUnit"
radarContainer.Size = UDim2.new(0, 220, 0, 260)
radarContainer.Position = UDim2.new(1, -240, 1, -280)
radarContainer.BackgroundColor3 = Color3.fromRGB(15, 20, 22)
radarContainer.BorderSizePixel = 0
radarContainer.Parent = screenGui

local cCorner = Instance.new("UICorner")
cCorner.CornerRadius = UDim.new(0, 14)
cCorner.Parent = radarContainer

local cStroke = Instance.new("UIStroke")
cStroke.Color = Color3.fromRGB(0, 255, 150)
cStroke.Thickness = 2.5
cStroke.Parent = radarContainer

-- Header
local radarTitle = Instance.new("TextLabel")
radarTitle.Size = UDim2.new(1, -20, 0, 26)
radarTitle.Position = UDim2.new(0, 10, 0, 8)
radarTitle.BackgroundTransparency = 1
radarTitle.Text = "📡 WX-8000 DOPPLER"
radarTitle.TextColor3 = Color3.fromRGB(0, 255, 170)
radarTitle.Font = Enum.Font.GothamBlack
radarTitle.TextSize = 13
radarTitle.TextXAlignment = Enum.TextXAlignment.Left
radarTitle.Parent = radarContainer

-- Circular Scope
local scope = Instance.new("Frame")
scope.Name = "RadarScope"
scope.Size = UDim2.new(0, 130, 0, 130)
scope.Position = UDim2.new(0.5, -65, 0, 36)
scope.BackgroundColor3 = Color3.fromRGB(10, 25, 15)
scope.BorderSizePixel = 0
scope.Parent = radarContainer

local sCorner = Instance.new("UICorner")
sCorner.CornerRadius = UDim.new(1, 0)
sCorner.Parent = scope

local sStroke = Instance.new("UIStroke")
sStroke.Color = Color3.fromRGB(0, 200, 100)
sStroke.Thickness = 1.5
sStroke.Parent = scope

-- Rotating Sweep Needle
local sweep = Instance.new("Frame")
sweep.Name = "SweepNeedle"
sweep.Size = UDim2.new(0, 65, 0, 2)
sweep.Position = UDim2.new(0.5, 0, 0.5, -1)
sweep.AnchorPoint = Vector2.new(0, 0.5)
sweep.BackgroundColor3 = Color3.fromRGB(50, 255, 150)
sweep.BorderSizePixel = 0
sweep.Parent = scope

-- Tornado Blip
local blip = Instance.new("Frame")
blip.Name = "TornadoBlip"
blip.Size = UDim2.new(0, 10, 0, 10)
blip.AnchorPoint = Vector2.new(0.5, 0.5)
blip.Position = UDim2.new(0.5, 0, 0.5, 0)
blip.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
blip.BorderSizePixel = 0
blip.Visible = false
blip.Parent = scope

local bCorner = Instance.new("UICorner")
bCorner.CornerRadius = UDim.new(1, 0)
bCorner.Parent = blip

-- Telemetry Readouts
local catLabel = Instance.new("TextLabel")
catLabel.Size = UDim2.new(1, -20, 0, 22)
catLabel.Position = UDim2.new(0, 10, 0, 172)
catLabel.BackgroundTransparency = 1
catLabel.Text = "TIER: FORECASTING..."
catLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
catLabel.Font = Enum.Font.GothamBold
catLabel.TextSize = 13
catLabel.TextXAlignment = Enum.TextXAlignment.Left
catLabel.Parent = radarContainer

local windLabel = Instance.new("TextLabel")
windLabel.Size = UDim2.new(1, -20, 0, 20)
windLabel.Position = UDim2.new(0, 10, 0, 196)
windLabel.BackgroundTransparency = 1
windLabel.Text = "WIND: -- MPH"
windLabel.TextColor3 = Color3.fromRGB(220, 230, 240)
windLabel.Font = Enum.Font.GothamMedium
windLabel.TextSize = 12
windLabel.TextXAlignment = Enum.TextXAlignment.Left
windLabel.Parent = radarContainer

local distLabel = Instance.new("TextLabel")
distLabel.Size = UDim2.new(1, -20, 0, 20)
distLabel.Position = UDim2.new(0, 10, 0, 218)
distLabel.BackgroundTransparency = 1
distLabel.Text = "EYE DIST: -- STUDS"
distLabel.TextColor3 = Color3.fromRGB(0, 230, 255)
distLabel.Font = Enum.Font.GothamMedium
distLabel.TextSize = 12
distLabel.TextXAlignment = Enum.TextXAlignment.Left
distLabel.Parent = radarContainer

local pressLabel = Instance.new("TextLabel")
pressLabel.Size = UDim2.new(1, -20, 0, 20)
pressLabel.Position = UDim2.new(0, 10, 0, 238)
pressLabel.BackgroundTransparency = 1
pressLabel.Text = "PRESSURE: 980 hPa"
pressLabel.TextColor3 = Color3.fromRGB(180, 190, 200)
pressLabel.Font = Enum.Font.Gotham
pressLabel.TextSize = 11
pressLabel.TextXAlignment = Enum.TextXAlignment.Left
pressLabel.Parent = radarContainer

-- --- Emergency Sirens & Banners ---
local emergencyBanner = Instance.new("Frame")
emergencyBanner.Name = "EmergencyBanner"
emergencyBanner.Size = UDim2.new(0, 520, 0, 60)
emergencyBanner.Position = UDim2.new(0.5, -260, 0, 18)
emergencyBanner.BackgroundColor3 = Color3.fromRGB(50, 12, 12)
emergencyBanner.BorderSizePixel = 0
emergencyBanner.Visible = false
emergencyBanner.Parent = screenGui

local eCorner = Instance.new("UICorner")
eCorner.CornerRadius = UDim.new(0, 10)
eCorner.Parent = emergencyBanner

local eStroke = Instance.new("UIStroke")
eStroke.Color = Color3.fromRGB(255, 40, 40)
eStroke.Thickness = 3
eStroke.Parent = emergencyBanner

local emergencyText = Instance.new("TextLabel")
emergencyText.Size = UDim2.new(1, 0, 1, 0)
emergencyText.BackgroundTransparency = 1
emergencyText.Text = "🚨 TORNADO WARNING: MONSTER EF5 TOUCHDOWN IMMINENT"
emergencyText.TextColor3 = Color3.fromRGB(255, 80, 80)
emergencyText.Font = Enum.Font.GothamBlack
emergencyText.TextSize = 16
emergencyText.Parent = emergencyBanner

-- Rotate Sweep Line
local sweepAngle = 0
RunService.RenderStepped:Connect(function(dt)
	sweepAngle = (sweepAngle + (120 * dt)) % 360
	sweep.Rotation = sweepAngle
end)

-- Doppler Telemetry Stream Listener
Network.DopplerTelemetry.OnClientEvent:Connect(function(vortexPos: Vector3, cat: string, wind: number, name: string, isFinal: boolean)
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
		if root then
			local delta = (vortexPos - root.Position)
			local dist = math.floor(delta.Magnitude)

			distLabel.Text = string.format("EYE DIST: %d STUDS", dist)
			windLabel.Text = string.format("WIND: %d MPH", wind)
			catLabel.Text = "TIER: " .. string.upper(cat)
			pressLabel.Text = string.format("PRESSURE: %d hPa", 1013 - math.floor((1 - math.clamp(dist / 300, 0, 1)) * 95))

			-- Update Radar Blip Position relative to player orientation
			blip.Visible = true
			local forward = root.CFrame.LookVector
			local right = root.CFrame.RightVector
			local localX = delta:Dot(right)
			local localZ = -delta:Dot(forward)

			local maxRadarDist = 300
			local normX = math.clamp(localX / maxRadarDist, -0.9, 0.9)
			local normZ = math.clamp(localZ / maxRadarDist, -0.9, 0.9)

			blip.Position = UDim2.new(0.5 + (normX * 0.45), 0, 0.5 + (normZ * 0.45), 0)

			-- Emergency Styling during Final EF5
			if isFinal then
				emergencyBanner.Visible = true
				cStroke.Color = Color3.fromRGB(255, 50, 50)
				catLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
			else
				emergencyBanner.Visible = false
				cStroke.Color = Color3.fromRGB(0, 255, 150)
				catLabel.TextColor3 = Color3.fromRGB(255, 200, 40)
			end
		end
	end
end)

print("[Client] DopplerRadarScreen online.")

