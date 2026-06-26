--!strict
-- Remotes — central RemoteEvent/RemoteFunction registry (§16).
--
-- Requiring this module returns a table:
--   Remotes.Events[name]    -> RemoteEvent
--   Remotes.Functions[name] -> RemoteFunction
--
-- On the SERVER it creates the instances (once); on the CLIENT it waits for them.
-- This keeps the client/server contract in one place and avoids per-slot remotes (§29).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local Remotes = {
	Events = {} :: { [string]: RemoteEvent },
	Functions = {} :: { [string]: RemoteFunction },
}

local isServer = RunService:IsServer()
local FOLDER_NAME = "Net"

local function getFolder(): Folder
	if isServer then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

local function ensureEvent(folder: Folder, name: string): RemoteEvent
	if isServer then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

local function ensureFunction(folder: Folder, name: string): RemoteFunction
	if isServer then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			return existing
		end
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteFunction
end

local folder = getFolder()

for _, name in Constants.ClientToServerEvents do
	Remotes.Events[name] = ensureEvent(folder, name)
end
for _, name in Constants.ServerToClientEvents do
	Remotes.Events[name] = ensureEvent(folder, name)
end
for _, name in Constants.RemoteFunctions do
	Remotes.Functions[name] = ensureFunction(folder, name)
end

return Remotes
