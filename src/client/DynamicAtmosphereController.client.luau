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
		Ambient = Color3.fromRGB(180, 185, 195),
		OutdoorAmbient = Color3.fromRGB(205, 212, 222),
		Brightness = 3.2,
		ExposureCompensation = 0.65,
		FogEnd = 200,
		FogColor = Color3.fromRGB(212, 218, 225),
		ColorCorrection = {
			Brightness = 0.05,
			Contrast = 0.14,
			Saturation = -0.15,
			TintColor = Color3.fromRGB(240, 246, 252),
		},
		Atmosphere = {
			Density = 0.44,
			Offset = 0.18,
			Color = Color3.fromRGB(215, 222, 230),
			Decay = Color3.fromRGB(180, 190, 200),
			Glare = 0.25,
			Haze = 0.35,
		},
	},

	Approaching = {
		Ambient = Color3.fromRGB(168, 175, 185),
		OutdoorAmbient = Color3.fromRGB(195, 202, 212),
		Brightness = 2.8,
		ExposureCompensation = 0.60,
		FogEnd = 160,
		FogColor = Color3.fromRGB(195, 205, 200), -- Eerie green/slate storm core tint
		ColorCorrection = {
			Brightness = 0.04,
			Contrast = 0.16,
			Saturation = -0.18,
			TintColor = Color3.fromRGB(235, 244, 240),
		},
		Atmosphere = {
			Density = 0.50,
			Offset = 0.15,
			Color = Color3.fromRGB(195, 208, 215),
			Decay = Color3.fromRGB(165, 178, 188),
			Glare = 0.15,
			Haze = 0.5,
		},
	},

	Warning = {
		Ambient = Color3.fromRGB(155, 162, 172),
		OutdoorAmbient = Color3.fromRGB(180, 188, 198),
		Brightness = 2.5,
		ExposureCompensation = 0.55,
		FogEnd = 130,
		FogColor = Color3.fromRGB(180, 192, 185),
		ColorCorrection = {
			Brightness = 0.03,
			Contrast = 0.18,
			Saturation = -0.20,
			TintColor = Color3.fromRGB(225, 238, 230),
		},
		Atmosphere = {
			Density = 0.56,
			Offset = 0.12,
			Color = Color3.fromRGB(175, 190, 198),
			Decay = Color3.fromRGB(145, 160, 170),
			Glare = 0.1,
			Haze = 0.7,
		},
	},

	CoreImpact = {
		Ambient = Color3.fromRGB(140, 148, 158),
		OutdoorAmbient = Color3.fromRGB(165, 174, 184),
		Brightness = 2.2,
		ExposureCompensation = 0.50,
		FogEnd = 95,
		FogColor = Color3.fromRGB(160, 175, 170),
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.22,
			Saturation = -0.22,
			TintColor = Color3.fromRGB(215, 230, 222),
		},
		Atmosphere = {
			Density = 0.62,
			Offset = 0.08,
			Color = Color3.fromRGB(155, 170, 180),
			Decay = Color3.fromRGB(130, 145, 155),
			Glare = 0,
			Haze = 1.0,
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
