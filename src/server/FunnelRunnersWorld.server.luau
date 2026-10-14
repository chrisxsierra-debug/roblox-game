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
	-- Silent Hill atmospheric daylight fog: luminous, pearlescent silver-white mist
	Lighting.ClockTime = 14.0
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(180, 185, 195)
	Lighting.OutdoorAmbient = Color3.fromRGB(205, 212, 222)
	Lighting.ExposureCompensation = 0.65
	Lighting.EnvironmentDiffuseScale = 1.0
	Lighting.EnvironmentSpecularScale = 0.85
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.8
	Lighting.FogColor = Color3.fromRGB(212, 218, 225)
	Lighting.FogStart = 20
	Lighting.FogEnd = 200

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if not sky then
		sky = Instance.new("Sky")
		sky.Parent = Lighting
	end
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 21

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "StormAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.44
	atmosphere.Offset = 0.18
	atmosphere.Color = Color3.fromRGB(215, 222, 230)
	atmosphere.Decay = Color3.fromRGB(180, 190, 200)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 0.35

	local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "StormColorCorrection"
		colorCorrection.Parent = Lighting
	end
	colorCorrection.Brightness = 0.05
	colorCorrection.Contrast = 0.14
	colorCorrection.Saturation = -0.15
	colorCorrection.TintColor = Color3.fromRGB(240, 246, 252)

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.2
	bloom.Size = 20
	bloom.Threshold = 1.0

	-- Translucent silver-white cloud ceiling
	local oldClouds = Terrain:FindFirstChildOfClass("Clouds")
	if oldClouds then
		oldClouds:Destroy()
	end
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.5
	clouds.Density = 0.35
	clouds.Color = Color3.fromRGB(225, 230, 238)
	clouds.Parent = Terrain
end

local function buildTerrain()
	Terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(135, 175, 85))
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(175, 155, 120))
	Terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(115, 95, 75))

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
		-- Highway Streetlight extending over roadway
		makePart({
			Name = "StreetlightArm",
			Size = Vector3.new(12, 0.5, 0.5),
			Position = Vector3.new(19, 29.5, z),
			Color = Color3.fromRGB(130, 135, 140),
			Material = Enum.Material.Metal,
		}, parent)
		local lampHead = makePart({
			Name = "StreetlightLamp",
			Size = Vector3.new(3, 0.6, 1.4),
			Position = Vector3.new(13, 29, z),
			Color = Color3.fromRGB(255, 250, 230),
			Material = Enum.Material.Neon,
		}, parent)
		local streetSpot = Instance.new("SpotLight")
		streetSpot.Name = "StreetSpot"
		streetSpot.Face = Enum.NormalId.Bottom
		streetSpot.Brightness = 4.5
		streetSpot.Range = 50
		streetSpot.Angle = 80
		streetSpot.Color = Color3.fromRGB(255, 248, 225)
		streetSpot.Shadows = true
		streetSpot.Parent = lampHead

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

	-- Research HQ trailer entrance porch light
	local porchLightPart = makePart({
		Name = "TrailerPorchLight",
		Size = Vector3.new(1.2, 1.2, 0.6),
		Position = p + Vector3.new(14.2, 2.5, -3),
		Color = Color3.fromRGB(255, 245, 210),
		Material = Enum.Material.Neon,
	}, base)
	local porchLight = Instance.new("PointLight")
	porchLight.Brightness = 3
	porchLight.Range = 25
	porchLight.Color = Color3.fromRGB(255, 240, 200)
	porchLight.Shadows = true
	porchLight.Parent = porchLightPart

	-- Spinning Doppler radar dish
	local dishMast = makePart({
		Name = "DishMast",
		Size = Vector3.new(2, 10, 2),
		Position = p + Vector3.new(0, 10, 0),
		Color = Color3.fromRGB(100, 100, 105),
		Material = Enum.Material.Metal,
	}, base)

	-- Red aviation warning beacon on the radar mast
	local redBeacon = makePart({
		Name = "RadarWarningBeacon",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 1.4, 1.4),
		CFrame = CFrame.new(dishMast.Position + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.Neon,
	}, base)
	local beaconLight = Instance.new("PointLight")
	beaconLight.Color = Color3.fromRGB(255, 40, 40)
	beaconLight.Brightness = 4
	beaconLight.Range = 35
	beaconLight.Parent = redBeacon

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

	-- Dual Depot Stadium Floodlight Towers illuminating spawn and vehicle bays
	for _, towerPos in { Vector3.new(16, 0, 105), Vector3.new(-16, 0, 138) } do
		makePart({
			Name = "FloodlightTower",
			Size = Vector3.new(1.6, 26, 1.6),
			Position = towerPos + Vector3.new(0, 13, 0),
			Color = Color3.fromRGB(75, 80, 85),
			Material = Enum.Material.Metal,
		}, base)

		makePart({
			Name = "FloodlightCrossBar",
			Size = Vector3.new(6, 0.8, 0.8),
			Position = towerPos + Vector3.new(0, 25.5, 0),
			Color = Color3.fromRGB(60, 65, 70),
			Material = Enum.Material.Metal,
		}, base)

		for _, dx in { -2.2, 2.2 } do
			local lamp = makePart({
				Name = "FloodLamp",
				Size = Vector3.new(1.8, 1.2, 1.6),
				CFrame = CFrame.new(towerPos + Vector3.new(dx, 25, 0)) * CFrame.Angles(math.rad(-25), 0, 0),
				Color = Color3.fromRGB(255, 250, 235),
				Material = Enum.Material.Neon,
			}, base)

			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Brightness = 6.5
			spot.Range = 90
			spot.Angle = 80
			spot.Color = Color3.fromRGB(255, 245, 220)
			spot.Shadows = true
			spot.Parent = lamp
		end
	end

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

