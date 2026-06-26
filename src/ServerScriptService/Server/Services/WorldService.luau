--!strict
-- WorldService — world generation + authored-map detection (§22).
-- TRACK C owns the visual generation; TRACK A owns nothing here but depends on
-- plots existing. STUB.
--
-- Responsibilities:
--   * Detect an authored Workspace/Map before generating placeholders (§22).
--   * If none, procedurally generate baseplate, spawn, GameConfig.PlotCount plots,
--     paths, signs, lighting — all anchored, in a clearly named folder.
--   * Never generate duplicates (idempotent).

local WorldService = {}
WorldService.Name = "WorldService"

function WorldService.Init()
	-- TODO(Track C): detect authored map, else generate placeholder world + plots.
end

function WorldService.Start() end

return WorldService
