--!strict
-- FunnelRunnersNetwork.luau
-- Mirrors replicated signatures from ATornadoManager, ADopplerRadar, and UTornadoOrbitComponent

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local folder = ReplicatedStorage:FindFirstChild("FR_Remotes")
if not folder then
	if RunService:IsServer() then
		folder = Instance.new("Folder")
		folder.Name = "FR_Remotes"
		folder.Parent = ReplicatedStorage
	else
		folder = ReplicatedStorage:WaitForChild("FR_Remotes", 10) :: Folder
	end
end

local function getRemote(name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		else
			remote = folder:WaitForChild(name, 10) :: RemoteEvent
		end
	end
	return remote :: RemoteEvent
end

local FunnelRunnersNetwork = {
	-- ATornadoManager lifecycle events
	OnTornadoStateChanged = getRemote("OnTornadoStateChanged"),
	OnFinalTornadoArrival = getRemote("OnFinalTornadoArrival"),
	OnFinalTornadoArrived = getRemote("OnFinalTornadoArrived"),
	
	-- ADopplerRadar live stream
	DopplerTelemetry = getRemote("DopplerTelemetry"),
	DopplerScanRequest = getRemote("DopplerScanRequest"),
	DopplerScanResult = getRemote("DopplerScanResult"),

	-- UTornadoSuctionComponent & UTornadoOrbitComponent
	OnUserRagdollStarted = getRemote("OnUserRagdollStarted"),
	OnUserRagdollEnded = getRemote("OnUserRagdollEnded"),
	OnTargetTossed = getRemote("OnTargetTossed"),

	-- Environment & Survival
	LightningStrike = getRemote("LightningStrike"),
	BunkerShelterState = getRemote("BunkerShelterState"),
	SirenState = getRemote("SirenState"),
}

return FunnelRunnersNetwork

