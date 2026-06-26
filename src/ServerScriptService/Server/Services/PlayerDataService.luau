--!strict
-- PlayerDataService — DataStore load/save + session cache (§13, §14).
-- TRACK A owns this. This is a STUB: interfaces are locked; bodies are TODO.
--
-- Non-negotiable safety rules to implement (§14):
--   * UpdateAsync + pcall + exponential backoff, MaxDataStoreRetries.
--   * Failed-load guard: if load fails after all retries, mark the session
--     load-failed, show a friendly error, BLOCK gameplay, kick safely, and
--     NEVER save over it.
--   * Default-profile reconciliation (use TableUtility.reconcile).
--   * Schema migration (include an example v0 -> v1).
--   * Autosave every GameConfig.AutosaveIntervalSeconds, on PlayerRemoving,
--     and on BindToClose. Save after rebirth.
--   * Sanitize/clamp malformed numbers; repair duplicate slots; prune receipts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Types = require(Shared:WaitForChild("Types"))

local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService"

-- userId -> PlayerData (only present once successfully loaded)
local sessions: { [number]: Types.PlayerData } = {}
-- userId -> true while a load is in flight or has failed (blocks gameplay)
local loadFailed: { [number]: boolean } = {}

-- Returns the canonical default profile for a brand-new player (§13).
function PlayerDataService.getDefaultProfile(): Types.PlayerData
	-- TODO(Track A): build from EconomyConfig starting values.
	return {
		DataVersion = GameConfig.DataVersion,
		Coins = 20,
		LifetimeCoins = 0,
		Rebirths = 0,
		UnlockedSlots = 2,
		HighestSeedTier = 1,
		Slots = {},
		Tutorial = { Completed = false, Step = 0 },
		Statistics = {
			TotalPlanted = 0,
			TotalHarvested = 0,
			TotalCoinsEarned = 0,
			HighestMutationRank = 0,
			PlaySeconds = 0,
		},
		Settings = { MusicVolume = 0.5, SoundVolume = 0.5, ReducedEffects = false },
		Purchases = { ProcessedReceipts = {} },
		FertilizerCharges = 0,
		LastSeenAt = 0,
	}
end

-- Returns the live session data for a player, or nil if not loaded / load-failed.
function PlayerDataService.get(userId: number): Types.PlayerData?
	if loadFailed[userId] then
		return nil
	end
	return sessions[userId]
end

function PlayerDataService.isLoaded(userId: number): boolean
	return sessions[userId] ~= nil and not loadFailed[userId]
end

-- TODO(Track A): implement load with retry + failed-load guard.
function PlayerDataService.load(_player: Player) end

-- TODO(Track A): implement save (UpdateAsync, backoff). `reason` is for logging.
function PlayerDataService.save(_player: Player, _reason: string?) end

-- TODO(Track A): example migration from DataVersion 0 to 1.
function PlayerDataService.migrate(data: any): Types.PlayerData
	return data
end

function PlayerDataService.Init()
	-- TODO(Track A): wire PlayerAdded -> load, PlayerRemoving -> save,
	-- BindToClose -> save all, and the autosave loop.
	Players.PlayerAdded:Connect(function(_player) end)
	Players.PlayerRemoving:Connect(function(_player) end)
end

function PlayerDataService.Start() end

return PlayerDataService
