--!strict
-- PlayerDataService — persistent player data via ProfileStore session-locking (§13, §14).
-- TRACK A owns this. Sole owner of the in-memory session cache: every other server
-- service reads/mutates through it and nothing else opens a DataStore.
--
-- Backend: ProfileStore (MadStudio / loleris) — the de-facto standard used by top
-- idle/sim games (incl. Grow a Garden). Vendored at Server/Vendor/ProfileStore.luau
-- (Apache-2.0). Session-locking gives us, for free, the safety the spec demands (§14):
--   * Atomic per-key lock → two servers can never load/save the same profile at once
--     (no server-hop / fast-rejoin data loss or duplication).
--   * Periodic auto-save + save-on-EndSession + auto BindToClose handling.
--   * :Reconcile() fills missing template fields (schema growth).
-- On top of ProfileStore we keep our own concerns: an explicit FAILED-LOAD GUARD
-- (StartSession returns nil → block gameplay, notify, kick, never save), a v0→v1
-- migration, DataValidator sanitization, leaderstats mirroring, and a 60s save cadence.

local Players = game:GetService("Players")
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
local ProfileStore = require(Server:WaitForChild("Vendor"):WaitForChild("ProfileStore"))

local limiter = RateLimiterModule.new()

local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService"

-- A loaded ProfileStore profile (kept untyped — ProfileStore is third-party).
type Profile = any

-- userId -> PlayerData (== profile.Data; present only once successfully loaded)
local sessions: { [number]: Types.PlayerData } = {}
-- userId -> active Profile object
local profiles: { [number]: Profile } = {}
-- userId -> true while a load has permanently failed (blocks gameplay)
local loadFailed: { [number]: boolean } = {}
-- userId -> true while a load is still in progress (waitForData yields on this)
local loading: { [number]: boolean } = {}
-- userId -> true when this session has unsaved changes (cleared by the 60s save loop)
local dirty: { [number]: boolean } = {}
-- userId -> transient pass-ownership cache, set by MonetizationService.setPasses.
-- Kept OUT of saved data so PlayerDataService never has to require MonetizationService.
local passes: { [number]: Types.PassOwnership } = {}
-- userId -> assigned plot id, set by PlotService (same trick to dodge a require cycle).
local plotIds: { [number]: number } = {}

local function keyFor(userId: number): string
	return `player_{userId}`
end

local function defaultPasses(): Types.PassOwnership
	return { DoubleGrowth = false, AutoCollect = false, GoldenPlotVIP = false }
end

-- ── Default profile (also the ProfileStore template) ────────────────────────
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

-- One ProfileStore for the whole experience (dev/prod name from GameConfig). In
-- Studio without API access, ProfileStore transparently uses an in-memory mock.
local profileStore =
	ProfileStore.New(GameConfig.getDataStoreName(), PlayerDataService.getDefaultProfile())

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

-- Transient plot-id cache, pushed by PlotService on assignment (avoids a require
-- cycle; lets buildSnapshot populate DataSnapshot.PlotId for client slot scoping).
function PlayerDataService.setPlotId(userId: number, plotId: number?)
	plotIds[userId] = plotId
end

-- Apply a validated settings table to the live profile (contract §3 UpdateSettings).
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
-- Mutates `data` IN PLACE (ProfileStore requires the same table reference) then
-- relies on :Reconcile() to fill the rest of the v1 shape.
function PlayerDataService.migrate(data: any): Types.PlayerData
	if type(data) ~= "table" then
		return PlayerDataService.getDefaultProfile()
	end

	local version = data.DataVersion
	if type(version) ~= "number" then
		version = 0
	end

	if version < 1 then
		-- v0 -> v1 example migration (runs BEFORE reconcile so old fields win).
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

-- ── Leaderstats mirroring (standard pattern) ────────────────────────────────
local function setupLeaderstats(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = ls

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls

	ls.Parent = player
end

local function updateLeaderstats(player: Player)
	local data = sessions[player.UserId]
	if not data then
		return
	end
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		return
	end
	local coins = ls:FindFirstChild("Coins") :: IntValue?
	if coins then
		-- IntValue caps at 2^31; clamp so very large balances don't overflow.
		coins.Value = math.clamp(math.floor(data.Coins), 0, 2 ^ 31 - 1)
	end
	local rebirths = ls:FindFirstChild("Rebirths") :: IntValue?
	if rebirths then
		rebirths.Value = math.clamp(data.Rebirths, 0, 2 ^ 31 - 1)
	end
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

		PlotId = plotIds[userId], -- populated by PlotService.setPlotId on assignment
		NextSlotCost = nextSlotCost,
		RebirthRequirement = EconomyConfig.getRebirthRequirement(data.Rebirths),
		Passes = {
			DoubleGrowth = ownership.DoubleGrowth,
			AutoCollect = ownership.AutoCollect,
			GoldenPlotVIP = ownership.GoldenPlotVIP,
		},
		ReducedEffects = data.Settings.ReducedEffects == true,
	}
end

-- Fire the full sanitized snapshot to a single player (§16) + keep leaderstats synced.
function PlayerDataService.replicate(player: Player)
	updateLeaderstats(player)
	local snapshot = PlayerDataService.buildSnapshot(player.UserId)
	if not snapshot then
		return
	end
	Remotes.Events[Constants.Remotes.DataUpdated]:FireClient(player, snapshot)
