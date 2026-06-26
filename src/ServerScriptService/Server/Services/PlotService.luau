--!strict
-- PlotService — plot ownership + assignment (§11).
-- TRACK A owns the ownership/assignment LOGIC; TRACK C owns the visual plot
-- building (WorldService / PlotFactory).
--
-- Responsibilities (§11):
--   * One plot per player, one owner per plot, server-authoritative.
--   * Assign first free plot on join (after data loads); build its visuals via World.
--   * Validate plot ownership on EVERY farm request.
--   * Clear transient visuals on leave; never delete persistent data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Constants = require(Shared:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local PlayerDataService = require(Server:WaitForChild("Services"):WaitForChild("PlayerDataService"))

-- WorldService (Track C) — we only CALL it; do not implement it here.
local WorldService = require(Server:WaitForChild("Services"):WaitForChild("WorldService"))

local PlotService = {}
PlotService.Name = "PlotService"

-- userId -> assigned plotId (nil if none)
local assignments: { [number]: number } = {}
-- plotId -> userId (the inverse, for one-owner-per-plot enforcement)
local plotOwners: { [number]: number } = {}

function PlotService.getPlotId(userId: number): number?
	return assignments[userId]
end

-- First plotId in 1..PlotCount not currently owned, or nil if the server is full.
local function firstFreePlot(): number?
	for plotId = 1, GameConfig.PlotCount do
		if plotOwners[plotId] == nil then
			return plotId
		end
	end
	return nil
end

-- True if `userId` owns a plot AND `slotIndex` is within their unlocked slots.
function PlotService.ownsSlot(userId: number, slotIndex: number): boolean
	if assignments[userId] == nil then
		return false
	end
	local data = PlayerDataService.get(userId)
	if not data then
		return false
	end
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
		return false
	end
	return slotIndex >= 1 and slotIndex <= data.UnlockedSlots
end

-- Assign a plot to a player and ask the World to build/rebuild its visuals.
function PlotService.assign(player: Player)
	local userId = player.UserId
	if assignments[userId] then
		return -- already assigned (idempotent)
	end

	local plotId = firstFreePlot()
	if not plotId then
		warn(`[PlotService] no free plot for {player.Name}`)
		Remotes.Events[Constants.Remotes.Notification]:FireClient(
			player,
			"All farms are full on this server.",
			2
		)
		return
	end

	assignments[userId] = plotId
	plotOwners[plotId] = userId
	-- Stamp the plot id into the transient cache so DataSnapshot.PlotId is populated
	-- (the client scopes 3D slot/effect lookups by it). Mirrors the passes pattern.
	PlayerDataService.setPlotId(userId, plotId)

	-- Track C builds the 3D plot (PlotService decides WHO, WorldService builds visuals).
	local ok, err = pcall(function()
		(WorldService :: any).buildPlotFor(player, plotId)
	end)
	if not ok then
		warn(`[PlotService] WorldService.buildPlotFor failed for {player.Name}: {err}`)
	end

	-- Tell the client which plot is theirs so it can locate slots in Workspace (§4).
	Remotes.Events[Constants.Remotes.FarmAssigned]:FireClient(player, plotId)
end

local function release(player: Player)
	local userId = player.UserId
	local plotId = assignments[userId]
	if plotId then
		plotOwners[plotId] = nil
		assignments[userId] = nil
		-- Visuals only — never touch persistent data. Track C clears the plot's
		-- transient creature models + resets owner attributes (§11).
		pcall(function()
			WorldService.clearPlot(plotId)
		end)
	end
end

local function onPlayerAdded(player: Player)
	-- Wait for data before assigning (contract §1/§3). nil => load failed → no-op.
	local data = PlayerDataService.waitForData(player)
	if not data then
		return
	end
	if player.Parent ~= Players then
		return
	end
	PlotService.assign(player)
	-- Send the initial full snapshot now that the player has a plot.
	PlayerDataService.replicate(player)
end

function PlotService.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(release)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function PlotService.Start() end

return PlotService
