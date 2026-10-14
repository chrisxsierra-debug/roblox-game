--!strict
-- RankineVortexEngine.luau
-- Implements the authentic Rankine Combined Vortex model from Roblox DevForum storm chaser physics
-- Splits the vortex into Solid-Body Inner Core rotation and Free Vortex Outer Suction

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

export type RankineConfig = {
	CoreRadius: number,       -- Solid rotation inner core radius
	MaxRadius: number,        -- Outer reach of the suction field
	MaxTangentialSpeed: number,-- Peak rotational speed at core edge
	InwardPullForce: number,  -- Inward vector suction towards center
	UpwardLift: number,       -- Updraft vertical velocity factor
	CoreHeight: number,       -- Maximum height of the funnel
	DamagePerSecond: number,  -- Core shredding damage
}

local RankineVortexEngine = {}
RankineVortexEngine.__index = RankineVortexEngine

function RankineVortexEngine.new(vortexRoot: BasePart)
	local self = setmetatable({}, RankineVortexEngine)
	self.VortexRoot = vortexRoot
	self.Config = {
		CoreRadius = 35,          -- Massive EF5 Wedge Core
		MaxRadius = 150,         -- 150 studs suction boundary
		MaxTangentialSpeed = 160, -- 160 studs/sec rotational speed
		InwardPullForce = 85,    -- Strong suction pull
		UpwardLift = 130,        -- Updraft lift
		CoreHeight = 220,
		DamagePerSecond = 50,
	} :: RankineConfig

	self.BlockageZones = {} :: { BasePart }
	self.LastDamageTime = 0
	return self
end

function RankineVortexEngine:AddBlockage(part: BasePart)
	table.insert(self.BlockageZones, part)
end

function RankineVortexEngine:IsBlocked(pos: Vector3): boolean
	for _, zone in self.BlockageZones do
		if zone and zone.Parent then
			local localPos = zone.CFrame:PointToObjectSpace(pos)
			local half = zone.Size / 2
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Calculate Rankine Vortex velocity vector at position (x, y, z)
function RankineVortexEngine:GetVortexVelocityAt(pos: Vector3): (Vector3, number, boolean)
	local center = self.VortexRoot.Position
	local displacement = pos - center
	local distXZ = Vector3.new(displacement.X, 0, displacement.Z).Magnitude

	if distXZ > self.Config.MaxRadius or distXZ < 1 then
		return Vector3.zero, distXZ, false
	end

	local dirXZ = Vector3.new(displacement.X, 0, displacement.Z).Unit
	local tangentXZ = Vector3.new(-dirXZ.Z, 0, dirXZ.X) -- Perpendicular tangential direction

	local tangentialSpeed = 0
	local radialPull = 0

	if distXZ < self.Config.CoreRadius then
		-- Inner Core: Solid body rotation (V increases linearly toward core edge)
		local ratio = (distXZ / self.Config.CoreRadius)
		tangentialSpeed = self.Config.MaxTangentialSpeed * ratio
		radialPull = -self.Config.InwardPullForce * 1.3
	else
		-- Outer Vortex: Free vortex (V decays with 1/r)
		local ratio = (self.Config.CoreRadius / distXZ)
		tangentialSpeed = self.Config.MaxTangentialSpeed * ratio
		radialPull = -self.Config.InwardPullForce * ratio
	end

	-- Upward Updraft component (strongest near core, decaying with height)
	local relY = math.clamp(pos.Y - center.Y, 0, self.Config.CoreHeight)
	local heightFactor = math.clamp(1 - (relY / self.Config.CoreHeight), 0.1, 1)
	local coreProximity = math.clamp(1 - (distXZ / self.Config.MaxRadius), 0, 1)
	local upwardSpeed = self.Config.UpwardLift * heightFactor * coreProximity

	local vortexVel = (tangentXZ * tangentialSpeed) + (dirXZ * radialPull) + Vector3.new(0, upwardSpeed, 0)
	local inCore = (distXZ <= self.Config.CoreRadius * 1.1)

	return vortexVel, distXZ, inCore
end

-- Physics Heartbeat Step
function RankineVortexEngine:Step(dt: number)
	local center = self.VortexRoot.Position

	-- 1. Apply Rankine Vortex forces to Players
	for _, player in Players:GetPlayers() do
		local char = player.Character
		if char and char:GetAttribute("IsSheltered") ~= true then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
			local hum = char:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 and not self:IsBlocked(root.Position) then
				local targetVel, dist, inCore = self:GetVortexVelocityAt(root.Position)
				if dist <= self.Config.MaxRadius then
					-- Apply organic impulse force
					local curVel = root.AssemblyLinearVelocity
					local velDiff = (targetVel - curVel)
					root.AssemblyLinearVelocity = curVel + (velDiff * math.clamp(dt * 3.5, 0, 1))

					-- Core damage & ragdoll
					if inCore then
						Network.OnUserRagdollStarted:FireClient(player)
						hum:TakeDamage(self.Config.DamagePerSecond * dt)
					end
				end
			end
		end
	end

	-- 2. Apply Rankine Vortex forces to Physical Debris & Destructible Parts
	for _, part in CollectionService:GetTagged("TornadoDebris") do
		if part:IsA("BasePart") and not part.Anchored and part.AssemblyMass < 8000 then
			local targetVel, dist = self:GetVortexVelocityAt(part.Position)
			if dist <= self.Config.MaxRadius then
				local curVel = part.AssemblyLinearVelocity
				local velDiff = (targetVel - curVel)
				part.AssemblyLinearVelocity = curVel + (velDiff * math.clamp(dt * 4, 0, 1))
				part.AssemblyAngularVelocity = Vector3.new(math.random(-15, 15), 25, math.random(-15, 15))
			end
		end
	end

	-- 3. Tear building planks off structures
	for _, plank in CollectionService:GetTagged("DestructibleStructure") do
		if plank:IsA("BasePart") and plank.Anchored then
			local d = (plank.Position - center).Magnitude
			if d <= self.Config.CoreRadius * 1.8 then
				plank.Anchored = false
				plank.CanCollide = true
				CollectionService:RemoveTag(plank, "DestructibleStructure")
				CollectionService:AddTag(plank, "TornadoDebris")
				plank.AssemblyLinearVelocity = Vector3.new(math.random(-40, 40), 60, math.random(-40, 40))
			end
		end
	end
end

return RankineVortexEngine

