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

-- Preset configurations: high-visibility daylight supercell atmosphere
local PRESETS = {
	FairWeather = {
		Ambient = Color3.fromRGB(128, 138, 150),
		OutdoorAmbient = Color3.fromRGB(160, 172, 185),
		Brightness = 2.8,
		ExposureCompensation = 0.35,
		FogEnd = 700,
		FogColor = Color3.fromRGB(175, 190, 205),
		ColorCorrection = {
			Brightness = 0.04,
			Contrast = 0.10,
			Saturation = 0.08,
			TintColor = Color3.fromRGB(252, 252, 255),
		},
		Atmosphere = {
			Density = 0.14,
			Offset = 0.25,
			Color = Color3.fromRGB(170, 185, 205),
			Decay = Color3.fromRGB(135, 150, 165),
			Glare = 0.15,
			Haze = 0.6,
		},
	},

	Approaching = {
		Ambient = Color3.fromRGB(118, 130, 142),
		OutdoorAmbient = Color3.fromRGB(150, 162, 172),
		Brightness = 2.5,
		ExposureCompensation = 0.30,
		FogEnd = 450,
		FogColor = Color3.fromRGB(145, 165, 155), -- Eerie green hail core tint
		ColorCorrection = {
			Brightness = 0.03,
			Contrast = 0.16,
			Saturation = 0.04,
			TintColor = Color3.fromRGB(240, 252, 242),
		},
		Atmosphere = {
			Density = 0.20,
			Offset = 0.20,
			Color = Color3.fromRGB(145, 165, 155),
			Decay = Color3.fromRGB(115, 135, 125),
			Glare = 0.05,
			Haze = 1.0,
		},
	},

	Warning = {
		Ambient = Color3.fromRGB(108, 120, 132),
		OutdoorAmbient = Color3.fromRGB(140, 152, 162),
		Brightness = 2.2,
		ExposureCompensation = 0.28,
		FogEnd = 320,
		FogColor = Color3.fromRGB(125, 145, 135),
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.20,
			Saturation = -0.02,
			TintColor = Color3.fromRGB(230, 246, 235),
		},
		Atmosphere = {
			Density = 0.26,
			Offset = 0.15,
			Color = Color3.fromRGB(125, 145, 135),
			Decay = Color3.fromRGB(100, 120, 110),
			Glare = 0,
			Haze = 1.4,
		},
	},

	CoreImpact = {
		Ambient = Color3.fromRGB(98, 112, 124),
		OutdoorAmbient = Color3.fromRGB(130, 144, 154),
		Brightness = 2.0, -- Always bright and visible!
		FogEnd = 240,    -- Clear visibility of the wedge funnel and terrain!
		FogColor = Color3.fromRGB(110, 128, 120),
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.24,
			Saturation = -0.06,
			TintColor = Color3.fromRGB(220, 238, 228),
		},
		Atmosphere = {
			Density = 0.32,
			Offset = 0.10,
			Color = Color3.fromRGB(110, 130, 120),
			Decay = Color3.fromRGB(85, 105, 95),
			Glare = 0,
			Haze = 1.8,
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
		ExposureCompensation = p.ExposureCompensation,
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
