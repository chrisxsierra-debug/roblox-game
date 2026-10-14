--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))

local lastScan = 0

local function bindTool(tool: Tool)
	local toolType = tool:GetAttribute("ToolType")

	tool.Activated:Connect(function()
		local char = player.Character
		if not char then return end

		if toolType == "DopplerRadar" then
			if os.clock() - lastScan > 2.0 then
				lastScan = os.clock()
				Network.DopplerScanRequest:FireServer()
			end
		elseif toolType == "Spotlight" then
			local handle = tool:FindFirstChild("Handle")
			local light = handle and handle:FindFirstChildOfClass("SpotLight")
			if light then
				light.Enabled = not light.Enabled
			end
		end
	end)
end

player.CharacterAdded:Connect(function(char)
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			bindTool(child)
		end
	end)
end)

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		bindTool(child)
	end
end)

for _, child in backpack:GetChildren() do
	if child:IsA("Tool") then
		bindTool(child)
	end
end

print("[Client] GadgetController bound to Portable Doppler and Spotlight.")