local function buildVintageLamppost(pos: Vector3, parent: Instance)
	local postModel = Instance.new("Model")
	postModel.Name = "VintageLamppost"

	makePart({
		Name = "Plinth",
		Size = Vector3.new(2, 1.2, 2),
		Position = pos + Vector3.new(0, 0.6, 0),
		Color = Color3.fromRGB(35, 38, 42),
		Material = Enum.Material.Metal,
	}, postModel)

	makePart({
		Name = "Pole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 0.9, 0.9),
		CFrame = CFrame.new(pos + Vector3.new(0, 7.6, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(38, 42, 46),
		Material = Enum.Material.Metal,
	}, postModel)

	makePart({
		Name = "Arm",
		Size = Vector3.new(1.8, 0.8, 1.8),
		Position = pos + Vector3.new(0, 14.8, 0),
		Color = Color3.fromRGB(35, 38, 42),
		Material = Enum.Material.Metal,
	}, postModel)

	local globe = makePart({
		Name = "GlassGlobe",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		Position = pos + Vector3.new(0, 16.2, 0),
		Color = Color3.fromRGB(255, 248, 220),
		Material = Enum.Material.Neon,
	}, postModel)

	makePart({
		Name = "GlobeCap",
		Size = Vector3.new(2.2, 0.6, 2.2),
		Position = pos + Vector3.new(0, 17.5, 0),
		Color = Color3.fromRGB(32, 35, 38),
		Material = Enum.Material.Metal,
	}, postModel)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 235, 195)
	light.Brightness = 3.8
	light.Range = 36
	light.Shadows = true
	light.Parent = globe

	postModel.Parent = parent
end

local function buildAbandonedCar(cf: CFrame, carType: string, parent: Instance)
	local car = Instance.new("Model")
	car.Name = "AbandonedCar_" .. carType

	destructible(makePart({
		Name = "Chassis",
		Size = Vector3.new(7.6, 1.4, 16),
		CFrame = cf * CFrame.new(0, 1.4, 0),
		Color = Color3.fromRGB(45, 48, 52),
		Material = Enum.Material.Metal,
	}, car))

	for _, offset in {
		Vector3.new(-3.9, -0.6, 4.8),
		Vector3.new(3.9, -0.6, 4.8),
		Vector3.new(-3.9, -0.6, -4.8),
		Vector3.new(3.9, -0.6, -4.8),
	} do
		destructible(makePart({
			Name = "FlatTire",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.1, 2.8, 2.8),
			CFrame = cf * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(25, 25, 28),
			Material = Enum.Material.Rubber,
		}, car))
	end

	if carType == "StationWagon" then
		destructible(makePart({
			Name = "Body",
			Size = Vector3.new(7.4, 2.8, 15.6),
			CFrame = cf * CFrame.new(0, 3.2, 0),
			Color = Color3.fromRGB(140, 120, 95),
			Material = Enum.Material.Metal,
		}, car))

		for _, side in { -3.75, 3.75 } do
			destructible(makePart({
				Name = "WoodgrainPanel",
				Size = Vector3.new(0.2, 1.6, 13.5),
				CFrame = cf * CFrame.new(side, 3.0, 0),
				Color = Color3.fromRGB(115, 68, 36),
				Material = Enum.Material.WoodPlanks,
			}, car))
		end

		for _, side in { -2.8, 2.8 } do
			destructible(makePart({
				Name = "RoofRail",
				Size = Vector3.new(0.3, 0.4, 8),
				CFrame = cf * CFrame.new(side, 4.8, -1),
				Color = Color3.fromRGB(180, 180, 185),
				Material = Enum.Material.Metal,
			}, car))
		end

		destructible(makePart({
			Name = "Windshield",
			Size = Vector3.new(6.8, 1.8, 0.3),
			CFrame = cf * CFrame.new(0, 3.8, -4.2) * CFrame.Angles(math.rad(25), 0, 0),
			Color = Color3.fromRGB(60, 75, 85),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Reflectance = 0.3,
		}, car))

		destructible(makePart({
			Name = "Bumper",
			Size = Vector3.new(7.8, 0.9, 0.8),
			CFrame = cf * CFrame.new(0, 1.8, -8.1),
			Color = Color3.fromRGB(200, 200, 205),
			Material = Enum.Material.Metal,
		}, car))

	elseif carType == "Sedan" then
		destructible(makePart({
			Name = "Hood",
			Size = Vector3.new(7.2, 1.8, 5.5),
			CFrame = cf * CFrame.new(0, 2.5, -4.8),
			Color = Color3.fromRGB(120, 138, 130),
			Material = Enum.Material.Metal,
		}, car))

		destructible(makePart({
			Name = "Cabin",
			Size = Vector3.new(6.8, 2.4, 6.5),
			CFrame = cf * CFrame.new(0, 3.8, 0.5),
			Color = Color3.fromRGB(120, 138, 130),
			Material = Enum.Material.Metal,
		}, car))

		destructible(makePart({
			Name = "Trunk",
			Size = Vector3.new(7.2, 1.6, 4.2),
			CFrame = cf * CFrame.new(0, 2.4, 5.4),
			Color = Color3.fromRGB(115, 130, 125),
			Material = Enum.Material.Metal,
		}, car))

		destructible(makePart({
			Name = "Windshield",
			Size = Vector3.new(6.4, 2, 0.3),
			CFrame = cf * CFrame.new(0, 3.6, -2.8) * CFrame.Angles(math.rad(28), 0, 0),
			Color = Color3.fromRGB(55, 70, 80),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			Reflectance = 0.25,
		}, car))

		destructible(makePart({
			Name = "FrontBumper",
			Size = Vector3.new(7.6, 0.8, 0.7),
			CFrame = cf * CFrame.new(0, 1.6, -7.8),
			Color = Color3.fromRGB(195, 195, 200),
			Material = Enum.Material.Metal,
		}, car))

	elseif carType == "Pickup" then
		destructible(makePart({
			Name = "Hood",
			Size = Vector3.new(7.4, 2.2, 5.2),
			CFrame = cf * CFrame.new(0, 2.8, -4.5),
			Color = Color3.fromRGB(140, 75, 45),
			Material = Enum.Material.CorrodedMetal,
		}, car))

		destructible(makePart({
			Name = "Cab",
			Size = Vector3.new(7.2, 3.2, 4.8),
			CFrame = cf * CFrame.new(0, 4.2, 0),
			Color = Color3.fromRGB(135, 70, 40),
			Material = Enum.Material.CorrodedMetal,
		}, car))

		destructible(makePart({
			Name = "BedFloor",
			Size = Vector3.new(7.2, 0.8, 6.5),
			CFrame = cf * CFrame.new(0, 2.2, 5.4),
			Color = Color3.fromRGB(110, 60, 35),
			Material = Enum.Material.CorrodedMetal,
		}, car))
		for _, side in { -3.6, 3.6 } do
			destructible(makePart({
				Name = "BedWall",
				Size = Vector3.new(0.5, 2.2, 6.5),
				CFrame = cf * CFrame.new(side, 3.2, 5.4),
				Color = Color3.fromRGB(125, 65, 38),
				Material = Enum.Material.CorrodedMetal,
			}, car))
		end
		destructible(makePart({
			Name = "Tailgate",
			Size = Vector3.new(7.2, 2.2, 0.5),
			CFrame = cf * CFrame.new(0, 3.2, 8.6),
			Color = Color3.fromRGB(120, 60, 35),
			Material = Enum.Material.CorrodedMetal,
		}, car))
	end

	car.Parent = parent
