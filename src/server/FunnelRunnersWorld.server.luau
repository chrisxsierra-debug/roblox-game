--!strict
-- FunnelRunnersWorld.server.luau
-- High-visibility stormy daylight, massive EF5 Wedge Tornado model, destructible barn, and storm bunker

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local function setupBrightStormAtmosphere()
	-- Clear daylight stormy look (bright enough to see everything clearly!)
	Lighting.Brightness = 2.2
	Lighting.ClockTime = 14.0 -- Mid-afternoon storm
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 130, 140)
	Lighting.Ambient = Color3.fromRGB(90, 95, 105)
	Lighting.GlobalShadows = true
	Lighting.FogColor = Color3.fromRGB(130, 140, 150)
	Lighting.FogStart = 200
	Lighting.FogEnd = 1200

	-- Clear out dark tints
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28 -- Light mist, not blinding pitch black
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(140, 155, 160)
	atmosphere.Decay = Color3.fromRGB(100, 110, 115)
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Brightness = 0.02
	colorCorrection.Contrast = 0.15
	colorCorrection.Saturation = -0.1
	colorCorrection.TintColor = Color3.fromRGB(240, 245, 250)
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.3
	bloom.Size = 18
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
end

local function buildHighwayAndPrairie(parent: Folder)
	-- Prairie Field Base
	local grass = Instance.new("Part")
	grass.Name = "PrairieGround"
	grass.Size = Vector3.new(800, 2, 800)
	grass.Position = Vector3.new(0, 0, 0)
	grass.Anchored = true
	grass.Color = Color3.fromRGB(85, 115, 65)
	grass.Material = Enum.Material.Grass
	grass.Parent = parent

	-- Asphalt Highway
	local road = Instance.new("Part")
	road.Name = "Highway"
	road.Size = Vector3.new(40, 1.2, 700)
	road.Position = Vector3.new(0, 1.1, 0)
	road.Anchored = true
	road.Color = Color3.fromRGB(50, 50, 55)
	road.Material = Enum.Material.Asphalt
	road.Parent = parent

	-- Yellow Double Centerlines
	for offset = -1.2, 1.2, 2.4 do
		local line = Instance.new("Part")
		line.Name = "CenterLine"
		line.Size = Vector3.new(0.6, 1.3, 690)
		line.Position = Vector3.new(offset, 1.15, 0)
		line.Anchored = true
		line.Color = Color3.fromRGB(255, 210, 40)
		line.Material = Enum.Material.Neon
		line.Parent = parent
	end

	-- Telephone Poles along road
	for z = -300, 300, 50 do
		local pole = Instance.new("Part")
		pole.Name = "UtilityPole"
		pole.Size = Vector3.new(1.4, 30, 1.4)
		pole.Position = Vector3.new(25, 15, z)
		pole.Anchored = true
		pole.Color = Color3.fromRGB(90, 65, 40)
		pole.Material = Enum.Material.Wood
		pole.Parent = parent

		local crossArm = Instance.new("Part")
		crossArm.Size = Vector3.new(8, 1, 1)
		crossArm.Position = Vector3.new(25, 28, z)
		crossArm.Anchored = true
		crossArm.Color = Color3.fromRGB(80, 55, 30)
		crossArm.Material = Enum.Material.Wood
		crossArm.Parent = parent
	end

	-- Road Warning Signboard
	local signBoard = Instance.new("Part")
	signBoard.Size = Vector3.new(0.6, 7, 14)
	signBoard.Position = Vector3.new(28, 12, 40)
	signBoard.Anchored = true
	signBoard.Color = Color3.fromRGB(25, 125, 50)
	signBoard.Material = Enum.Material.SmoothPlastic
	signBoard.Parent = parent

	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Back
	signGui.Adornee = signBoard
	signGui.Parent = signBoard

	local signText = Instance.new("TextLabel")
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.Text = "⚠️ DANGER: TORNADO ALLEY\nEF5 MONSTER TOUCHDOWN AHEAD\nSHELTER 40 STUDS NORTH ➔"
	signText.TextColor3 = Color3.fromRGB(255, 255, 255)
	signText.Font = Enum.Font.GothamBlack
	signText.TextScaled = true
	signText.Parent = signGui
end

