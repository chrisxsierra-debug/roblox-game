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

-- Helper getters to ensure we always target active instances in Lighting
local function getColorCorrection(): ColorCorrectionEffect
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "StormColorCorrection"
		cc.Parent = Lighting
	end
	return cc
end

local function getAtmosphere(): Atmosphere
	local at = Lighting:FindFirstChildOfClass("Atmosphere")
	if not at then
		at = Instance.new("Atmosphere")
		at.Name = "StormAtmosphere"
		at.Parent = Lighting
	end
	return at
end

-- Preset configurations: atmospheric, luminous Silent Hill fog
local PRESETS = {
	FairWeather = {
		Ambient = Color3.fromRGB(184, 192, 200),
		OutdoorAmbient = Color3.fromRGB(210, 218, 228),
		Brightness = 3.2,
		ExposureCompensation = 0.65,
		FogStart = 40,
		FogEnd = 350,
		FogColor = Color3.fromRGB(218, 224, 232),
		ColorCorrection = {
			Brightness = 0.05,
			Contrast = 0.14,
			Saturation = -0.15,
			TintColor = Color3.fromRGB(240, 246, 252),
		},
		Atmosphere = {
			Density = 0.38,
			Offset = 0.15,
			Color = Color3.fromRGB(218, 224, 232),
			Decay = Color3.fromRGB(190, 200, 210),
			Glare = 0.20,
			Haze = 0.25,
		},
	},

	Approaching = {
		Ambient = Color3.fromRGB(172, 180, 190),
		OutdoorAmbient = Color3.fromRGB(198, 206, 216),
		Brightness = 2.8,
		ExposureCompensation = 0.60,
		FogStart = 25,
		FogEnd = 240,
		FogColor = Color3.fromRGB(198, 208, 204), -- Eerie green/slate storm core tint
		ColorCorrection = {
			Brightness = 0.04,
			Contrast = 0.16,
			Saturation = -0.18,
			TintColor = Color3.fromRGB(235, 244, 240),
		},
		Atmosphere = {
			Density = 0.44,
			Offset = 0.14,
			Color = Color3.fromRGB(198, 210, 218),
			Decay = Color3.fromRGB(170, 182, 192),
			Glare = 0.15,
			Haze = 0.40,
		},
	},

	Warning = {
		Ambient = Color3.fromRGB(158, 166, 176),
		OutdoorAmbient = Color3.fromRGB(182, 190, 200),
		Brightness = 2.5,
		ExposureCompensation = 0.55,
		FogStart = 15,
		FogEnd = 160,
		FogColor = Color3.fromRGB(182, 194, 188),
		ColorCorrection = {
			Brightness = 0.03,
			Contrast = 0.18,
			Saturation = -0.20,
			TintColor = Color3.fromRGB(225, 238, 230),
		},
		Atmosphere = {
			Density = 0.52,
			Offset = 0.10,
			Color = Color3.fromRGB(178, 192, 200),
			Decay = Color3.fromRGB(148, 162, 172),
			Glare = 0.10,
			Haze = 0.55,
		},
	},

	CoreImpact = {
		Ambient = Color3.fromRGB(142, 150, 160),
		OutdoorAmbient = Color3.fromRGB(168, 176, 186),
		Brightness = 2.2,
		ExposureCompensation = 0.50,
		FogStart = 5,
		FogEnd = 90,
		FogColor = Color3.fromRGB(162, 176, 172),
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.22,
			Saturation = -0.22,
			TintColor = Color3.fromRGB(215, 230, 222),
		},
		Atmosphere = {
			Density = 0.65,
			Offset = 0.06,
			Color = Color3.fromRGB(158, 172, 182),
			Decay = Color3.fromRGB(132, 146, 156),
			Glare = 0,
			Haze = 0.85,
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

	local cc = getColorCorrection()
	local at = getAtmosphere()

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	local t1 = TweenService:Create(Lighting, tweenInfo, {
		Ambient = p.Ambient,
		OutdoorAmbient = p.OutdoorAmbient,
		Brightness = p.Brightness,
		ExposureCompensation = p.ExposureCompensation,
		FogStart = p.FogStart,
		FogEnd = p.FogEnd,
		FogColor = p.FogColor,
	})
	t1:Play()

	local t2 = TweenService:Create(cc, tweenInfo, {
		Brightness = p.ColorCorrection.Brightness,
		Contrast = p.ColorCorrection.Contrast,
		Saturation = p.ColorCorrection.Saturation,
		TintColor = p.ColorCorrection.TintColor,
	})
	t2:Play()

	local t3 = TweenService:Create(at, tweenInfo, {
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
	local cc = getColorCorrection()
	-- Instant flash
	cc.Brightness = 0.7
	cc.Contrast = 0.5
	Lighting.Brightness = 10

	-- Rapid fade back
	TweenService:Create(cc, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = PRESETS[currentPreset].ColorCorrection.Brightness,
		Contrast = PRESETS[currentPreset].ColorCorrection.Contrast,
	}):Play()
	TweenService:Create(Lighting, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = PRESETS[currentPreset].Brightness,
	}):Play()
end)

-- Find VortexRoot
-- Find Closest Storm Distance across all active vortices
local function getClosestStormDistance(playerPos: Vector3): number?
	local stormFolder = ReplicatedStorage:FindFirstChild("StormState")
	if not stormFolder then return nil end

	local closestDist: number? = nil
	for _, child in stormFolder:GetChildren() do
		local pos = child:GetAttribute("Position")
		if typeof(pos) == "Vector3" then
			local d = (playerPos - pos).Magnitude
			if closestDist == nil or d < closestDist then
				closestDist = d
			end
		end
	end
	return closestDist
end

-- Proximity loop
local lastUpdate = 0
RunService.RenderStepped:Connect(function(dt)
	lastUpdate += dt
	if lastUpdate < 0.3 then return end
	lastUpdate = 0

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	local dist = getClosestStormDistance(root.Position)
	if not dist then
		applyPreset("FairWeather", 3)
		windSound.Volume = 0.1
		return
	end

	-- Scale wind audio smoothly based on distance
	local targetWindVol = math.clamp(1.4 - (dist / 400), 0.1, 1.2)
	TweenService:Create(windSound, TweenInfo.new(0.4), { Volume = targetWindVol }):Play()

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