end

local function buildStorefront(
	center: Vector3,
	width: number,
	depth: number,
	floors: number,
	title: string,
	awningColor: Color3,
	awningStripe: Color3,
	parent: Instance
)
	local bldg = Instance.new("Model")
	bldg.Name = "Storefront_" .. title

	local totalHeight = floors * 15

	-- Main Brick Shell
	destructible(makePart({
		Name = "Facade",
		Size = Vector3.new(width, totalHeight, depth),
		Position = center + Vector3.new(0, totalHeight / 2, 0),
		Color = Color3.fromRGB(135, 65, 55),
		Material = Enum.Material.Brick,
	}, bldg))

	-- Roof Parapet / Cornice
	destructible(makePart({
		Name = "Cornice",
		Size = Vector3.new(width + 2, 2.5, depth + 2),
		Position = center + Vector3.new(0, totalHeight + 1.25, 0),
		Color = Color3.fromRGB(160, 160, 155),
		Material = Enum.Material.Concrete,
	}, bldg))

	-- Display Windows
	local facingSign = if center.X < 0 then 1 else -1
	for _, dz in { -depth * 0.28, depth * 0.28 } do
		destructible(makePart({
			Name = "DisplayWindow",
			Size = Vector3.new(0.6, 7.5, depth * 0.38),
			Position = center + Vector3.new(facingSign * (width / 2 + 0.1), 5.5, dz),
			Color = Color3.fromRGB(50, 65, 75),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
			Reflectance = 0.25,
		}, bldg))
	end

	-- Awning over display windows (striped canvas fabric matching reference image)
	local awningOffsetX = facingSign * (width / 2 + 3.2)
	local awningRotZ = facingSign * math.rad(-22)
	for i = 0, 7 do
		local stripeColor = if i % 2 == 0 then awningColor else awningStripe
		local stripDepth = (depth - 2) / 8
		local sz = -depth / 2 + 1 + stripDepth * (i + 0.5)
		destructible(makePart({
			Name = "AwningStripe",
			Size = Vector3.new(7, 0.4, stripDepth),
			CFrame = CFrame.new(center + Vector3.new(awningOffsetX, 9.5, sz)) * CFrame.Angles(0, 0, awningRotZ),
			Color = stripeColor,
			Material = Enum.Material.Fabric,
		}, bldg))
	end

	-- Signboard with Store Title
	local signBoard = destructible(makePart({
		Name = "StoreSign",
		Size = Vector3.new(0.8, 3, depth * 0.8),
		Position = center + Vector3.new(facingSign * (width / 2 + 0.5), 12, 0),
		Color = Color3.fromRGB(40, 42, 45),
		Material = Enum.Material.Wood,
	}, bldg))

	local sg = Instance.new("SurfaceGui")
	sg.Face = if center.X < 0 then Enum.NormalId.Right else Enum.NormalId.Left
	sg.Adornee = signBoard
	sg.Parent = signBoard

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = title
	lbl.TextColor3 = Color3.fromRGB(255, 235, 190)
	lbl.Font = Enum.Font.Antique
	lbl.TextScaled = true
	lbl.Parent = sg

	-- Second Floor Windows & Window AC Unit
	if floors >= 2 then
		for _, dz in { -depth * 0.3, 0, depth * 0.3 } do
			destructible(makePart({
				Name = "UpperWindow",
				Size = Vector3.new(0.4, 5, 3.5),
				Position = center + Vector3.new(facingSign * (width / 2 + 0.2), 20.5, dz),
				Color = Color3.fromRGB(60, 75, 85),
				Material = Enum.Material.Glass,
				Reflectance = 0.2,
			}, bldg))
			destructible(makePart({
				Name = "WindowSill",
				Size = Vector3.new(0.8, 0.8, 4.2),
				Position = center + Vector3.new(facingSign * (width / 2 + 0.4), 17.6, dz),
				Color = Color3.fromRGB(180, 180, 185),
				Material = Enum.Material.Concrete,
			}, bldg))
		end

		destructible(makePart({
			Name = "WindowACUnit",
			Size = Vector3.new(2.5, 2.2, 2.8),
			Position = center + Vector3.new(facingSign * (width / 2 + 1.2), 19.5, depth * 0.3),
			Color = Color3.fromRGB(195, 198, 202),
			Material = Enum.Material.Metal,
		}, bldg))
	end

	local intLight = Instance.new("PointLight")
	intLight.Color = Color3.fromRGB(255, 235, 190)
	intLight.Brightness = 2.5
	intLight.Range = 35
	intLight.Parent = signBoard

	bldg.Parent = parent
