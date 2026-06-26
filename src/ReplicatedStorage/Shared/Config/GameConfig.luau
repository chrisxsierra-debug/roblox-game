--!strict
-- GameConfig — high-level, non-economy game settings.
-- Dependency-free so it can be required anywhere (and Lune-loaded for tests).

local GameConfig = {}

GameConfig.GameName = "Brainrot Farm: Grow & Raid"
GameConfig.Tagline = "Plant Something Dumb. Grow Something Huge."

-- DataStore versioning (§14). The live store name is composed from these.
GameConfig.DataVersion = 1
GameConfig.DataStoreScope = "BrainrotFarm"
-- When true, use a separate development store so test data never touches production.
GameConfig.UseDevelopmentDataStore = true
GameConfig.ProductionDataStoreName = "PlayerData_v1"
GameConfig.DevelopmentDataStoreName = "PlayerData_DEV_v1"

-- Server / plot sizing (§11)
GameConfig.MaxPlayersPerServer = 8
GameConfig.PlotCount = 8

-- Autosave / persistence (§14)
GameConfig.AutosaveIntervalSeconds = 60
GameConfig.MaxDataStoreRetries = 5

-- Auto-Collect (§23) — central interval, NOT per-crop polling (§29)
GameConfig.AutoCollectIntervalSeconds = 5

-- Number of visible growth stages (§9): Egg, Sprout, Awkward, Full
GameConfig.GrowthStageCount = 4

-- Returns the DataStore name to use given the current build flag.
function GameConfig.getDataStoreName(): string
	if GameConfig.UseDevelopmentDataStore then
		return GameConfig.DevelopmentDataStoreName
	end
	return GameConfig.ProductionDataStoreName
end

return GameConfig
