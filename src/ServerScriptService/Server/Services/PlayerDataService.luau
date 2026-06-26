--!strict
-- PlayerDataService — DataStore load/save + session cache (§13, §14).
-- TRACK A owns this. Sole owner of the in-memory session cache: every other
-- server service reads/mutates through it and nothing else opens a DataStore.
--
-- Non-negotiable safety rules (§14):
--   * UpdateAsync + pcall + exponential backoff, MaxDataStoreRetries.
--   * Failed-load guard: if load fails after all retries, mark the session
--     load-failed, show a friendly error, BLOCK gameplay, kick safely, and
--     NEVER save over it.
--   * Default-profile reconciliation (TableUtility.reconcile).
--   * Schema migration (example v0 -> v1).
--   * Autosave every GameConfig.AutosaveIntervalSeconds, on PlayerRemoving,
--     and on BindToClose. Save after rebirth.
--   * Sanitize/clamp malformed numbers; repair duplicate slots; prune receipts.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("EconomyConfig"))
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))
local TableUtility = require(Shared:WaitForChild("Utility"):WaitForChild("TableUtility"))

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Server = script.Parent.Parent
local Utility = Server:WaitForChild("Utility")
local DataValidator = require(Utility:WaitForChild("DataValidator"))
local RemoteValidator = require(Utility:WaitForChild("RemoteValidator"))
local RateLimiterModule = require(Utility:WaitForChild("RateLimiter"))

local limiter = RateLimiterModule.new()

local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService"

-- userId -> PlayerData (only present once successfully loaded)
local sessions: { [number]: Types.PlayerData } = {}
-- userId -> true while a load is in flight or has permanently failed (blocks gameplay)
local loadFailed: { [number]: boolean } = {}
-- userId -> true while a load is still in progress (waitForData yields on this)
local loading: { [number]: boolean } = {}
-- userId -> true when this session needs an autosave
local dirty: { [number]: boolean } = {}
-- userId -> transient pass-ownership cache, set by MonetizationService.setPasses.
-- Kept OUT of saved data so PlayerDataService never has to require MonetizationService.
local passes: { [number]: Types.PassOwnership } = {}

local store: DataStore? = nil

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(
			GameConfig.getDataStoreName(),
			GameConfig.DataStoreScope
		)
	end)
	if ok then
		store = result
		return store
	end
	warn(`[PlayerDataService] could not open DataStore: {result}`)
	return nil
end

local function keyFor(userId: number): string
	return `player_{userId}`
end

local function defaultPasses(): Types.PassOwnership
	return { DoubleGrowth = false, AutoCollect = false, GoldenPlotVIP = false }
end

