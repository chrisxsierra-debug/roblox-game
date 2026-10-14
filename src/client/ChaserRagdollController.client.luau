--!strict
-- ChaserRagdollController.client.luau
-- Implements OnUserRagdollStarted and OnUserRagdollEnded directly matching Funnel Runners C++

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local CameraShaker = require(Packages:WaitForChild("CameraShaker"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")

local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCFrame)
	camera.CFrame = camera.CFrame * shakeCFrame
end)
camShake:Start()

local isRagdolled = false

-- Ragdoll Start (When captured by vortex)
Network.OnUserRagdollStarted.OnClientEvent:Connect(function()
	if isRagdolled then return end
	isRagdolled = true

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Ragdoll)
			hum.PlatformStand = true
		end
		-- Continuous violent tumble shake
		camShake:ShakeOnce(6, 15, 0.1, 3.5)
	end
end)

-- Target Tossed out of vortex
Network.OnTargetTossed.OnClientEvent:Connect(function(tossVelocity: Vector3)
	camShake:ShakeOnce(8, 20, 0, 1.2)
end)

-- Ragdoll Ended (Recover on feet)
Network.OnUserRagdollEnded.OnClientEvent:Connect(function()
	if not isRagdolled then return end
	isRagdolled = false

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end)

-- Lightning Strike Shake
Network.LightningStrike.OnClientEvent:Connect(function(pos: Vector3)
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
		if root then
			local dist = (pos - root.Position).Magnitude
			if dist < 220 then
				local intensity = math.clamp(1 - (dist / 220), 0.3, 1.0)
				camShake:ShakeOnce(7 * intensity, 16, 0, 0.9)
			end
		end
	end
end)

print("[Client] ChaserRagdollController initialized.")

