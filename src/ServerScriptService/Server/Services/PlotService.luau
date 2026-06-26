--!strict
-- PlotService — plot ownership + assignment (§11).
-- TRACK A owns the ownership/assignment LOGIC; TRACK C owns the visual plot
-- building (PlotFactory). STUB.
--
-- Responsibilities (§11):
--   * One plot per player, one owner per plot, server-authoritative.
--   * Assign first free plot on join; teleport the player there.
--   * Rebuild the player's farm visuals from saved data.
--   * Validate plot ownership on EVERY farm request.
--   * Clear transient models on leave; never delete persistent data.

local PlotService = {}
PlotService.Name = "PlotService"

-- userId -> assigned plotId (nil if none)
local assignments: { [number]: number } = {}

function PlotService.getPlotId(userId: number): number?
	return assignments[userId]
end

-- TODO(Track A): true if `userId` owns the plot containing this slot request.
function PlotService.ownsSlot(_userId: number, _slotIndex: number): boolean
	return false
end

function PlotService.Init() end
function PlotService.Start() end

return PlotService