end

local function buildAbandonedHouse(pos: Vector3, rotY: number, style: number, parent: Instance)
	local house = Instance.new("Model")
	house.Name = "AbandonedHouse_" .. style

	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(rotY), 0)

	local wallColors = {
		Color3.fromRGB(95, 115, 130),  -- Weathered blue-gray weatherboard
		Color3.fromRGB(195, 195, 190), -- Peeling white colonial
		Color3.fromRGB(80, 62, 48),    -- Dark craftsman wood
		Color3.fromRGB(135, 60, 50),   -- Aged red brick
		Color3.fromRGB(160, 150, 135), -- Weathered stucco
		Color3.fromRGB(65, 70, 75),    -- Dark Victorian slate
	}
	local wallMat = if style == 4 then Enum.Material.Brick else Enum.Material.WoodPlanks
	local wallColor = wallColors[((style - 1) % #wallColors) + 1]

	-- Foundation
	makePart({
		Name = "Foundation",
		Size = Vector3.new(36, 1.8, 42),
		CFrame = cf * CFrame.new(0, 0.9, 0),
		Color = Color3.fromRGB(120, 120, 125),
		Material = Enum.Material.Concrete,
	}, house)

	-- Ground Floor Walls
	local wallH = 14
	destructible(makePart({
		Name = "HouseBody",
		Size = Vector3.new(34, wallH, 40),
		CFrame = cf * CFrame.new(0, 1.8 + wallH / 2, 0),
		Color = wallColor,
		Material = wallMat,
	}, house))

	-- Front Porch Deck & Steps
	local porchZ = 20 + 4
	destructible(makePart({
		Name = "PorchDeck",
		Size = Vector3.new(34, 1.2, 8),
		CFrame = cf * CFrame.new(0, 1.6, porchZ),
		Color = Color3.fromRGB(90, 70, 52),
		Material = Enum.Material.WoodPlanks,
	}, house))

	for _, px in { -15, 0, 15 } do
		destructible(makePart({
			Name = "PorchPost",
			Size = Vector3.new(1.2, 10, 1.2),
			CFrame = cf * CFrame.new(px, 6.8, porchZ + 3.2),
			Color = Color3.fromRGB(180, 180, 175),
			Material = Enum.Material.Wood,
		}, house))
	end

	destructible(makePart({
		Name = "PorchRoof",
		Size = Vector3.new(36, 1, 9),
		CFrame = cf * CFrame.new(0, 12.2, porchZ) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = Color3.fromRGB(130, 135, 140),
		Material = Enum.Material.CorrodedMetal,
	}, house))

	local roofPeakY = 1.8 + wallH + 9
	for _, side in { -1, 1 } do
		destructible(makePart({
			Name = "RoofPanel",
			Size = Vector3.new(20, 1.2, 44),
			CFrame = cf * CFrame.new(side * 9, roofPeakY - 4, 0) * CFrame.Angles(0, 0, math.rad(-side * 28)),
			Color = Color3.fromRGB(110, 115, 120),
			Material = Enum.Material.CorrodedMetal,
		}, house))
	end

	for _, gz in { -20, 20 } do
		for _, side in { -1, 1 } do
			destructible(makePart({
				ClassName = "WedgePart",
				Name = "Gable",
				Size = Vector3.new(1.2, 8, 17),
				CFrame = cf * CFrame.new(side * 8.5, roofPeakY - 4, gz) * CFrame.Angles(0, if gz > 0 then math.rad(90) else math.rad(-90), 0) * CFrame.Angles(0, 0, if side > 0 then 0 else math.rad(180)),
				Color = wallColor,
				Material = wallMat,
			}, house))
		end
	end

	destructible(makePart({
		Name = "Chimney",
		Size = Vector3.new(4, 22, 4),
		CFrame = cf * CFrame.new(-12, 14, -8),
		Color = Color3.fromRGB(140, 55, 45),
		Material = Enum.Material.Brick,
	}, house))

	-- Boarded-up Windows
	for _, wx in { -9, 9 } do
		destructible(makePart({
			Name = "WindowFrame",
			Size = Vector3.new(4.8, 5.2, 0.4),
			CFrame = cf * CFrame.new(wx, 8, 20.2),
			Color = Color3.fromRGB(210, 210, 205),
			Material = Enum.Material.Wood,
		}, house))
		for _, pAngle in { -20, 20, 0 } do
			destructible(makePart({
				Name = "BoardedPlank",
				Size = Vector3.new(5.6, 1, 0.3),
				CFrame = cf * CFrame.new(wx, 8, 20.5) * CFrame.Angles(0, 0, math.rad(pAngle)),
				Color = Color3.fromRGB(80, 58, 40),
				Material = Enum.Material.WoodPlanks,
			}, house))
		end
	end

	for fx = -18, 18, 5 do
		if math.abs(fx) > 4 then
			destructible(makePart({
				Name = "PicketPost",
				Size = Vector3.new(0.6, 4.2, 0.6),
				CFrame = cf * CFrame.new(fx, 2.1, 32) * CFrame.Angles(0, 0, math.rad((fx % 3) * 6 - 6)),
				Color = Color3.fromRGB(190, 190, 185),
				Material = Enum.Material.Wood,
			}, house))
		end
	end

	local porchLantern = makePart({
		Name = "PorchLantern",
		Size = Vector3.new(0.8, 1.2, 0.8),
		CFrame = cf * CFrame.new(4, 9, 20.6),
		Color = Color3.fromRGB(255, 240, 210),
		Material = Enum.Material.Neon,
	}, house)
	local pLight = Instance.new("PointLight")
	pLight.Color = Color3.fromRGB(255, 230, 190)
	pLight.Brightness = 2.5
	pLight.Range = 28
	pLight.Parent = porchLantern

	house.Parent = parent
end

local function buildGroundFogEmitter(pos: Vector3, size: Vector3, parent: Instance)
	local fogPart = Instance.new("Part")
	fogPart.Name = "GroundFogZone"
	fogPart.Size = size
	fogPart.Position = pos
	fogPart.Anchored = true
	fogPart.CanCollide = false
	fogPart.CanQuery = false
	fogPart.CanTouch = false
	fogPart.Transparency = 1
	fogPart.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RollingMist"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(9, 15)
	emitter.Speed = NumberRange.new(1.5, 4)
	emitter.SpreadAngle = Vector2.new(180, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 22),
		NumberSequenceKeypoint.new(0.5, 52),
		NumberSequenceKeypoint.new(1, 68),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 0.88),
		NumberSequenceKeypoint.new(0.82, 0.93),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(225, 230, 238))
	emitter.LightInfluence = 0.8
	emitter.Parent = fogPart
