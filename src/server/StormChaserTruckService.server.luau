--!strict
-- StormChaserTruckService.server.luau
-- Spawns a fully drivable Storm Chaser Scout Truck using Roblox VehicleSeat & physics constraints

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local function buildDrivableChaserTruck(spawnCFrame: CFrame): Model
	local truck = Instance.new("Model")
	truck.Name = "StormChaserTruck"

	-- Main Chassis
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(9, 3, 18)
	chassis.CFrame = spawnCFrame * CFrame.new(0, 3.5, 0)
	chassis.Color = Color3.fromRGB(35, 42, 50)
	chassis.Material = Enum.Material.Metal
	chassis.CustomPhysicalProperties = PhysicalProperties.new(1.8, 0.4, 0, 100, 100) -- Heavy storm armor
	chassis.CanCollide = true
	chassis.Parent = truck
	truck.PrimaryPart = chassis

	-- Cab & Windshield
	local cab = Instance.new("Part")
	cab.Name = "Cab"
	cab.Size = Vector3.new(8.5, 4, 10)
	cab.CFrame = chassis.CFrame * CFrame.new(0, 3.5, -2)
	cab.Color = Color3.fromRGB(40, 48, 58)
	cab.Material = Enum.Material.Metal
	cab.CanCollide = false
	cab.Parent = truck

	local weldCab = Instance.new("WeldConstraint")
	weldCab.Part0 = chassis
	weldCab.Part1 = cab
	weldCab.Parent = chassis

	-- Windshield Armor Grate
	local grate = Instance.new("Part")
	grate.Name = "ArmorGrate"
	grate.Size = Vector3.new(8.2, 3, 0.5)
	grate.CFrame = cab.CFrame * CFrame.new(0, 0.5, -5.2)
	grate.Color = Color3.fromRGB(80, 80, 85)
	grate.Material = Enum.Material.DiamondPlate
	grate.CanCollide = false
	grate.Parent = truck

	local weldGrate = Instance.new("WeldConstraint")
	weldGrate.Part0 = chassis
	weldGrate.Part1 = grate
	weldGrate.Parent = chassis

	-- Driver's VehicleSeat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.5, 1, 2.5)
	seat.CFrame = cab.CFrame * CFrame.new(-2, 0.2, -1)
	seat.MaxSpeed = 75
	seat.Torque = 40
	seat.TurnSpeed = 1.8
	seat.SteerFloat = 0
	seat.ThrottleFloat = 0
	seat.Parent = truck

	local weldSeat = Instance.new("WeldConstraint")
	weldSeat.Part0 = chassis
	weldSeat.Part1 = seat
	weldSeat.Parent = chassis

	-- Passenger Seat
	local pSeat = Instance.new("Seat")
	pSeat.Name = "PassengerSeat"
	pSeat.Size = Vector3.new(2.5, 1, 2.5)
	pSeat.CFrame = cab.CFrame * CFrame.new(2, 0.2, -1)
	pSeat.Parent = truck

	local weldPSeat = Instance.new("WeldConstraint")
	weldPSeat.Part0 = chassis
	weldPSeat.Part1 = pSeat
	weldPSeat.Parent = chassis

	-- Headlights
	for _, xOffset in { -3.2, 3.2 } do
		local lightPart = Instance.new("Part")
		lightPart.Size = Vector3.new(1.2, 1, 0.5)
		lightPart.CFrame = chassis.CFrame * CFrame.new(xOffset, 0.5, -9.2)
		lightPart.Color = Color3.fromRGB(255, 255, 240)
		lightPart.Material = Enum.Material.Neon
		lightPart.CanCollide = false
		lightPart.Parent = truck

		local spot = Instance.new("SpotLight")
		spot.Brightness = 8
		spot.Range = 160
		spot.Angle = 60
		spot.Color = Color3.fromRGB(255, 255, 230)
		spot.Face = Enum.NormalId.Front
		spot.Shadows = true
		spot.Parent = lightPart

		local weldL = Instance.new("WeldConstraint")
		weldL.Part0 = chassis
		weldL.Part1 = lightPart
		weldL.Parent = chassis
	end

	-- Roof Amber Emergency Lightbar
	local lightbar = Instance.new("Part")
	lightbar.Name = "EmergencyLightbar"
	lightbar.Size = Vector3.new(6.5, 0.8, 1.4)
	lightbar.CFrame = cab.CFrame * CFrame.new(0, 2.4, 0)
	lightbar.Color = Color3.fromRGB(255, 160, 20)
	lightbar.Material = Enum.Material.Neon
	lightbar.CanCollide = false
	lightbar.Parent = truck

	local weldBar = Instance.new("WeldConstraint")
	weldBar.Part0 = cab
	weldBar.Part1 = lightbar
	weldBar.Parent = cab

	local beacon = Instance.new("PointLight")
	beacon.Color = Color3.fromRGB(255, 160, 20)
	beacon.Brightness = 5
	beacon.Range = 35
	beacon.Parent = lightbar

	-- Engine Audio Loop
	local engineSound = Instance.new("Sound")
	engineSound.Name = "EngineSound"
	engineSound.SoundId = "rbxassetid://9114221160" -- Heavy diesel engine
	engineSound.Volume = 0.8
	engineSound.Looped = true
	engineSound.PlaybackSpeed = 0.8
	engineSound.Parent = chassis
	engineSound:Play()

	-- 4 Wheels with Physics Suspension
	local wheelOffsets = {
		{ Name = "FL", Pos = Vector3.new(-5.2, -1.2, -5.5), IsFront = true },
		{ Name = "FR", Pos = Vector3.new(5.2, -1.2, -5.5),  IsFront = true },
		{ Name = "RL", Pos = Vector3.new(-5.2, -1.2, 5.5),   IsFront = false },
		{ Name = "RR", Pos = Vector3.new(5.2, -1.2, 5.5),   IsFront = false },
	}

	local wheels = {}

	for _, w in wheelOffsets do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel_" .. w.Name
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(2.4, 3.8, 3.8)
		wheel.CFrame = (chassis.CFrame * CFrame.new(w.Pos)) * CFrame.Angles(0, 0, math.rad(90))
		wheel.Color = Color3.fromRGB(25, 25, 28)
		wheel.Material = Enum.Material.Rubber
		wheel.CustomPhysicalProperties = PhysicalProperties.new(1.2, 1.5, 0, 100, 100) -- High grip tire friction
		wheel.CanCollide = true
		wheel.Parent = truck

		local weldW = Instance.new("WeldConstraint")
		weldW.Part0 = chassis
		weldW.Part1 = wheel
		weldW.Parent = chassis

		table.insert(wheels, { Part = wheel, IsFront = w.IsFront })
	end

	-- Simple Reliable BodyVelocity/AngularVelocity Driving Physics Loop
	local linearVel = Instance.new("LinearVelocity")
	linearVel.MaxForce = 120000
	linearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	linearVel.LineDirection = Vector3.new(0, 0, -1)
	linearVel.LineVelocity = 0

	local att = Instance.new("Attachment")
	att.Parent = chassis
	linearVel.Attachment0 = att
	linearVel.Parent = chassis

	local angularVel = Instance.new("AngularVelocity")
	angularVel.MaxTorque = 90000
	angularVel.AngularVelocity = Vector3.zero
	angularVel.Attachment0 = att
	angularVel.Parent = chassis

	-- Nitrous Exhaust Emitters
	local nitroEmitters = {}
	for _, xOffset in { -2.5, 2.5 } do
		local pipe = Instance.new("Part")
		pipe.Name = "ExhaustPipe"
		pipe.Size = Vector3.new(0.6, 0.6, 1.2)
		pipe.CFrame = chassis.CFrame * CFrame.new(xOffset, -1, 9.2)
		pipe.Color = Color3.fromRGB(50, 50, 55)
		pipe.Material = Enum.Material.Metal
		pipe.CanCollide = false
		pipe.Parent = truck

		local weldPipe = Instance.new("WeldConstraint")
		weldPipe.Part0 = chassis
		weldPipe.Part1 = pipe
		weldPipe.Parent = chassis

		local flame = Instance.new("ParticleEmitter")
		flame.Texture = "rbxasset://textures/particles/fire_main.dds"
		flame.Color = ColorSequence.new(Color3.fromRGB(0, 180, 255), Color3.fromRGB(255, 255, 255))
		flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0.1) })
		flame.Lifetime = NumberRange.new(0.15, 0.3)
		flame.Speed = NumberRange.new(20, 35)
		flame.Rate = 0
		flame.EmissionDirection = Enum.NormalId.Back
		flame.Parent = pipe
		table.insert(nitroEmitters, flame)
	end

	-- Nitro & Anchor state attributes
	truck:SetAttribute("NitroActive", false)
	truck:SetAttribute("AnchoredSpikes", false)
	truck:SetAttribute("LastNitro", 0)

	-- Connect Driver Input
	RunService.Heartbeat:Connect(function(dt)
		if not truck.Parent then return end

		local isAnchored = truck:GetAttribute("AnchoredSpikes") == true
		if isAnchored then
			chassis.Anchored = true
			linearVel.LineVelocity = 0
			angularVel.AngularVelocity = Vector3.zero
			return
		else
			chassis.Anchored = false
		end

		local throttle = seat.ThrottleFloat
		local steer = seat.SteerFloat
		local isNitro = truck:GetAttribute("NitroActive") == true

		local topSpeed = isNitro and 115 or 65
		linearVel.LineDirection = chassis.CFrame.LookVector
		linearVel.LineVelocity = -throttle * topSpeed

		angularVel.AngularVelocity = Vector3.new(0, -steer * (isNitro and 1.5 or 2.2), 0)

		-- Engine Sound dynamic pitch
		if isNitro then
			engineSound.PlaybackSpeed = 1.6
			engineSound.Volume = 1.8
		elseif math.abs(throttle) > 0.05 then
			engineSound.PlaybackSpeed = 0.9 + math.abs(throttle) * 0.6
			engineSound.Volume = 1.4
		else
			engineSound.PlaybackSpeed = 0.75
			engineSound.Volume = 0.5
		end

		-- Flashing lightbar
		beacon.Brightness = (math.sin(os.clock() * 8) > 0) and 6 or 1
	end)

	truck.Parent = Workspace
	return truck