end

-- Failed-load guard: block gameplay, notify, kick, never save (§14).
function PlayerDataService.handleLoadFailure(player: Player)
	local userId = player.UserId
	loadFailed[userId] = true
	sessions[userId] = nil
	profiles[userId] = nil
	dirty[userId] = nil

	if player.Parent == Players then
		pcall(function()
			Remotes.Events[Constants.Remotes.Notification]:FireClient(
				player,
				"Could not load your save. Please rejoin in a moment.",
				2
			)
		end)
		task.delay(1, function()
			if player.Parent == Players then
				player:Kick("Your data failed to load. Please rejoin — your progress is safe.")
			end
		end)
	end
end

-- ── Load (start a ProfileStore session) ─────────────────────────────────────
function PlayerDataService.load(player: Player)
	local userId = player.UserId
	loading[userId] = true
	loadFailed[userId] = nil
	sessions[userId] = nil

	-- Cancel the (potentially long, lock-contended) session start if the player
	-- leaves first — ProfileStore returns nil in that case.
	local profile = profileStore:StartSessionAsync(keyFor(userId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		loading[userId] = nil
		if player.Parent ~= Players then
			-- Player left during the load; not a failure, just abandon quietly.
			return
		end
		-- Genuinely could not acquire the session lock → failed-load guard.
		PlayerDataService.handleLoadFailure(player)
		return
	end

	profile:AddUserId(userId) -- GDPR association
	-- Order matters: migrate old fields first, then reconcile fills the template,
	-- then sanitize clamps/repairs. All operate IN PLACE on profile.Data.
	PlayerDataService.migrate(profile.Data)
	profile:Reconcile()
	DataValidator.sanitizeProfile(profile.Data)

	-- The session can end out from under us if another server steals the lock or the
	-- game closes — tear down and kick so the player rejoins cleanly (no double-data).
	profile.OnSessionEnd:Connect(function()
		sessions[userId] = nil
		profiles[userId] = nil
		if player.Parent == Players then
			player:Kick("Your save was opened elsewhere. Please rejoin — your progress is safe.")
		end
	end)

	if player.Parent ~= Players then
		-- Left right as the session opened: release the lock immediately.
		profile:EndSession()
		loading[userId] = nil
		return
	end

	-- Offline growth note: ReadyAt is absolute os.time(), so crops keep growing while
	-- offline automatically (§15); LastSeenAt is informational for the client.
	profile.Data.LastSeenAt = os.time()

	profiles[userId] = profile
	sessions[userId] = profile.Data
	loadFailed[userId] = nil
	loading[userId] = nil

	setupLeaderstats(player)
	PlayerDataService.replicate(player)
end

-- ── Save (manual flush; ProfileStore also auto-saves + saves on EndSession) ──
function PlayerDataService.save(player: Player, reason: string?)
	local userId = player.UserId
	if loadFailed[userId] then
		return -- never persist a failed/never-loaded session (§14)
	end
	local profile = profiles[userId]
	if not profile or profile:IsActive() ~= true then
		return
	end

	-- Sanitize + stamp LastSeenAt right before persisting (in place).
	DataValidator.sanitizeProfile(profile.Data)
	profile.Data.LastSeenAt = os.time()

	local ok, err = pcall(function()
		profile:Save()
	end)
	if ok then
		dirty[userId] = false
	else
		warn(`[PlayerDataService] save FAILED for {userId} (reason={reason or "?"}): {err}`)
	end
end

-- ── Lifecycle ────────────────────────────────────────────────────────────────
local function onPlayerAdded(player: Player)
	PlayerDataService.load(player)
end

local function onPlayerRemoving(player: Player)
	local userId = player.UserId
	local profile = profiles[userId]
	if profile then
		-- EndSession performs a final save AND releases the lock.
		pcall(function()
			profile:EndSession()
		end)
	end
	sessions[userId] = nil
	profiles[userId] = nil
	loadFailed[userId] = nil
	loading[userId] = nil
	dirty[userId] = nil
	passes[userId] = nil
	plotIds[userId] = nil
	limiter:clear(tostring(userId))
end

function PlayerDataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- UpdateSettings intent (contract §3) — guarded by RateLimiter + RemoteValidator.
	Remotes.Events[Constants.Remotes.UpdateSettings].OnServerEvent:Connect(
		function(player, settings)
			if
				not limiter:allow(
					`{player.UserId}:UpdateSettings`,
					Constants.RateLimits.UpdateSettings
				)
			then
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
	-- snapshot on demand. Rate-limited; returns nil while load is in flight / failed.
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

	-- NOTE: ProfileStore installs its own game:BindToClose to end every active
	-- session (final save + lock release) on shutdown, so we do not add one here.
end

function PlayerDataService.Start()
	-- 60s save cadence for dirty sessions (ProfileStore also auto-saves on its own
	-- longer interval; this tightens the worst-case loss window on a hard crash).
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveIntervalSeconds)
			for _, player in Players:GetPlayers() do
				local userId = player.UserId
				if dirty[userId] and PlayerDataService.isLoaded(userId) then
					task.spawn(function()
						PlayerDataService.save(player, "Autosave")
					end)
				end
			end
		end
	end)
end

return PlayerDataService
