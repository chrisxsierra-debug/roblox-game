--!strict
-- TornadoManager.server.luau
-- Manages the Massive EF5 Wedge Tornado using the DevForum Rankine Combined Vortex Engine

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

local worldFolder = Workspace:WaitForChild("FunnelRunnersWorld", 15)
local vortexModel = worldFolder:WaitForChild("FunnelRunnersVortex", 10)
local vortexRoot = vortexModel:WaitForChild("VortexRoot", 10) :: BasePart

local rankineVortex = RankineEngine.new(vortexRoot)

-- Connect Bunker Safe Blockage
local function registerBunker()
	for _, zone in CollectionService:GetTagged("StormBunker") do
		if zone:IsA("BasePart") then
			rankineVortex:AddBlockage(zone)
		end
	end
end
task.defer(registerBunker)

-- Waypoints that parade the EF5 Wedge directly down the highway and past the farmhouse!
local waypoints = {
	Vector3.new(0, 2, -60),   -- In plain view right down the highway
	Vector3.new(-65, 2, -20), -- Hits the Destructible Farmhouse directly!
	Vector3.new(0, 2, 30),    -- Passes right over the Underground Bunker!
	Vector3.new(20, 2, 90),   -- Sweeps near the highway poles
	Vector3.new(-25, 2, -100),
}
local currentWpIndex = 1

-- Lightning System
local lastLightningTime = os.clock()
local function triggerLightning()
	local strikePos = vortexRoot.Position + Vector3.new(math.random(-80, 80), 0, math.random(-80, 80))

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

-- Physics & Movement Tick on Every Heartbeat
RunService.Heartbeat:Connect(function(dt)
	-- 1. Step Rankine Vortex Engine (Solid-Body core rotation, outer free vortex suction, updraft lift, house destruction)
	rankineVortex:Step(dt)

	-- 2. Move Wedge Tornado along highway
	local targetWp = waypoints[currentWpIndex]
	local dir = (targetWp - vortexRoot.Position)
	local dist = dir.Magnitude

	if dist < 15 then
		currentWpIndex = (currentWpIndex % #waypoints) + 1
	else
		-- Sweeps menacingly at 16 studs/sec
		vortexRoot.CFrame = CFrame.new(vortexRoot.Position + dir.Unit * (16 * dt))
	end

	-- 3. Random Lightning
	if os.clock() - lastLightningTime > math.random(8, 15) then
		lastLightningTime = os.clock()
		triggerLightning()
	end

	-- 4. Stream Live Doppler Telemetry to all Clients
	local wind = math.random(215, 285)
	Network.DopplerTelemetry:FireAllClients(vortexRoot.Position, "EF5", wind, "MONSTER EF5 WEDGE TORNADO", true)
end)

-- Broadcast touchdown immediately on start!
task.defer(function()
	Network.SirenState:FireAllClients(true)
	Network.OnFinalTornadoArrived:FireAllClients("🚨 MONSTER EF5 WEDGE TORNADO ACTIVE ON HIGHWAY!")
end)

print("[TornadoManager] Rankine Vortex Wedge Tornado active on highway.")