local function buildChaserSpawnBase(parent: Folder)
	local base = Instance.new("Model")
	base.Name = "ChaserSpawnBase"

	-- Spawn Location
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ChaserSpawn"
	spawn.Size = Vector3.new(18, 1.2, 18)
	spawn.Position = Vector3.new(0, 1.8, 120)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(45, 65, 85)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Duration = 0
	spawn.Parent = base

	-- Chaser Base HQ Trailer
	local trailer = Instance.new("Part")
	trailer.Name = "ResearchHQ"
	trailer.Size = Vector3.new(28, 12, 18)
	trailer.Position = Vector3.new(-26, 7, 120)
	trailer.Anchored = true
	trailer.Color = Color3.fromRGB(190, 195, 200)
	trailer.Material = Enum.Material.Metal
	trailer.Parent = base

	-- Spinning Doppler Radar Dish on Base
	local dishMast = Instance.new("Part")
	dishMast.Size = Vector3.new(2, 10, 2)
	dishMast.Position = trailer.Position + Vector3.new(0, 10, 0)
	dishMast.Anchored = true
	dishMast.Color = Color3.fromRGB(100, 100, 105)
	dishMast.Parent = base

	local dish = Instance.new("Part")
	dish.Name = "DopplerDish"
	dish.Shape = Enum.PartType.Cylinder
	dish.Size = Vector3.new(2.5, 12, 12)
	dish.CFrame = CFrame.new(dishMast.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	dish.Anchored = true
	dish.Color = Color3.fromRGB(245, 245, 250)
	dish.Material = Enum.Material.SmoothPlastic
	dish.Parent = base

	task.spawn(function()
		while dish.Parent do
			dish.CFrame = dish.CFrame * CFrame.Angles(0, math.rad(2.5), 0)
			task.wait(0.03)
		end
	end)

	base.Parent = parent
end

local function buildDestructibleFarmhouse(parent: Folder)
	local house = Instance.new("Model")
	house.Name = "DestructibleFarmhouse"

	local houseCenter = Vector3.new(-65, 1, -20)

	-- Foundation
	local foundation = Instance.new("Part")
	foundation.Size = Vector3.new(42, 2, 52)
	foundation.Position = houseCenter + Vector3.new(0, 1, 0)
	foundation.Anchored = true
	foundation.Color = Color3.fromRGB(115, 115, 120)
	foundation.Material = Enum.Material.Concrete
	foundation.Parent = house

	-- Breakable Wall Planks & Siding (Tagged DestructibleStructure for Tornado to rip off!)
	for y = 4, 18, 3.5 do
		for x = -18, 18, 9 do
			local plankF = Instance.new("Part")
			plankF.Name = "WallPlank_Front"
			plankF.Size = Vector3.new(8.5, 3.2, 1.2)
			plankF.Position = houseCenter + Vector3.new(x, y, -25)
			plankF.Anchored = true
			plankF.Color = Color3.fromRGB(175, 45, 45) -- Barn red
			plankF.Material = Enum.Material.WoodPlanks
			CollectionService:AddTag(plankF, "DestructibleStructure")
			plankF.Parent = house

			local plankB = Instance.new("Part")
			plankB.Name = "WallPlank_Back"
			plankB.Size = Vector3.new(8.5, 3.2, 1.2)
			plankB.Position = houseCenter + Vector3.new(x, y, 25)
			plankB.Anchored = true
			plankB.Color = Color3.fromRGB(175, 45, 45)
			plankB.Material = Enum.Material.WoodPlanks
			CollectionService:AddTag(plankB, "DestructibleStructure")
			plankB.Parent = house
		end
	end

	-- Breakable Tin Roof Panels
	for z = -20, 20, 10 do
		local roofL = Instance.new("Part")
		roofL.Name = "RoofPanel_Left"
		roofL.Size = Vector3.new(24, 1.2, 9.5)
		roofL.CFrame = CFrame.new(houseCenter + Vector3.new(-11, 23, z)) * CFrame.Angles(0, 0, math.rad(-25))
		roofL.Anchored = true
		roofL.Color = Color3.fromRGB(150, 155, 160)
		roofL.Material = Enum.Material.CorrodedMetal
		CollectionService:AddTag(roofL, "DestructibleStructure")
		roofL.Parent = house

		local roofR = Instance.new("Part")
		roofR.Name = "RoofPanel_Right"
		roofR.Size = Vector3.new(24, 1.2, 9.5)
		roofR.CFrame = CFrame.new(houseCenter + Vector3.new(11, 23, z)) * CFrame.Angles(0, 0, math.rad(25))
		roofR.Anchored = true
		roofR.Color = Color3.fromRGB(150, 155, 160)
		roofR.Material = Enum.Material.CorrodedMetal
		CollectionService:AddTag(roofR, "DestructibleStructure")
		roofR.Parent = house
	end

	house.Parent = parent
end

local function buildUndergroundStormBunker(parent: Folder)
	local bunker = Instance.new("Model")
	bunker.Name = "UndergroundBunker"

	local bunkerPos = Vector3.new(0, 1, 30) -- Right next to the highway in plain sight!
	local interiorPos = Vector3.new(0, -30, 30)

	-- Surface Collar
	local collar = Instance.new("Part")
	collar.Name = "BunkerSurfaceCollar"
	collar.Size = Vector3.new(24, 3.5, 24)
	collar.Position = bunkerPos + Vector3.new(0, 1.75, 0)
	collar.Anchored = true
	collar.Color = Color3.fromRGB(90, 85, 80)
	collar.Material = Enum.Material.Concrete
	collar.Parent = bunker

	-- Yellow Hazard Blast Hatch
	local hatch = Instance.new("Part")
	hatch.Name = "BlastHatch"
	hatch.Size = Vector3.new(14, 1.2, 14)
	hatch.CFrame = CFrame.new(bunkerPos + Vector3.new(0, 3.8, 0)) * CFrame.Angles(math.rad(18), 0, 0)
	hatch.Anchored = true
	hatch.Color = Color3.fromRGB(245, 190, 20)
	hatch.Material = Enum.Material.DiamondPlate
	hatch.CanCollide = false
	hatch.Parent = bunker

	local hatchBillboard = Instance.new("BillboardGui")
	hatchBillboard.Size = UDim2.new(12, 0, 3, 0)
	hatchBillboard.StudsOffset = Vector3.new(0, 6, 0)
	hatchBillboard.AlwaysOnTop = true
	hatchBillboard.Adornee = hatch
	hatchBillboard.Parent = hatch

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "🛡️ UNDERGROUND STORM BUNKER\n[JUMP IN TO SURVIVE EF5 WEDGE TORNADO]"
	label.TextColor3 = Color3.fromRGB(255, 225, 40)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Parent = hatchBillboard

	-- Teleport into shelter
	local entrancePad = Instance.new("Part")
	entrancePad.Name = "EntrancePad"
	entrancePad.Size = Vector3.new(12, 1, 12)
	entrancePad.Position = bunkerPos + Vector3.new(0, 1.8, 0)
	entrancePad.Anchored = true
	entrancePad.Transparency = 0.5
	entrancePad.Color = Color3.fromRGB(50, 220, 255)
	entrancePad.Material = Enum.Material.Neon
	entrancePad.CanCollide = false
	entrancePad.Parent = bunker

	-- Interior Room
	local floor = Instance.new("Part")
	floor.Name = "ShelterFloor"
	floor.Size = Vector3.new(48, 2, 48)
	floor.Position = interiorPos
	floor.Anchored = true
	floor.Color = Color3.fromRGB(65, 65, 70)
	floor.Material = Enum.Material.Concrete
	floor.Parent = bunker

	local ceiling = Instance.new("Part")
	ceiling.Size = Vector3.new(48, 2, 48)
	ceiling.Position = interiorPos + Vector3.new(0, 16, 0)
	ceiling.Anchored = true
	ceiling.Color = Color3.fromRGB(55, 55, 60)
	ceiling.Material = Enum.Material.Concrete
	ceiling.Parent = bunker

	local redLight = Instance.new("PointLight")
	redLight.Color = Color3.fromRGB(255, 80, 60)
	redLight.Brightness = 3.5
	redLight.Range = 45
	redLight.Parent = ceiling

	-- Exit Ladder
	local exitLadder = Instance.new("Part")
	exitLadder.Name = "ExitLadder"
	exitLadder.Size = Vector3.new(5, 14, 1.2)
	exitLadder.Position = interiorPos + Vector3.new(0, 7, 22)
	exitLadder.Anchored = true
	exitLadder.Color = Color3.fromRGB(240, 200, 30)
	exitLadder.Material = Enum.Material.DiamondPlate
	exitLadder.Parent = bunker

	local exitPrompt = Instance.new("ProximityPrompt")
	exitPrompt.ObjectText = "Surface Hatch"
	exitPrompt.ActionText = "Climb to Surface"
	exitPrompt.HoldDuration = 0.3
	exitPrompt.MaxActivationDistance = 14
	exitPrompt.Parent = exitLadder

	exitPrompt.Triggered:Connect(function(player)
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if root then
				root.CFrame = CFrame.new(0, 5, 45)
			end
		end
	end)

	entrancePad.Touched:Connect(function(hit)
		local char = hit.Parent
		if char and char:IsA("Model") then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if root and root.Position.Y > 0 then
				root.CFrame = CFrame.new(0, -26, 30)
			end
		end
	end)

	-- Safe Volume Tag for ZonePlus & Physics Engine
	local safeVolume = Instance.new("Part")
	safeVolume.Name = "BunkerSafeVolume"
	safeVolume.Size = Vector3.new(46, 15, 46)
	safeVolume.Position = interiorPos + Vector3.new(0, 8, 0)
	safeVolume.Anchored = true
	safeVolume.Transparency = 1
	safeVolume.CanCollide = false
	CollectionService:AddTag(safeVolume, "StormBunker")
	safeVolume.Parent = bunker

	bunker.Parent = parent
end

-- --- GIGANTIC MASSIVE EF5 WEDGE TORNADO MODEL ---
local function buildGiganticWedgeTornado(parent: Folder): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "FunnelRunnersVortex"

	-- Root placed on the highway in plain view!
	local root = Instance.new("Part")
	root.Name = "VortexRoot"
	root.Size = Vector3.new(14, 4, 14)
	root.Position = Vector3.new(0, 2, -60) -- RIGHT DOWN THE HIGHWAY, PLAINLY VISIBLE!
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	-- Ground Condensation & Violent Dust Storm Emitter
	local dustEmitter = Instance.new("ParticleEmitter")
	dustEmitter.Name = "WedgeDustCloud"
	dustEmitter.Rate = 350
	dustEmitter.Lifetime = NumberRange.new(2.5, 5)
	dustEmitter.Speed = NumberRange.new(45, 95)
	dustEmitter.SpreadAngle = Vector2.new(180, 75)
	dustEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 18),
		NumberSequenceKeypoint.new(0.3, 45),
		NumberSequenceKeypoint.new(0.7, 75),
		NumberSequenceKeypoint.new(1, 110),
	})
	dustEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	dustEmitter.Color = ColorSequence.new(Color3.fromRGB(75, 75, 78))
	dustEmitter.Parent = root

	-- Multi-tier Massive Expanding Funnel Mesh Layers (True EF5 Wedge!)
	-- Expanding from 35 studs at base to 200 studs at top, 240 studs high!
	local wedgeLayers = {
		{ Height = 8,   Radius = 38,  Transparency = 0.25 },
		{ Height = 25,  Radius = 55,  Transparency = 0.30 },
		{ Height = 50,  Radius = 78,  Transparency = 0.35 },
		{ Height = 85,  Radius = 110, Transparency = 0.40 },
		{ Height = 130, Radius = 150, Transparency = 0.45 },
		{ Height = 180, Radius = 195, Transparency = 0.50 },
	}

	for i, layer in wedgeLayers do
		local funnelPart = Instance.new("Part")
		funnelPart.Name = "WedgeLayer_" .. i
		funnelPart.Shape = Enum.PartType.Cylinder
		funnelPart.Size = Vector3.new(16, layer.Radius, layer.Radius)
		funnelPart.CFrame = CFrame.new(root.Position + Vector3.new(0, layer.Height, 0)) * CFrame.Angles(0, 0, math.rad(90))
		funnelPart.Anchored = true
		funnelPart.CanCollide = false
		funnelPart.Transparency = layer.Transparency
		funnelPart.Color = Color3.fromRGB(45, 48, 55)
		funnelPart.Material = Enum.Material.Smoke
		funnelPart.Parent = model

		-- Add swirling cloud particles to each layer
		local cloudEmitter = Instance.new("ParticleEmitter")
		cloudEmitter.Rate = 45
		cloudEmitter.Lifetime = NumberRange.new(2, 4)
		cloudEmitter.Speed = NumberRange.new(20, 50)
		cloudEmitter.Size = NumberSequence.new(25, 45)
		cloudEmitter.Transparency = NumberSequence.new(0.4, 1)
		cloudEmitter.Color = ColorSequence.new(Color3.fromRGB(50, 52, 60))
		cloudEmitter.Parent = funnelPart
	end

	-- Howling Roar Audio
	local roar = Instance.new("Sound")
	roar.Name = "TornadoRoarAudio"
	roar.SoundId = "rbxassetid://9114223171"
	roar.Volume = 3.5
	roar.Looped = true
	roar.RollOffMaxDistance = 500
	roar.RollOffMinDistance = 50
	roar.Parent = root
	roar:Play()

	model.Parent = parent
	return model, root
end

local function initializeWorld()
	setupBrightStormAtmosphere()

	local worldFolder = Workspace:FindFirstChild("FunnelRunnersWorld") or Instance.new("Folder")
	worldFolder.Name = "FunnelRunnersWorld"
	worldFolder.Parent = Workspace
	worldFolder:ClearAllChildren()

	buildHighwayAndPrairie(worldFolder)
	buildChaserSpawnBase(worldFolder)
	buildDestructibleFarmhouse(worldFolder)
	buildUndergroundStormBunker(worldFolder)
	buildGiganticWedgeTornado(worldFolder)

	print("[FunnelRunnersWorld] Clear-view storm world with GIGANTIC EF5 WEDGE TORNADO loaded.")
end

initializeWorld()
