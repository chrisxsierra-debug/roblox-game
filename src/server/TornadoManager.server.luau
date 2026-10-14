--!strict
-- TornadoManager.server.luau
-- Runs the storm cycle using the round timings in FunnelRunnersConfig.Manager:
--   Forecast:     storm cells develop on radar where minor tornadoes will touch down
--   Minor:        1-2 minor tornadoes touch down at random spots away from players and wander
--   FinalWarning: the minors rope out; the final wedge's wall cloud rolls in from a map edge
--   Final:        the EF5 wedge touches down and tracks toward the nearest exposed chaser
--   Intermission: everything dissipates, then the cycle repeats
-- Radar data is published as attributes under ReplicatedStorage.StormState (no per-frame remotes).

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("FunnelRunnersConfig"))
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

local Server = script.Parent
local RankineEngine = require(Server:WaitForChild("RankineVortexEngine"))
local TornadoBuilder = require(Server:WaitForChild("TornadoBuilder"))

local worldFolder = Workspace:WaitForChild("FunnelRunnersWorld", 15)

local MAP_HALF = 330 -- tornadoes stay inside this square (the prairie is about 400 studs from center)
local MIN_SPAWN_DISTANCE = 220 -- minor tornadoes touch down at least this far from every player
local RETARGET_SECONDS = 8 -- how often the final wedge re-aims at a chaser

local TORNADO_TYPES = {
	Minor = {
		Params = Config.MinorTornado,
		Shape = { BottomRadius = 8, TopRadius = 38, Height = 150, CloudDiameter = 280 },
		-- Overrides for RankineVortexEngine's defaults (which are tuned for the EF5 wedge)
		Physics = {
			CoreRadius = 14,
			MaxRadius = Config.MinorTornado.SuctionRadius,
			MaxTangentialSpeed = 110,
			InwardPullForce = 60,
			UpwardLift = 90,
			CoreHeight = 150,
			DamagePerSecond = Config.MinorTornado.CoreDamagePerSecond,
		},
		CellSpeed = 4, -- drift speed before touchdown
		Speed = 14,
	},
	Final = {
		Params = Config.FinalTornado,
		Shape = { BottomRadius = 34, TopRadius = 124, Height = 220, CloudDiameter = 560 },
		Physics = {},
		CellSpeed = 6,
		Speed = 16,
	},
}

type Storm = {
	Kind: string,
	Tornado: TornadoBuilder.Tornado,
	Info: Configuration, -- radar data, replicated to clients
	Engine: any?, -- RankineVortexEngine, created at touchdown
	Target: Vector3,
	Speed: number,
	Chasing: boolean,
	NextRetarget: number,
}

local storms: { Storm } = {}
local nextStormId = 0

local stormState = Instance.new("Folder")
stormState.Name = "StormState"
stormState.Parent = ReplicatedStorage

local function setPhase(phase: string, duration: number)
	stormState:SetAttribute("Phase", phase)
	stormState:SetAttribute("PhaseEndsAt", Workspace:GetServerTimeNow() + duration)
end

local function exposedRoots(): { BasePart }
	local roots = {}
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and char:GetAttribute("IsSheltered") ~= true then
			table.insert(roots, root)
		end
	end
	return roots
end

local function randomMapPoint(): Vector3
	return Vector3.new(math.random(-MAP_HALF, MAP_HALF), 2, math.random(-MAP_HALF, MAP_HALF))
end

-- Random spot far from every player (falls back to the farthest candidate found)
local function randomPointAwayFromPlayers(minDistance: number): Vector3
	local best, bestDistance = randomMapPoint(), -1
	for _ = 1, 30 do
		local candidate = randomMapPoint()
		local nearest = math.huge
		for _, root in exposedRoots() do
			nearest = math.min(nearest, (Vector3.new(root.Position.X, 2, root.Position.Z) - candidate).Magnitude)
		end
		if nearest >= minDistance then
			return candidate
		elseif nearest > bestDistance then
			best, bestDistance = candidate, nearest
		end
	end
	return best
end

local function randomEdgePoint(): Vector3
	local along = math.random(-MAP_HALF, MAP_HALF)
	local side = math.random(1, 4)
	if side == 1 then
		return Vector3.new(along, 2, -MAP_HALF)
	elseif side == 2 then
		return Vector3.new(along, 2, MAP_HALF)
	elseif side == 3 then
		return Vector3.new(-MAP_HALF, 2, along)
	end
	return Vector3.new(MAP_HALF, 2, along)
end

local function clampToMap(point: Vector3): Vector3
	return Vector3.new(math.clamp(point.X, -MAP_HALF, MAP_HALF), 2, math.clamp(point.Z, -MAP_HALF, MAP_HALF))
end

-- A storm starts as a wall cloud with no funnel and no physics
local function createStorm(kind: string, position: Vector3): Storm
	local stormType = TORNADO_TYPES[kind]
	nextStormId += 1
	local tornado = TornadoBuilder.Build("Tornado_" .. nextStormId, stormType.Shape, position, worldFolder)
	TornadoBuilder.ShowClouds(tornado, 8)

	local info = Instance.new("Configuration")
	info.Name = "Storm_" .. nextStormId
	info:SetAttribute("Kind", kind)
	info:SetAttribute("DisplayName", stormType.Params.Name)
	info:SetAttribute("Category", stormType.Params.Category)
	info:SetAttribute("Position", tornado.Root.Position)
	info:SetAttribute("Radius", stormType.Shape.BottomRadius)
	info:SetAttribute("TouchedDown", false)
	info:SetAttribute("Wind", 0)
	info.Parent = stormState

	local storm: Storm = {
		Kind = kind,
		Tornado = tornado,
		Info = info,
		Engine = nil,
		Target = randomMapPoint(),
		Speed = stormType.CellSpeed,
		Chasing = false,
		NextRetarget = 0,
	}
	table.insert(storms, storm)
	return storm
