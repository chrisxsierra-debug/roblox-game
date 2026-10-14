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
		Ambient = Color3.fromRGB(85, 95, 105),
		OutdoorAmbient = Color3.fromRGB(120, 130, 140),
		Brightness = 1.8,
		FogEnd = 500,
		FogColor = Color3.fromRGB(160, 175, 185),
		ColorCorrection = {
			Brightness = 0.0,
			Contrast = 0.08,
			Saturation = 0.05,
			TintColor = Color3.fromRGB(250, 252, 255),
		},
		Atmosphere = {
			Density = 0.18,
			Offset = 0,
			Color = Color3.fromRGB(170, 180, 195),
			Decay = Color3.fromRGB(130, 140, 155),
			Glare = 0.1,
			Haze = 1.2,
		},
	},

	Approaching = {
		Ambient = Color3.fromRGB(75, 88, 82),
		OutdoorAmbient = Color3.fromRGB(110, 125, 115),
		Brightness = 1.6,
		FogEnd = 320,
		FogColor = Color3.fromRGB(115, 135, 120), -- Eerie green hail core tint
		ColorCorrection = {
			Brightness = -0.02,
			Contrast = 0.20,
			Saturation = -0.15,
			TintColor = Color3.fromRGB(225, 245, 225),
		},
		Atmosphere = {
			Density = 0.32,
			Offset = 0,
			Color = Color3.fromRGB(120, 140, 125),
			Decay = Color3.fromRGB(90, 110, 95),
			Glare = 0,
			Haze = 2.5,
		},
	},

	Warning = {
		Ambient = Color3.fromRGB(65, 78, 72),
		OutdoorAmbient = Color3.fromRGB(95, 112, 102),
		Brightness = 1.4,
		FogEnd = 220,
		FogColor = Color3.fromRGB(85, 105, 92),
		ColorCorrection = {
			Brightness = -0.04,
			Contrast = 0.28,
			Saturation = -0.25,
			TintColor = Color3.fromRGB(210, 235, 210),
		},
		Atmosphere = {
			Density = 0.45,
			Offset = 0,
			Color = Color3.fromRGB(90, 110, 98),
			Decay = Color3.fromRGB(70, 90, 78),
			Glare = 0,
			Haze = 4.0,
		},
	},

	CoreImpact = {
		Ambient = Color3.fromRGB(55, 68, 62),
		OutdoorAmbient = Color3.fromRGB(82, 98, 88),
		Brightness = 1.2, -- Stays clearly visible!
		FogEnd = 140,    -- Can easily see the wedge funnel!
		FogColor = Color3.fromRGB(65, 80, 72),
		ColorCorrection = {
			Brightness = -0.06,
			Contrast = 0.38,
			Saturation = -0.35,
			TintColor = Color3.fromRGB(195, 225, 200),
		},
		Atmosphere = {
			Density = 0.58,
			Offset = 0,
			Color = Color3.fromRGB(70, 85, 76),
			Decay = Color3.fromRGB(50, 65, 56),
			Glare = 0,
			Haze = 6.0,
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