-- ── Default profile ───────────────────────────────────────────────────────
function PlayerDataService.getDefaultProfile(): Types.PlayerData
	return {
		DataVersion = GameConfig.DataVersion,
		Coins = EconomyConfig.StartingCoins,
		LifetimeCoins = 0,
		Rebirths = EconomyConfig.StartingRebirths,
		UnlockedSlots = EconomyConfig.StartingSlots,
		HighestSeedTier = EconomyConfig.StartingSeedTier,
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

-- ── Session accessors ──────────────────────────────────────────────────────
function PlayerDataService.get(userId: number): Types.PlayerData?
	if loadFailed[userId] then
		return nil
	end
	return sessions[userId]
end

function PlayerDataService.isLoaded(userId: number): boolean
	return sessions[userId] ~= nil and not loadFailed[userId]
end

function PlayerDataService.markDirty(userId: number)
	if sessions[userId] then
		dirty[userId] = true
	end
end

-- Yields until the player's data finishes loading. Returns the profile, or nil if
-- the load failed (the caller should then no-op — gameplay is blocked).
function PlayerDataService.waitForData(player: Player): Types.PlayerData?
	local userId = player.UserId
	while loading[userId] and player.Parent == Players do
		task.wait(0.1)
	end
	if loadFailed[userId] then
		return nil
	end
	return sessions[userId]
end

-- Transient pass cache, pushed by MonetizationService (avoids a require cycle).
function PlayerDataService.setPasses(userId: number, ownership: Types.PassOwnership)
	passes[userId] = {
		DoubleGrowth = ownership.DoubleGrowth == true,
		AutoCollect = ownership.AutoCollect == true,
		GoldenPlotVIP = ownership.GoldenPlotVIP == true,
	}
end

function PlayerDataService.getPasses(userId: number): Types.PassOwnership
	return passes[userId] or defaultPasses()
end

-- Apply a validated settings table to the live profile (contract §3 UpdateSettings).
-- The values are already shape/range-checked by RemoteValidator.validateSettings.
function PlayerDataService.applySettings(userId: number, settings: Types.Settings)
	local data = PlayerDataService.get(userId)
	if not data then
		return
	end
	data.Settings.MusicVolume = settings.MusicVolume
	data.Settings.SoundVolume = settings.SoundVolume
	data.Settings.ReducedEffects = settings.ReducedEffects
	PlayerDataService.markDirty(userId)
end

-- ── Migration ──────────────────────────────────────────────────────────────
-- Example v0 -> v1: very old saves stored a flat `coins` field and no DataVersion.
-- Map them forward, then let reconcile fill the rest of the v1 shape.
function PlayerDataService.migrate(data: any): Types.PlayerData
	if type(data) ~= "table" then
		return PlayerDataService.getDefaultProfile()
	end

	local version = data.DataVersion
	if type(version) ~= "number" then
		version = 0
	end

	if version < 1 then
		-- v0 -> v1 example migration.
		if data.coins ~= nil and data.Coins == nil then
			data.Coins = data.coins
			data.coins = nil
		end
		if data.Purchases == nil then
			data.Purchases = { ProcessedReceipts = {} }
		end
		data.DataVersion = 1
	end

	-- Future migrations chain here (v1 -> v2, ...).

	return data
end

-- ── Snapshot (server-computed derived fields, §16) ──────────────────────────
function PlayerDataService.buildSnapshot(userId: number): Types.DataSnapshot?
	local data = PlayerDataService.get(userId)
	if not data then
		return nil
	end

	local ownership = passes[userId] or defaultPasses()

	local nextSlotIndex = data.UnlockedSlots + 1
	local nextSlotCost: number? = nil
	if nextSlotIndex <= EconomyConfig.MaxSlots then
		nextSlotCost = EconomyConfig.getSlotCost(nextSlotIndex)
	end

	return {
		Coins = data.Coins,
		LifetimeCoins = data.LifetimeCoins,
		Rebirths = data.Rebirths,
		IncomeMultiplier = EconomyConfig.getIncomeMultiplier(data.Rebirths),
		UnlockedSlots = data.UnlockedSlots,
		HighestSeedTier = data.HighestSeedTier,
		Slots = TableUtility.deepCopy(data.Slots),
		Tutorial = { Completed = data.Tutorial.Completed, Step = data.Tutorial.Step },
		FertilizerCharges = data.FertilizerCharges,

		PlotId = nil, -- PlotService stamps this onto FarmAssigned; snapshot leaves nil.
		NextSlotCost = nextSlotCost,
		RebirthRequirement = EconomyConfig.getRebirthRequirement(data.Rebirths),
		Passes = {
			DoubleGrowth = ownership.DoubleGrowth,
			AutoCollect = ownership.AutoCollect,
			GoldenPlotVIP = ownership.GoldenPlotVIP,
		},
	}
end

-- Fire the full sanitized snapshot to a single player (§16).
function PlayerDataService.replicate(player: Player)
	local snapshot = PlayerDataService.buildSnapshot(player.UserId)
	if not snapshot then
		return
	end
	Remotes.Events[Constants.Remotes.DataUpdated]:FireClient(player, snapshot)
end

-- ── Load ────────────────────────────────────────────────────────────────────
-- Reconcile, migrate, sanitize a raw stored value into a valid profile.
local function normalizeProfile(raw: any): Types.PlayerData
	local data: any = raw
	if type(data) ~= "table" then
		data = PlayerDataService.getDefaultProfile()
	end
	data = PlayerDataService.migrate(data)
	TableUtility.reconcile(data, PlayerDataService.getDefaultProfile())
	local sanitized = (DataValidator.sanitizeProfile(data))
	return sanitized :: Types.PlayerData
end

function PlayerDataService.load(player: Player)
	local userId = player.UserId
	loading[userId] = true
	loadFailed[userId] = nil
	sessions[userId] = nil

	local ds = getStore()
	if not ds then
		-- No store at all → treat as failed load (never overwrite real data blindly).
		loading[userId] = nil
		PlayerDataService.handleLoadFailure(player)
		return
	end

	local key = keyFor(userId)
	local loaded: any = nil
	local success = false

	for attempt = 1, GameConfig.MaxDataStoreRetries do
		local ok, result = pcall(function()
			return ds:GetAsync(key)
		end)
		if ok then
			loaded = result
			success = true
			break
		end
		warn(`[PlayerDataService] GetAsync attempt {attempt} failed for {userId}: {result}`)
		if attempt < GameConfig.MaxDataStoreRetries then
			task.wait(2 ^ (attempt - 1))
		end
	end

	if not success then
		loading[userId] = nil
		PlayerDataService.handleLoadFailure(player)
		return
	end

	if player.Parent ~= Players then
		-- Player left during load; abandon quietly.
		loading[userId] = nil
		return
	end

	local profile = normalizeProfile(loaded)

	-- Offline growth note: ReadyAt is absolute os.time(), so crops keep growing
	-- while offline automatically (§15). LastSeenAt is informational for the client.
	profile.LastSeenAt = os.time()

	sessions[userId] = profile
	dirty[userId] = false
	loading[userId] = nil
	loadFailed[userId] = nil
end

-- Failed-load guard: block gameplay, notify, kick, never save (§14).
function PlayerDataService.handleLoadFailure(player: Player)
	local userId = player.UserId
	loadFailed[userId] = true
	sessions[userId] = nil
	dirty[userId] = nil

	if player.Parent == Players then
		local ok = pcall(function()
			Remotes.Events[Constants.Remotes.Notification]:FireClient(
				player,
				"Could not load your save. Please rejoin in a moment.",
				2
			)
		end)
		local _ = ok
		task.delay(1, function()
			if player.Parent == Players then
				player:Kick("Your data failed to load. Please rejoin — your progress is safe.")
			end
		end)
	end
end

-- ── Save ─────────────────────────────────────────────────────────────────────
function PlayerDataService.save(player: Player, reason: string?)
	local userId = player.UserId

	-- NEVER save a failed/never-loaded session (would clobber real data, §14).
	if loadFailed[userId] then
		return
	end
	local data = sessions[userId]
	if not data then
		return
	end

	local ds = getStore()
	if not ds then
		warn(`[PlayerDataService] cannot save {userId}: no DataStore`)
		return
	end

	-- Sanitize + stamp LastSeenAt right before persisting.
	DataValidator.sanitizeProfile(data)
	data.LastSeenAt = os.time()
	local payload = TableUtility.deepCopy(data)

	local key = keyFor(userId)
	local saved = false

	for attempt = 1, GameConfig.MaxDataStoreRetries do
		local ok, err = pcall(function()
			ds:UpdateAsync(key, function(_old)
				-- Last-write-wins on this single key; the session cache is authoritative
				-- for an online player, so we replace rather than merge.
				return payload
			end)
		end)
		if ok then
			saved = true
			break
		end
		warn(`[PlayerDataService] UpdateAsync attempt {attempt} failed for {userId}: {err}`)
		if attempt < GameConfig.MaxDataStoreRetries then
			task.wait(2 ^ (attempt - 1))
		end
	end

	if saved then
		dirty[userId] = false
	else
		warn(`[PlayerDataService] save FAILED for {userId} (reason={reason or "?"})`)
	end
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────
local function onPlayerAdded(player: Player)
	PlayerDataService.load(player)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	PlayerDataService.save(player, "PlayerRemoving")
	-- Tear down session state.
	sessions[userId] = nil
	loadFailed[userId] = nil
	loading[userId] = nil
	dirty[userId] = nil
	passes[userId] = nil
	limiter:clear(tostring(userId))
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- UpdateSettings intent (contract §3) — guarded by RateLimiter + RemoteValidator.
	Remotes.Events[Constants.Remotes.UpdateSettings].OnServerEvent:Connect(
		function(player, settings)
			local key = `{player.UserId}:UpdateSettings`
			if not limiter:allow(key, Constants.RateLimits.UpdateSettings) then
				return
			end
			local clean = RemoteValidator.validateSettings(settings)
			if not clean then
				return
			end
			PlayerDataService.applySettings(player.UserId, clean)
		end
	)

	-- RequestData RemoteFunction — lets a (re)connecting client pull the current
	-- snapshot on demand instead of waiting for the next push. Rate-limited; returns
	-- nil while the load is still in flight / failed.
	Remotes.Functions[Constants.RemoteFunctions.RequestData].OnServerInvoke = function(player)
		if not limiter:allow(`{player.UserId}:RequestData`, Constants.RateLimits.Default) then
			return nil
		end
		return PlayerDataService.buildSnapshot(player.UserId)
	end

	-- Players already present (Studio reloads / late require).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, player in Players:GetPlayers() do
			task.spawn(function()
				PlayerDataService.save(player, "BindToClose")
			end)
		end
		-- Give saves a brief window to flush.
		task.wait(3)
	end)
end

function PlayerDataService.Start()
	-- Autosave loop: save every dirty session on the configured interval.
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveIntervalSeconds)
			for _, player in Players:GetPlayers() do
				local userId = player.UserId
				if dirty[userId] and not loadFailed[userId] and sessions[userId] then
					task.spawn(function()
						PlayerDataService.save(player, "Autosave")
					end)
				end
			end
		end
	end)
end

return PlayerDataService
