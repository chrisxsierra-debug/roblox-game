--!strict
-- DynamicAtmosphereController.client.luau
-- Inspired by roblox-game-skill AtmosphereController
-- Dynamically morphs lighting, atmosphere fog, and audio based on tornado proximity

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

-- Create or fetch post-processing effects
local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "StormColorCorrection"
	colorCorrection.Parent = Lighting
end

local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "StormAtmosphere"
	atmosphere.Parent = Lighting
end

-- Preset configurations adapted from roblox-game-skill
local PRESETS = {
	FairWeather = {
		Ambient = Color3.fromRGB(90, 95, 105),
		OutdoorAmbient = Color3.fromRGB(90, 95, 105),
		Brightness = 1.6,
		FogEnd = 500,
		FogColor = Color3.fromRGB(140, 150, 160),
		ColorCorrection = {
			Brightness = 0.0,
			Contrast = 0.05,
			Saturation = 0.0,
			TintColor = Color3.fromRGB(245, 248, 255),
		},
		Atmosphere = {
			Density = 0.20,
			Offset = 0,
			Color = Color3.fromRGB(150, 160, 175),
			Decay = Color3.fromRGB(110, 120, 135),
			Glare = 0.1,
			Haze = 1.5,
		},
	},

	Approaching = {
		Ambient = Color3.fromRGB(50, 55, 65),
		OutdoorAmbient = Color3.fromRGB(50, 55, 65),
		Brightness = 0.8,
		FogEnd = 240,
		FogColor = Color3.fromRGB(80, 95, 85), -- Classic greenish supercell tint
		ColorCorrection = {
			Brightness = -0.05,
			Contrast = 0.18,
			Saturation = -0.25,
			TintColor = Color3.fromRGB(210, 230, 215),
		},
		Atmosphere = {
			Density = 0.38,
			Offset = 0,
			Color = Color3.fromRGB(90, 105, 95),
			Decay = Color3.fromRGB(60, 75, 65),
			Glare = 0,
			Haze = 3.5,
		},
	},

	Warning = {
		Ambient = Color3.fromRGB(25, 28, 35),
		OutdoorAmbient = Color3.fromRGB(25, 28, 35),
		Brightness = 0.3,
		FogEnd = 120,
		FogColor = Color3.fromRGB(45, 55, 50),
		ColorCorrection = {
			Brightness = -0.12,
			Contrast = 0.30,
			Saturation = -0.45,
			TintColor = Color3.fromRGB(180, 205, 190),
		},
		Atmosphere = {
			Density = 0.55,
			Offset = 0,
			Color = Color3.fromRGB(50, 60, 55),
			Decay = Color3.fromRGB(35, 45, 40),
			Glare = 0,
			Haze = 6.0,
		},
	},

	CoreImpact = {
		Ambient = Color3.fromRGB(8, 10, 12),
		OutdoorAmbient = Color3.fromRGB(8, 10, 12),
		Brightness = 0.05,
		FogEnd = 50,
		FogColor = Color3.fromRGB(20, 22, 20),
		ColorCorrection = {
			Brightness = -0.22,
			Contrast = 0.45,
			Saturation = -0.70,
			TintColor = Color3.fromRGB(150, 160, 155),
		},
		Atmosphere = {
			Density = 0.78,
			Offset = 0,
			Color = Color3.fromRGB(25, 30, 28),
			Decay = Color3.fromRGB(15, 18, 16),
			Glare = 0,
			Haze = 10.0,
		},
	},
}

local currentPreset = "FairWeather"
local activeTweens: { [string]: Tween } = {}