end

-- Network Listeners for Nitro & Anchors
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

Network.TruckNitroRequest.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.SeatPart or humanoid.SeatPart.Name ~= "DriverSeat" then return end

	local truck = humanoid.SeatPart.Parent :: Model?
	if not truck then return end

	local now = os.clock()
	local lastNitro = truck:GetAttribute("LastNitro") or 0
	if now - lastNitro < 9 then return end -- Cooldown

	truck:SetAttribute("LastNitro", now)
	truck:SetAttribute("NitroActive", true)

	for _, pipe in truck:GetChildren() do
		if pipe.Name == "ExhaustPipe" then
			local flame = pipe:FindFirstChildOfClass("ParticleEmitter")
			if flame then flame.Rate = 90 end
		end
	end

	task.delay(3.5, function()
		if truck and truck.Parent then
			truck:SetAttribute("NitroActive", false)
			for _, pipe in truck:GetChildren() do
				if pipe.Name == "ExhaustPipe" then
					local flame = pipe:FindFirstChildOfClass("ParticleEmitter")
					if flame then flame.Rate = 0 end
				end
			end
		end
	end)
end)

Network.TruckAnchorRequest.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or not humanoid.SeatPart or humanoid.SeatPart.Name ~= "DriverSeat" then return end

	local truck = humanoid.SeatPart.Parent :: Model?
	if not truck then return end

	local currentlyAnchored = truck:GetAttribute("AnchoredSpikes") == true
	truck:SetAttribute("AnchoredSpikes", not currentlyAnchored)
end)

-- Spawn dual trucks parked side-by-side for you and your friend!
task.defer(function()
	local truckPos1 = CFrame.new(12, 1.5, 95) * CFrame.Angles(0, math.rad(180), 0)
	local truckPos2 = CFrame.new(-12, 1.5, 95) * CFrame.Angles(0, math.rad(180), 0)

	local t1 = buildDrivableChaserTruck(truckPos1)
	t1.Name = "StormChaserTruck_Alpha"

	local t2 = buildDrivableChaserTruck(truckPos2)
	t2.Name = "StormChaserTruck_Bravo"

	print("[StormChaserTruckService] Dual Storm Chaser Trucks (Alpha & Bravo) spawned on highway.")
end)

