--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))
local Config = require(Shared:WaitForChild("FunnelRunnersConfig"))

local function createDopplerRadarTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Portable Doppler Radar"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.6, 2.2, 0.8)
	handle.Color = Color3.fromRGB(45, 55, 65)
	handle.Material = Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool

	-- Screen part
	local screen = Instance.new("Part")
	screen.Name = "Screen"
	screen.Size = Vector3.new(1.3, 1.2, 0.1)
	screen.Color = Color3.fromRGB(0, 240, 160)
	screen.Material = Enum.Material.Neon
	screen.CanCollide = false
	screen.CFrame = handle.CFrame * CFrame.new(0, 0.2, -0.45)
	screen.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = screen
	weld.Parent = handle

	tool:SetAttribute("ToolType", "DopplerRadar")
	return tool
end

local function createSpotlightTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "High-Beam Storm Spotlight"
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 0.8, 2.4)
	handle.Color = Color3.fromRGB(230, 190, 30)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Parent = tool

	local light = Instance.new("SpotLight")
	light.Name = "Beam"
	light.Brightness = 8
	light.Range = 140
	light.Angle = 55
	light.Color = Color3.fromRGB(255, 255, 240)
	light.Face = Enum.NormalId.Front
	light.Shadows = true
	light.Parent = handle

	tool:SetAttribute("ToolType", "Spotlight")
	return tool
end

local function onCharacterAdded(char: Model, player: Player)
	local backpack = player:WaitForChild("Backpack")
	createDopplerRadarTool().Parent = backpack
	createSpotlightTool().Parent = backpack
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(char, player)
	end)
	if player.Character then
		onCharacterAdded(player.Character, player)
	end
end)

for _, p in Players:GetPlayers() do
	if p.Character then
		onCharacterAdded(p.Character, p)
	end
end

-- Handle Radar Scanning from Client
Network.DopplerScanRequest.OnServerEvent:Connect(function(player: Player)
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart
	if not root then return end

	-- Scan the nearest tornado that is on the ground (TornadoManager tags and flags them)
	local vortexRoot: BasePart? = nil
	for _, tagged in CollectionService:GetTagged("TornadoVortex") do
		if tagged:IsA("BasePart") and tagged:GetAttribute("TouchedDown") then
			if not vortexRoot or (tagged.Position - root.Position).Magnitude < (vortexRoot.Position - root.Position).Magnitude then
				vortexRoot = tagged
			end
		end
	end

	if not vortexRoot then
		Network.DopplerScanResult:FireClient(player, 0, -1, false) -- nothing on the ground to scan
	else
		local dist = (vortexRoot.Position - root.Position).Magnitude
		if dist <= Config.Doppler.MaxScanDistance then
			-- Proximity multiplier: Closer to eye = massive bonus tokens!
			local dangerBonus = math.clamp(math.floor((1 - (dist / Config.Doppler.MaxScanDistance)) * 75), 10, 100)
			local totalTokens = Config.Doppler.BaseResearchTokens + dangerBonus

			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local tokensVal = leaderstats:FindFirstChild("Tokens") :: IntValue
				if tokensVal then tokensVal.Value += totalTokens end
			end

			Network.DopplerScanResult:FireClient(player, totalTokens, dist, true)
		else
			Network.DopplerScanResult:FireClient(player, 0, dist, false)
		end
	end
end)

print("[StormGadgetService] Portable Doppler and Spotlight loadout active.")
