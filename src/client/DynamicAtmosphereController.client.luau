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

-- Preset configurations: bright, open daylight supercell atmosphere
local PRESETS = {
	FairWeather = {
		Ambient = Color3.fromRGB(195, 205, 215),
		OutdoorAmbient = Color3.fromRGB(220, 230, 240),
		Brightness = 3.8,
		ExposureCompensation = 0.85,
		FogEnd = 1200,
		FogColor = Color3.fromRGB(210, 225, 240),
		ColorCorrection = {
			Brightness = 0.10,
			Contrast = 0.06,
			Saturation = 0.12,
			TintColor = Color3.fromRGB(255, 255, 255),
		},
		Atmosphere = {
			Density = 0.06,
			Offset = 0.25,
			Color = Color3.fromRGB(195, 215, 235),
			Decay = Color3.fromRGB(165, 185, 205),
			Glare = 0.2,
			Haze = 0.1,
		},
	},

	Approaching = {
		Ambient = Color3.fromRGB(185, 198, 208),
		OutdoorAmbient = Color3.fromRGB(210, 222, 232),
		Brightness = 3.5,
		ExposureCompensation = 0.80,
		FogEnd = 900,
		FogColor = Color3.fromRGB(180, 205, 195), -- Subtle green-tinted supercell sky
		ColorCorrection = {
			Brightness = 0.09,
			Contrast = 0.08,
			Saturation = 0.10,
			TintColor = Color3.fromRGB(248, 255, 250),
		},
		Atmosphere = {
			Density = 0.10,
			Offset = 0.20,
			Color = Color3.fromRGB(175, 200, 190),
			Decay = Color3.fromRGB(150, 175, 165),
			Glare = 0.1,
			Haze = 0.2,
		},
	},

	Warning = {
		Ambient = Color3.fromRGB(175, 188, 198),
		OutdoorAmbient = Color3.fromRGB(200, 212, 222),
		Brightness = 3.2,
		ExposureCompensation = 0.75,
		FogEnd = 700,
		FogColor = Color3.fromRGB(160, 185, 175),
		ColorCorrection = {
			Brightness = 0.08,
			Contrast = 0.10,
			Saturation = 0.08,
			TintColor = Color3.fromRGB(242, 252, 245),
		},
		Atmosphere = {
			Density = 0.14,
			Offset = 0.15,
			Color = Color3.fromRGB(155, 180, 170),
			Decay = Color3.fromRGB(135, 160, 150),
			Glare = 0.05,
			Haze = 0.3,
		},
	},

	CoreImpact = {
		Ambient = Color3.fromRGB(165, 178, 188),
		OutdoorAmbient = Color3.fromRGB(190, 202, 212),
		Brightness = 3.0, -- Always bright and visible!
		ExposureCompensation = 0.70,
		FogEnd = 500,    -- 500 studs visibility! Player can see far ahead!
		FogColor = Color3.fromRGB(145, 170, 160),
		ColorCorrection = {
			Brightness = 0.07,
			Contrast = 0.12,
			Saturation = 0.05,
			TintColor = Color3.fromRGB(235, 248, 240),
		},
		Atmosphere = {
			Density = 0.18,
			Offset = 0.10,
			Color = Color3.fromRGB(140, 165, 155),
			Decay = Color3.fromRGB(120, 145, 135),
			Glare = 0,
			Haze = 0.4,
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