end

local function touchdown(storm: Storm)
	if not table.find(storms, storm) then
		return
	end
	local stormType = TORNADO_TYPES[storm.Kind]
	TornadoBuilder.Touchdown(storm.Tornado, 5)
	storm.Info:SetAttribute("TouchedDown", true)
	storm.Tornado.Root:SetAttribute("TouchedDown", true)

	-- Physics starts once the funnel reaches the ground
	task.delay(3, function()
		if not table.find(storms, storm) then
			return
		end
		local engine = RankineEngine.new(storm.Tornado.Root)
		for key, value in stormType.Physics do
			engine.Config[key] = value
		end
		for _, zone in CollectionService:GetTagged("StormBunker") do
			if zone:IsA("BasePart") then
				engine:AddBlockage(zone)
			end
		end
		storm.Engine = engine
		storm.Speed = stormType.Speed
	end)
end

local function dissipate(storm: Storm)
	local index = table.find(storms, storm)
	if not index then
		return
	end
	table.remove(storms, index)
	storm.Engine = nil
	storm.Tornado.Root:SetAttribute("TouchedDown", false)
	storm.Info:Destroy()
	TornadoBuilder.Dissipate(storm.Tornado, 8)
end

-- The final wedge heads for the nearest exposed chaser, aiming a little off so it can be outrun
local function chaseTarget(storm: Storm): Vector3
	local position = storm.Tornado.Root.Position
	local nearest: BasePart? = nil
	for _, root in exposedRoots() do
		if not nearest or (root.Position - position).Magnitude < (nearest.Position - position).Magnitude then
			nearest = root
		end
	end
	if not nearest then
		return randomMapPoint()
	end
	return clampToMap(nearest.Position + Vector3.new(math.random(-60, 60), 0, math.random(-60, 60)))
end

-- Lightning strikes near a random storm
local function triggerLightning(near: Vector3)
	local strikePos = Vector3.new(near.X + math.random(-80, 80), 0, near.Z + math.random(-80, 80))

	local bolt = Instance.new("Part")
	bolt.Size = Vector3.new(2.5, 280, 2.5)
	bolt.Position = strikePos + Vector3.new(0, 140, 0)
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(225, 245, 255)
	bolt.Parent = Workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(235, 248, 255)
	light.Brightness = 15
	light.Range = 350
	light.Parent = bolt

	local thunder = Instance.new("Sound")
	thunder.SoundId = "rbxassetid://9114221580"
	thunder.Volume = 4
	thunder.Parent = bolt
	thunder:Play()

	Network.LightningStrike:FireAllClients(strikePos)

	task.delay(0.2, function()
		bolt:Destroy()
	end)
end

local lastPublish, lastWindUpdate, nextLightning = 0, 0, os.clock() + 10

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, storm in storms do
		if storm.Engine then
			storm.Engine:Step(dt)
		end

		if storm.Chasing and now >= storm.NextRetarget then
			storm.Target = chaseTarget(storm)
			storm.NextRetarget = now + RETARGET_SECONDS
		end

		local root = storm.Tornado.Root
		local offset = Vector3.new(storm.Target.X - root.Position.X, 0, storm.Target.Z - root.Position.Z)
		if offset.Magnitude < 15 then
			storm.Target = if storm.Chasing then chaseTarget(storm) else randomMapPoint()
		else
			root.CFrame = CFrame.new(root.Position + offset.Unit * math.min(storm.Speed * dt, offset.Magnitude))
		end
	end

	-- Radar updates 10 times a second; wind readings change once a second
	if now - lastPublish >= 0.1 then
		lastPublish = now
		local updateWind = now - lastWindUpdate >= 1
		if updateWind then
			lastWindUpdate = now
		end
		for _, storm in storms do
			storm.Info:SetAttribute("Position", storm.Tornado.Root.Position)
			if updateWind and storm.Engine then
				local params = TORNADO_TYPES[storm.Kind].Params
				storm.Info:SetAttribute("Wind", math.random(params.WindSpeedMin, params.WindSpeedMax))
			end
		end
	end

	if #storms > 0 and now >= nextLightning then
		nextLightning = now + math.random(6, 14)
		triggerLightning(storms[math.random(1, #storms)].Tornado.Root.Position)
	end
end)

-- Storm cycle
task.spawn(function()
	local timings = Config.Manager
	while true do
		setPhase("Forecast", timings.ForecastDuration)
		local minors = {}
		local minorCount = if math.random() < 0.35 then 2 else 1
		for _ = 1, minorCount do
			table.insert(minors, createStorm("Minor", randomPointAwayFromPlayers(MIN_SPAWN_DISTANCE)))
		end
		task.wait(timings.ForecastDuration)

		setPhase("Minor", timings.MinorTornadoDuration)
		for i, storm in minors do
			task.delay((i - 1) * math.random(4, 12), touchdown, storm)
		end
		task.wait(timings.MinorTornadoDuration)

		setPhase("FinalWarning", timings.FinalWarningDuration)
		for _, storm in minors do
			dissipate(storm)
		end
		local final = createStorm("Final", randomEdgePoint())
		final.Chasing = true
		task.wait(timings.FinalWarningDuration)

		setPhase("Final", timings.FinalTornadoDuration)
		touchdown(final)
		task.wait(timings.FinalTornadoDuration)

		setPhase("Intermission", timings.IntermissionDuration)
		dissipate(final)
		task.wait(timings.IntermissionDuration)
	end
end)

print("[TornadoManager] Storm cycle running.")
