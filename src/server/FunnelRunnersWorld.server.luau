--!strict
-- FunnelRunnersWorld.server.luau
-- Stormy prairie world: terrain, highway, chaser base, farm and storm bunker
-- (tornadoes are built on demand by TornadoBuilder; see TornadoManager)
--
-- Visual overhaul notes:
--   * Fixed: farmhouse roof panels were tilted into a V; the farmhouse also gets side walls and gable ends
--   * Removes the template Baseplate/SpawnLocation (players could spawn inside the ground)
--   * Overcast storm lighting with moving storm clouds
--   * Terrain ground with hills, a pond and a dirt farmyard; trees, fences, hay bales, a silo and power lines
--   * Lighting Technology is now "Future" in default.project.json (it can't be set from a script)

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Terrain = Workspace.Terrain
local BARN_RED = Color3.fromRGB(150, 40, 35)
local WOOD = Color3.fromRGB(95, 70, 48)

-- Creates an anchored part from a property table (ClassName picks Part, WedgePart, etc.)
local function makePart(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Tagged parts get ripped off by the tornado (see RankineVortexEngine)
local function destructible(part: BasePart): BasePart
	CollectionService:AddTag(part, "DestructibleStructure")
	return part
end

local function removeTemplateParts()
	-- The starter Baseplate and SpawnLocation sit inside the prairie ground; players could spawn there
	for _, name in { "Baseplate", "SpawnLocation" } do
		local part = Workspace:FindFirstChild(name)
		if part then
			part:Destroy()
		end
	end
end

local function setupStormLighting()
	-- Overcast late-afternoon storm: moody, but still bright enough to see the tornado
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(70, 75, 85)
	Lighting.OutdoorAmbient = Color3.fromRGB(105, 110, 120)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.5

	for _, child in Lighting:GetChildren() do
		if child:IsA("PostProcessEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end

	-- Hide the bright sun disc behind the storm clouds
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		sky.CelestialBodiesShown = false
		sky.StarCount = 0
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(115, 122, 130)
	atmosphere.Decay = Color3.fromRGB(70, 76, 84)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Contrast = 0.12
	colorCorrection.Saturation = -0.25
	colorCorrection.TintColor = Color3.fromRGB(220, 230, 240)
	colorCorrection.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 1.2 -- only bright things like lightning bloom
	bloom.Parent = Lighting

	-- Thick, moving storm clouds
	local oldClouds = Terrain:FindFirstChildOfClass("Clouds")
	if oldClouds then
		oldClouds:Destroy()
	end
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.85
	clouds.Density = 0.8
	clouds.Color = Color3.fromRGB(85, 90, 100)
	clouds.Parent = Terrain
end

local function buildTerrain()
	Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(92, 112, 64))
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(102, 86, 64))
	Terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(70, 58, 45))

	-- Flat prairie with its surface at y = 1 (same height as the old ground part).
	-- It stops at y = -11, above the underground bunker at y = -31..-13.
	Terrain:FillBlock(CFrame.new(0, -5, 0), Vector3.new(1200, 12, 1200), Enum.Material.Grass)

	-- Ring of rolling hills around the map edge
	local rng = Random.new(7)
	for i = 1, 28 do
		local angle = (i / 28) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local dist = rng:NextNumber(420, 520)
		local radius = rng:NextNumber(60, 110)
		Terrain:FillBall(Vector3.new(math.cos(angle) * dist, -radius * 0.55, math.sin(angle) * dist), radius, Enum.Material.Grass)
	end

	-- Farm pond with a muddy bank
	local pond = Vector3.new(130, 0, -70)
	Terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -3, 0)), 8, 34, Enum.Material.Mud)
	Terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -2, 0)), 8, 28, Enum.Material.Air)
	Terrain:FillCylinder(CFrame.new(pond + Vector3.new(0, -3.5, 0)), 5, 28, Enum.Material.Water)

	-- Dirt yard around the farmhouse
	local yard = Region3.new(Vector3.new(-92, -4, -52), Vector3.new(-36, 4, 12)):ExpandToGrid(4)
	Terrain:ReplaceMaterial(yard, 4, Enum.Material.Grass, Enum.Material.Ground)