local function applyPreset(name: string, duration: number)
	if currentPreset == name then return end
	currentPreset = name
	local p = PRESETS[name]
	if not p then return end

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local t1 = TweenService:Create(Lighting, tweenInfo, {
		Ambient = p.Ambient,
		OutdoorAmbient = p.OutdoorAmbient,
		Brightness = p.Brightness,
		FogEnd = p.FogEnd,
		FogColor = p.FogColor,
	})
	t1:Play()

	local t2 = TweenService:Create(colorCorrection, tweenInfo, {
		Brightness = p.ColorCorrection.Brightness,
		Contrast = p.ColorCorrection.Contrast,
		Saturation = p.ColorCorrection.Saturation,
		TintColor = p.ColorCorrection.TintColor,
	})
	t2:Play()

	local t3 = TweenService:Create(atmosphere, tweenInfo, {
		Density = p.Atmosphere.Density,
		Offset = p.Atmosphere.Offset,
		Color = p.Atmosphere.Color,
		Decay = p.Atmosphere.Decay,
		Glare = p.Atmosphere.Glare,
		Haze = p.Atmosphere.Haze,
	})
	t3:Play()
end

-- Audio Setup
local windSound = Instance.new("Sound")
windSound.Name = "StormWindAmbient"
windSound.SoundId = "rbxassetid://9114223174"
windSound.Looped = true
windSound.Volume = 0.1
windSound.Parent = SoundService
windSound:Play()

local sirenSound = Instance.new("Sound")
sirenSound.Name = "CountyTornadoSiren"
sirenSound.SoundId = "rbxassetid://9114223846"
sirenSound.Looped = true
sirenSound.Volume = 0
sirenSound.Parent = SoundService

Network.SirenState.OnClientEvent:Connect(function(active: boolean)
	if active then
		sirenSound:Play()
		TweenService:Create(sirenSound, TweenInfo.new(3), { Volume = 0.8 }):Play()
	else
		local fade = TweenService:Create(sirenSound, TweenInfo.new(3), { Volume = 0 })
		fade:Play()
		fade.Completed:Connect(function()
			sirenSound:Stop()
		end)
	end
end)

-- Lightning Flash Effect
Network.LightningStrike.OnClientEvent:Connect(function(_strikePos)
	-- Instant flash
	colorCorrection.Brightness = 0.6
	colorCorrection.Contrast = 0.6
	Lighting.Brightness = 8

	-- Rapid fade back
	TweenService:Create(colorCorrection, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = PRESETS[currentPreset].ColorCorrection.Brightness,
		Contrast = PRESETS[currentPreset].ColorCorrection.Contrast,
	}):Play()
	TweenService:Create(Lighting, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = PRESETS[currentPreset].Brightness,
	}):Play()
end)

-- Find VortexRoot
local function getVortexRoot(): BasePart?
	local wf = Workspace:FindFirstChild("FunnelRunnersWorld")
	if wf then
		local vm = wf:FindFirstChild("FunnelRunnersVortex")
		if vm then
			return vm:FindFirstChild("VortexRoot") :: BasePart?
		end
	end
	return nil
end

-- Proximity loop
local lastUpdate = 0
RunService.RenderStepped:Connect(function(dt)
	lastUpdate += dt
	if lastUpdate < 0.5 then return end
	lastUpdate = 0

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local vortex = getVortexRoot()
	if not vortex then
		applyPreset("FairWeather", 3)
		windSound.Volume = 0.1
		return
	end

	local dist = (root.Position - vortex.Position).Magnitude

	-- Scale wind audio smoothly based on distance
	local targetWindVol = math.clamp(1.5 - (dist / 400), 0.1, 1.2)
	TweenService:Create(windSound, TweenInfo.new(0.5), { Volume = targetWindVol }):Play()

	-- Preset selection based on distance
	if dist < 120 then
		applyPreset("CoreImpact", 1.5)
	elseif dist < 260 then
		applyPreset("Warning", 2.0)
	elseif dist < 500 then
		applyPreset("Approaching", 3.0)
	else
		applyPreset("FairWeather", 4.0)
	end
end)

print("[DynamicAtmosphereController] Atmosphere controller active with distance-based supercell lighting.")