end

local function buildSilentHillTown(parent: Instance)
	local town = Instance.new("Model")
	town.Name = "SilentHillTown"

	-- Main Street (Wet reflective asphalt matching the reference image)
	makePart({
		Name = "MainStreetRoad",
		Size = Vector3.new(38, 1.2, 500),
		Position = Vector3.new(0, 1.1, 0),
		Color = Color3.fromRGB(45, 48, 52),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.32,
	}, town)

	-- Double yellow centerlines
	for _, x in { -1.0, 1.0 } do
		makePart({
			Name = "RoadLine",
			Size = Vector3.new(0.6, 1.25, 500),
			Position = Vector3.new(x, 1.15, 0),
			Color = Color3.fromRGB(225, 185, 35),
			Material = Enum.Material.SmoothPlastic,
		}, town)
	end

	-- Concrete Sidewalks & Curbs
	for _, side in { -1, 1 } do
		makePart({
			Name = "Sidewalk",
			Size = Vector3.new(14, 1.4, 500),
			Position = Vector3.new(side * 26, 1.2, 0),
			Color = Color3.fromRGB(160, 160, 155),
			Material = Enum.Material.Concrete,
		}, town)
		makePart({
			Name = "Curb",
			Size = Vector3.new(1.2, 1.8, 500),
			Position = Vector3.new(side * 19.5, 1.3, 0),
			Color = Color3.fromRGB(145, 145, 140),
			Material = Enum.Material.Concrete,
		}, town)
	end

	-- Pedestrian Crosswalks (white stripes across street matching reference image!)
	for _, z in { 35, -35 } do
		for x = -16, 16, 4 do
			makePart({
				Name = "CrosswalkStripe",
				Size = Vector3.new(2.4, 0.05, 10),
				Position = Vector3.new(x, 1.25, z),
				Color = Color3.fromRGB(235, 235, 230),
				Material = Enum.Material.SmoothPlastic,
			}, town)
		end
	end

	-- Cross Street (Maple Street - Residential Avenue)
	makePart({
		Name = "MapleStreetRoad",
		Size = Vector3.new(380, 1.2, 32),
		Position = Vector3.new(0, 1.12, -35),
		Color = Color3.fromRGB(48, 50, 55),
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.30,
	}, town)
	for _, side in { -1, 1 } do
		makePart({
			Name = "MapleSidewalk",
			Size = Vector3.new(380, 1.4, 10),
			Position = Vector3.new(0, 1.2, -35 + side * 21),
			Color = Color3.fromRGB(160, 160, 155),
			Material = Enum.Material.Concrete,
		}, town)
	end

	-- Storefronts along Main Street
	-- West Side: Ashwood Diner, Pharmacy & Sundries, Hardware & Feed
	buildStorefront(Vector3.new(-48, 1, 80), 32, 28, 2, "ASHWOOD DINER", Color3.fromRGB(140, 35, 30), Color3.fromRGB(240, 235, 220), town)
	buildStorefront(Vector3.new(-48, 1, 20), 30, 26, 2, "PHARMACY & SUNDRIES", Color3.fromRGB(35, 95, 55), Color3.fromRGB(230, 240, 235), town)
	buildStorefront(Vector3.new(-48, 1, -95), 34, 28, 2, "HARDWARE & FEED", Color3.fromRGB(130, 75, 35), Color3.fromRGB(60, 60, 65), town)

	-- East Side: Auto Repair, General Goods, Town Post Office
	buildStorefront(Vector3.new(48, 1, 80), 32, 28, 2, "SILENT PEAKS AUTO", Color3.fromRGB(45, 50, 60), Color3.fromRGB(220, 140, 30), town)
	buildStorefront(Vector3.new(48, 1, 20), 30, 26, 2, "GENERAL GOODS", Color3.fromRGB(120, 40, 40), Color3.fromRGB(240, 235, 215), town)
	buildStorefront(Vector3.new(48, 1, -95), 34, 28, 2, "TOWN POST & TELEGRAPH", Color3.fromRGB(40, 70, 120), Color3.fromRGB(235, 235, 240), town)

	-- 6 Detailed Abandoned Residential Houses along Maple Street
	buildAbandonedHouse(Vector3.new(-85, 1, 15), 0, 1, town)   -- Blue Weatherboard
	buildAbandonedHouse(Vector3.new(-145, 1, 15), 0, 2, town)  -- Peeling White Colonial
	buildAbandonedHouse(Vector3.new(-85, 1, -85), 180, 3, town) -- Dark Craftsman Bungalow
	buildAbandonedHouse(Vector3.new(85, 1, 15), 0, 4, town)    -- Derelict Brick Farmstead
	buildAbandonedHouse(Vector3.new(145, 1, 15), 0, 5, town)   -- Storybook Cottage
	buildAbandonedHouse(Vector3.new(85, 1, -85), 180, 6, town)  -- Dilapidated Victorian

	-- Abandoned Vehicles matching the reference image!
	-- 1980s wood-paneled station wagon parked along curb on the left
	buildAbandonedCar(CFrame.new(-14, 1.2, 55) * CFrame.Angles(0, math.rad(-10), 0), "StationWagon", town)
	-- Vintage sedan parked crookedly across the curb on the right
	buildAbandonedCar(CFrame.new(15, 1.2, 12) * CFrame.Angles(0, math.rad(28), 0), "Sedan", town)
	-- Rusted pickup truck abandoned near the intersection
	buildAbandonedCar(CFrame.new(-13, 1.2, -65) * CFrame.Angles(0, math.rad(6), 0), "Pickup", town)
	-- Abandoned sedan on Maple Street
	buildAbandonedCar(CFrame.new(-115, 1.2, -35) * CFrame.Angles(0, math.rad(85), 0), "Sedan", town)

	-- Vintage Cast-Iron Lampposts lining both sides of Main Street
	for z = -180, 180, 45 do
		for _, side in { -1, 1 } do
			buildVintageLamppost(Vector3.new(side * 20, 1.3, z), town)
		end
	end

	-- Vintage Lampposts along Maple Street
	for _, x in { -160, -115, -70, 70, 115, 160 } do
		buildVintageLamppost(Vector3.new(x, 1.3, -24), town)
		buildVintageLamppost(Vector3.new(x, 1.3, -46), town)
	end

	-- Blue USPS Mailboxes
	local function buildMailbox(pos: Vector3)
		local box = Instance.new("Model")
		box.Name = "USPSMailbox"
		makePart({ Name = "Stand", Size = Vector3.new(1.8, 1.4, 1.6), Position = pos + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(40, 45, 50), Material = Enum.Material.Metal }, box)
		makePart({ Name = "Body", Size = Vector3.new(2.4, 2.8, 2.2), Position = pos + Vector3.new(0, 2.6, 0), Color = Color3.fromRGB(35, 75, 150), Material = Enum.Material.Metal }, box)
		makePart({ Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 4.0, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(35, 75, 150), Material = Enum.Material.Metal }, box)
		box.Parent = town
	end
	buildMailbox(Vector3.new(21, 1.3, 30))
	buildMailbox(Vector3.new(-21, 1.3, -30))

	-- Fire Hydrants
	local function buildFireHydrant(pos: Vector3)
		local hyd = Instance.new("Model")
		hyd.Name = "FireHydrant"
		makePart({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.8, 1.4, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(195, 45, 40), Material = Enum.Material.Metal }, hyd)
		makePart({ Name = "TopNut", Size = Vector3.new(1.4, 0.6, 1.4), Position = pos + Vector3.new(0, 3.1, 0), Color = Color3.fromRGB(225, 185, 30), Material = Enum.Material.Metal }, hyd)
		hyd.Parent = town
	end
	buildFireHydrant(Vector3.new(-21, 1.3, 65))
	buildFireHydrant(Vector3.new(21, 1.3, -70))

	-- Overgrown curb weeds
	local weedRng = Random.new(42)
	for z = -180, 180, 20 do
		for _, side in { -19.4, 19.4 } do
			makePart({
				Name = "CurbWeed",
				Size = Vector3.new(1.4, 0.9, 1.4),
				Position = Vector3.new(side + weedRng:NextNumber(-0.3, 0.3), 1.5, z + weedRng:NextNumber(-2, 2)),
				Color = Color3.fromRGB(75, 105, 55),
				Material = Enum.Material.Grass,
			}, town)
		end
	end

	-- Volumetric Ground-Hugging Fog Emitters along streets (matching the cinematic mist in screenshot)
	for _, z in { -140, -70, 0, 70, 140 } do
		buildGroundFogEmitter(Vector3.new(0, 2.5, z), Vector3.new(38, 3, 50), town)
	end
	for _, x in { -120, -60, 60, 120 } do
		buildGroundFogEmitter(Vector3.new(x, 2.5, -35), Vector3.new(50, 3, 30), town)
	end

	town.Parent = parent
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

	-- Surface caution floodlights at the collar corners
	for _, corner in {
		Vector3.new(-11, 3.5, -11),
		Vector3.new(11, 3.5, -11),
		Vector3.new(-11, 3.5, 11),
		Vector3.new(11, 3.5, 11),
	} do
		local lightPost = makePart({
			Name = "BunkerCautionLight",
			Size = Vector3.new(0.8, 2, 0.8),
			Position = bunkerPos + corner,
			Color = Color3.fromRGB(255, 180, 20),
			Material = Enum.Material.Neon,
		}, bunker)
		local pLight = Instance.new("PointLight")
		pLight.Color = Color3.fromRGB(255, 190, 30)
		pLight.Brightness = 4.5
		pLight.Range = 35
		pLight.Shadows = true
		pLight.Parent = lightPost
	end

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
	buildSilentHillTown(worldFolder)
	buildScenery(worldFolder)
	buildUndergroundStormBunker(worldFolder)

	print("[FunnelRunnersWorld] Silent Hill abandoned foggy town with EF5 wedge loaded.")
end

initializeWorld()