end

local function buildHighway(parent: Instance)
	makePart({
		Name = "Highway",
		Size = Vector3.new(40, 1.2, 700),
		Position = Vector3.new(0, 1.1, 0),
		Color = Color3.fromRGB(50, 50, 55),
		Material = Enum.Material.Asphalt,
	}, parent)

	-- Gravel shoulders
	for _, x in { -22, 22 } do
		makePart({
			Name = "Shoulder",
			Size = Vector3.new(4, 1, 700),
			Position = Vector3.new(x, 1, 0),
			Color = Color3.fromRGB(105, 100, 92),
			Material = Enum.Material.Pebble,
		}, parent)
	end

	-- Painted lines (plain paint instead of glowing neon)
	for _, line in {
		{ X = -1.2, Color = Color3.fromRGB(230, 190, 40) },
		{ X = 1.2, Color = Color3.fromRGB(230, 190, 40) },
		{ X = -18.8, Color = Color3.fromRGB(225, 225, 220) },
		{ X = 18.8, Color = Color3.fromRGB(225, 225, 220) },
	} do
		makePart({
			Name = "RoadLine",
			Size = Vector3.new(0.6, 1.3, 690),
			Position = Vector3.new(line.X, 1.15, 0),
			Color = line.Color,
			Material = Enum.Material.SmoothPlastic,
		}, parent)
	end

	-- Telephone poles with sagging power lines
	local previousEnds: { Attachment }? = nil
	for z = -300, 300, 50 do
		makePart({
			Name = "UtilityPole",
			Size = Vector3.new(1.4, 30, 1.4),
			Position = Vector3.new(25, 15, z),
			Color = Color3.fromRGB(90, 65, 40),
			Material = Enum.Material.Wood,
		}, parent)

		local crossArm = makePart({
			Name = "CrossArm",
			Size = Vector3.new(8, 1, 1),
			Position = Vector3.new(25, 28, z),
			Color = Color3.fromRGB(80, 55, 30),
			Material = Enum.Material.Wood,
		}, parent)

		local ends: { Attachment } = {}
		for _, dx in { -3.5, 3.5 } do
			makePart({
				Name = "Insulator",
				Size = Vector3.new(0.5, 0.8, 0.5),
				Position = Vector3.new(25 + dx, 28.9, z),
				Color = Color3.fromRGB(120, 160, 140),
				Material = Enum.Material.Glass,
			}, parent)

			-- Attachment X axis points down so the wire curves downward between poles
			local attachment = Instance.new("Attachment")
			attachment.CFrame = CFrame.fromMatrix(Vector3.new(dx, 0.8, 0), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
			attachment.Parent = crossArm
			table.insert(ends, attachment)
		end

		if previousEnds then
			for i, attachment in ends do
				local wire = Instance.new("Beam")
				wire.Attachment0 = previousEnds[i]
				wire.Attachment1 = attachment
				wire.Width0 = 0.15
				wire.Width1 = 0.15
				wire.CurveSize0 = 5
				wire.CurveSize1 = -5
				wire.Segments = 12
				wire.FaceCamera = true
				wire.Color = ColorSequence.new(Color3.fromRGB(20, 20, 22))
				wire.Transparency = NumberSequence.new(0)
				wire.LightInfluence = 1
				wire.Parent = crossArm
			end
		end
		previousEnds = ends
	end

	-- Road warning sign on two posts
	local signBoard = makePart({
		Name = "WarningSign",
		Size = Vector3.new(0.6, 7, 14),
		Position = Vector3.new(28, 12, 40),
		Color = Color3.fromRGB(25, 125, 50),
		Material = Enum.Material.SmoothPlastic,
	}, parent)
	for _, dz in { -5, 5 } do
		makePart({
			Name = "SignPost",
			Size = Vector3.new(0.8, 12, 0.8),
			Position = Vector3.new(28.7, 7, 40 + dz),
			Color = Color3.fromRGB(140, 140, 145),
			Material = Enum.Material.Metal,
		}, parent)
	end

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

local function buildChaserSpawnBase(parent: Instance)
	local base = Instance.new("Model")
	base.Name = "ChaserSpawnBase"

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "ChaserSpawn"
	spawn.Size = Vector3.new(18, 1.2, 18)
	spawn.Position = Vector3.new(0, 1.8, 120)
	spawn.Anchored = true
	spawn.Color = Color3.fromRGB(45, 65, 85)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Duration = 0
	spawn.Parent = base

	-- Research HQ trailer
	local trailer = makePart({
		Name = "ResearchHQ",
		Size = Vector3.new(28, 12, 18),
		Position = Vector3.new(-26, 7, 120),
		Color = Color3.fromRGB(190, 195, 200),
		Material = Enum.Material.Metal,
	}, base)
	local p = trailer.Position

	makePart({ Name = "Skirt", Size = Vector3.new(28.4, 2.2, 18.4), Position = p + Vector3.new(0, -4.9, 0), Color = Color3.fromRGB(45, 48, 52), Material = Enum.Material.Metal }, base)
	makePart({ Name = "Stripe", Size = Vector3.new(28.3, 1.4, 18.3), Position = p + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(230, 120, 30), Material = Enum.Material.SmoothPlastic }, base)
	for _, dx in { -8, 0, 8 } do
		for _, side in { -1, 1 } do
			makePart({
				Name = "Window",
				Size = Vector3.new(5, 2.6, 0.3),
				Position = p + Vector3.new(dx, 3.2, side * 9.1),
				Color = Color3.fromRGB(60, 80, 100),
				Material = Enum.Material.Glass,
				Reflectance = 0.25,
			}, base)
		end
	end
	makePart({ Name = "Door", Size = Vector3.new(0.3, 7.5, 4), Position = p + Vector3.new(14.1, -1.85, -3), Color = Color3.fromRGB(70, 75, 80), Material = Enum.Material.Metal }, base)
	makePart({ Name = "Steps", Size = Vector3.new(3, 1, 4.5), Position = p + Vector3.new(15.6, -5.5, -3), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.DiamondPlate }, base)
	makePart({ Name = "ACUnit", Size = Vector3.new(5, 2, 4), Position = p + Vector3.new(6, 7, 0), Color = Color3.fromRGB(205, 205, 210), Material = Enum.Material.Metal }, base)

	-- Spinning Doppler radar dish
	local dishMast = makePart({
		Name = "DishMast",
		Size = Vector3.new(2, 10, 2),
		Position = p + Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(100, 100, 105),
		Material = Enum.Material.Metal,
	}, base)

	local dish = makePart({
		Name = "DopplerDish",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.5, 12, 12),
		CFrame = CFrame.new(dishMast.Position + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(245, 245, 250),
		Material = Enum.Material.SmoothPlastic,
	}, base)

	task.spawn(function()
		while dish.Parent do
			dish.CFrame = dish.CFrame * CFrame.Angles(0, math.rad(2.5), 0)
			task.wait(0.03)
		end
	end)

	base.Parent = parent
end

local function buildFenceLine(from: Vector3, to: Vector3, parent: Instance)
	local delta = to - from
	local count = math.max(1, math.round(delta.Magnitude / 8))
	local step = delta / count
	for i = 0, count do
		local base = from + step * i
		destructible(makePart({
			Name = "FencePost",
			Size = Vector3.new(0.8, 5, 0.8),
			Position = base + Vector3.new(0, 2.5, 0),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, parent))
		if i < count then
			for _, height in { 2.2, 4.2 } do
				local mid = base + step / 2 + Vector3.new(0, height, 0)
				destructible(makePart({
					Name = "FenceRail",
					Size = Vector3.new(0.4, 0.5, step.Magnitude),
					CFrame = CFrame.lookAt(mid, mid + step),
					Color = WOOD,
					Material = Enum.Material.Wood,
				}, parent))
			end
		end
	end
end

local function buildFarm(parent: Instance)
	local house = Instance.new("Model")
	house.Name = "DestructibleFarmhouse"

	local houseCenter = Vector3.new(-65, 1, -20)

	makePart({
		Name = "Foundation",
		Size = Vector3.new(42, 2, 52),
		Position = houseCenter + Vector3.new(0, 1, 0),
		Color = Color3.fromRGB(115, 115, 120),
		Material = Enum.Material.Concrete,
	}, house)

	-- Front/back walls (planks run along X) and side walls (planks run along Z)
	for y = 4, 18, 3.5 do
		for x = -18, 18, 9 do
			for _, z in { -25, 25 } do
				destructible(makePart({
					Name = "WallPlank",
					Size = Vector3.new(8.5, 3.2, 1.2),
					Position = houseCenter + Vector3.new(x, y, z),
					Color = BARN_RED,
					Material = Enum.Material.WoodPlanks,
				}, house))
			end
		end
		for i = -2, 2 do
			for _, x in { -21.4, 21.4 } do
				destructible(makePart({
					Name = "WallPlank",
					Size = Vector3.new(1.2, 3.2, 9.5),
					Position = houseCenter + Vector3.new(x, y, i * 9.6),
					Color = BARN_RED,
					Material = Enum.Material.WoodPlanks,
				}, house))
			end
		end
	end

	-- Gable ends: two wedges per end, rising toward the ridge at x = 0
	for _, z in { -25, 25 } do
		for _, side in { -1, 1 } do
			local center = houseCenter + Vector3.new(side * 10.7, 19.6 + 5, z)
			destructible(makePart({
				ClassName = "WedgePart",
				Name = "Gable",
				Size = Vector3.new(1.2, 10, 21.4),
				CFrame = CFrame.fromMatrix(center, Vector3.new(0, 0, side), Vector3.yAxis),
				Color = BARN_RED,
				Material = Enum.Material.WoodPlanks,
			}, house))
		end
	end

	-- Tin roof sloping down from the ridge on both sides
	for z = -20, 20, 10 do
		for _, side in { -1, 1 } do
			destructible(makePart({
				Name = "RoofPanel",
				Size = Vector3.new(24, 1.2, 10.5),
				CFrame = CFrame.new(houseCenter + Vector3.new(side * 11, 25.5, z)) * CFrame.Angles(0, 0, math.rad(-side * 25)),
				Color = Color3.fromRGB(150, 155, 160),
				Material = Enum.Material.CorrodedMetal,
			}, house))
		end
	end
	makePart({
		Name = "RidgeCap",
		Size = Vector3.new(2, 1, 54),
		Position = houseCenter + Vector3.new(0, 30.8, 0),
		Color = Color3.fromRGB(120, 125, 130),
		Material = Enum.Material.CorrodedMetal,
	}, house)

	-- Door and windows
	destructible(makePart({ Name = "Door", Size = Vector3.new(6, 9, 0.4), Position = houseCenter + Vector3.new(0, 6.5, -25.8), Color = Color3.fromRGB(70, 50, 35), Material = Enum.Material.Wood }, house))
	for _, z in { -25.8, 25.8 } do
		for _, x in { -12, 12 } do
			destructible(makePart({ Name = "WindowTrim", Size = Vector3.new(5.6, 4.6, 0.3), Position = houseCenter + Vector3.new(x, 11, z), Color = Color3.fromRGB(235, 230, 220), Material = Enum.Material.Wood }, house))
			destructible(makePart({ Name = "Window", Size = Vector3.new(4.8, 3.8, 0.3), Position = houseCenter + Vector3.new(x, 11, z + math.sign(z) * 0.1), Color = Color3.fromRGB(45, 55, 65), Material = Enum.Material.Glass, Reflectance = 0.2 }, house))
		end
	end

	house.Parent = parent

	-- Farmyard: fence with a gate gap facing the highway, silo, hay bales
	local yard = Instance.new("Model")
	yard.Name = "Farmyard"
	buildFenceLine(Vector3.new(-112, 1, -70), Vector3.new(-32, 1, -70), yard)
	buildFenceLine(Vector3.new(-112, 1, 30), Vector3.new(-32, 1, 30), yard)
	buildFenceLine(Vector3.new(-112, 1, -70), Vector3.new(-112, 1, 30), yard)
	buildFenceLine(Vector3.new(-32, 1, -70), Vector3.new(-32, 1, -30), yard)
	buildFenceLine(Vector3.new(-32, 1, -10), Vector3.new(-32, 1, 30), yard)

	makePart({
		Name = "Silo",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(36, 14, 14),
		CFrame = CFrame.new(-100, 19, 15) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(165, 170, 175),
		Material = Enum.Material.CorrodedMetal,
	}, yard)
	makePart({
		Name = "SiloDome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		Position = Vector3.new(-100, 37, 15),
		Color = Color3.fromRGB(120, 125, 130),
		Material = Enum.Material.Metal,
	}, yard)

	local rng = Random.new(11)
	for _, spot in { Vector2.new(-50, 18), Vector2.new(-55, 22), Vector2.new(-48, 24), Vector2.new(-95, -55), Vector2.new(-90, -60), Vector2.new(-100, -50) } do
		destructible(makePart({
			Name = "HayBale",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 4.5, 4.5),
			CFrame = CFrame.new(spot.X, 3.25, spot.Y) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Color = Color3.fromRGB(196, 168, 96),
			Material = Enum.Material.Fabric,
		}, yard))
	end

	yard.Parent = parent
end

local function buildTree(position: Vector3, height: number, rng: Random, parent: Instance)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	makePart({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height * 0.6, 2.2, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, height * 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(85, 62, 45),
		Material = Enum.Material.Wood,
	}, tree)
	for _ = 1, 4 do
		local size = height * rng:NextNumber(0.35, 0.5)
		local offset = Vector3.new(rng:NextNumber(-0.15, 0.15) * height, height * rng:NextNumber(0.6, 0.85), rng:NextNumber(-0.15, 0.15) * height)
		makePart({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = position + offset,
			Color = Color3.fromRGB(rng:NextInteger(55, 75), rng:NextInteger(80, 100), rng:NextInteger(42, 55)),
			Material = Enum.Material.Grass,
		}, tree)
	end
	tree.Parent = parent
end

local function buildScenery(parent: Instance)
	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	local rng = Random.new(3)
	local placed = 0
	while placed < 40 do
		local x, z = rng:NextNumber(-380, 380), rng:NextNumber(-380, 380)
		local nearRoad = math.abs(x) < 50
		local inFarmyard = x > -125 and x < -20 and z > -85 and z < 45
		local nearPond = (Vector2.new(x, z) - Vector2.new(130, -70)).Magnitude < 45
		if not (nearRoad or inFarmyard or nearPond) then
			buildTree(Vector3.new(x, 1, z), rng:NextNumber(18, 30), rng, trees)
			placed += 1
		end
	end
	trees.Parent = parent
end

local function buildUndergroundStormBunker(parent: Instance)
	local bunker = Instance.new("Model")
	bunker.Name = "UndergroundBunker"

	local bunkerPos = Vector3.new(0, 1, 30)
	local interiorPos = Vector3.new(0, -30, 30)

	makePart({
		Name = "BunkerSurfaceCollar",
		Size = Vector3.new(24, 3.5, 24),
		Position = bunkerPos + Vector3.new(0, 1.75, 0),
		Color = Color3.fromRGB(90, 85, 80),
		Material = Enum.Material.Concrete,
	}, bunker)

	local hatch = makePart({
		Name = "BlastHatch",
		Size = Vector3.new(14, 1.2, 14),
		CFrame = CFrame.new(bunkerPos + Vector3.new(0, 3.8, 0)) * CFrame.Angles(math.rad(18), 0, 0),
		Color = Color3.fromRGB(245, 190, 20),
		Material = Enum.Material.DiamondPlate,
		CanCollide = false,
	}, bunker)

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
	local entrancePad = makePart({
		Name = "EntrancePad",
		Size = Vector3.new(12, 1, 12),
		Position = bunkerPos + Vector3.new(0, 1.8, 0),
		Transparency = 0.5,
		Color = Color3.fromRGB(50, 220, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, bunker)

	-- Interior room
	makePart({ Name = "ShelterFloor", Size = Vector3.new(48, 2, 48), Position = interiorPos, Color = Color3.fromRGB(65, 65, 70), Material = Enum.Material.Concrete }, bunker)
	local ceiling = makePart({ Name = "ShelterCeiling", Size = Vector3.new(48, 2, 48), Position = interiorPos + Vector3.new(0, 16, 0), Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Concrete }, bunker)
	for _, wall in {
		{ Offset = Vector3.new(0, 8, -24.5), Size = Vector3.new(48, 18, 1) },
		{ Offset = Vector3.new(0, 8, 24.5), Size = Vector3.new(48, 18, 1) },
		{ Offset = Vector3.new(-24.5, 8, 0), Size = Vector3.new(1, 18, 48) },
		{ Offset = Vector3.new(24.5, 8, 0), Size = Vector3.new(1, 18, 48) },
	} do
		makePart({ Name = "ShelterWall", Size = wall.Size, Position = interiorPos + wall.Offset, Color = Color3.fromRGB(75, 75, 80), Material = Enum.Material.Concrete }, bunker)
	end

	local redLight = Instance.new("PointLight")
	redLight.Color = Color3.fromRGB(255, 80, 60)
	redLight.Brightness = 3.5
	redLight.Range = 45
	redLight.Parent = ceiling

	for _, x in { -12, 12 } do
		local lamp = makePart({ Name = "CeilingLamp", Size = Vector3.new(4, 0.6, 1.5), Position = interiorPos + Vector3.new(x, 14.7, 0), Color = Color3.fromRGB(255, 240, 215), Material = Enum.Material.Neon }, bunker)
		local lampLight = Instance.new("PointLight")
		lampLight.Color = Color3.fromRGB(255, 235, 200)
		lampLight.Brightness = 1.5
		lampLight.Range = 30
		lampLight.Parent = lamp
	end
	for _, x in { -21, 21 } do
		makePart({ Name = "Bench", Size = Vector3.new(3, 1, 30), Position = interiorPos + Vector3.new(x, 2.5, 0), Color = WOOD, Material = Enum.Material.Wood }, bunker)
	end

	local exitLadder = makePart({
		Name = "ExitLadder",
		Size = Vector3.new(5, 14, 1.2),
		Position = interiorPos + Vector3.new(0, 7, 22),
		Color = Color3.fromRGB(240, 200, 30),
		Material = Enum.Material.DiamondPlate,
	}, bunker)

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

	-- Safe volume tag for ZonePlus & physics engine
	local safeVolume = makePart({
		Name = "BunkerSafeVolume",
		Size = Vector3.new(46, 15, 46),
		Position = interiorPos + Vector3.new(0, 8, 0),
		Transparency = 1,
		CanCollide = false,
	}, bunker)
	CollectionService:AddTag(safeVolume, "StormBunker")

	bunker.Parent = parent
end

local function initializeWorld()
	removeTemplateParts()
	setupStormLighting()
	buildTerrain()

	local worldFolder = Workspace:FindFirstChild("FunnelRunnersWorld") or Instance.new("Folder")
	worldFolder.Name = "FunnelRunnersWorld"
	worldFolder.Parent = Workspace
	worldFolder:ClearAllChildren()

	buildHighway(worldFolder)
	buildChaserSpawnBase(worldFolder)
	buildFarm(worldFolder)
	buildScenery(worldFolder)
	buildUndergroundStormBunker(worldFolder)

	print("[FunnelRunnersWorld] Storm world with EF5 wedge tornado loaded.")
end

initializeWorld()
