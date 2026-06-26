--!strict
-- WorldService — world generation + authored-map detection (§22).
-- TRACK C owns the visual generation. Track A's PlotService CALLS this service to
-- assign owners + rebuild visuals (INTEGRATION_CONTRACT §6 seam).
--
-- Responsibilities:
--   * Detect an authored Workspace/<AuthoredMapFolder> before generating placeholders.
--   * If none, procedurally generate (idempotently) a baseplate, central spawn,
--     lighting, and GameConfig.PlotCount plots laid out in a grid via PlotFactory,
--     under Workspace/<GeneratedFolder>/<PlotsFolder>. Never generate duplicates.
--   * Public API used by Track A:
--       buildPlotFor(player, plotId) — set owner attributes, teleport, rebuild slots.
--       getPlotById(plotId) / getSlotAnchor(plotId, slotIndex) — Workspace lookups.
--       clearPlot(plotId) — clear transient models on leave (never delete data).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local Factories = ServerScriptService:WaitForChild("Server"):WaitForChild("Factories")
local PlotFactory = require(Factories:WaitForChild("PlotFactory"))

local WorldService = {}
WorldService.Name = "WorldService"

-- ── Layout ──────────────────────────────────────────────────────────────────────
-- Plots are laid out in as-square-as-possible grid. Spacing leaves a path gutter
-- between plots and clearance for the large border walls.
local PLOT_GAP = 40 -- studs of empty path between adjacent plot grounds
local PLOT_STRIDE = PlotFactory.GroundSize.X + PLOT_GAP
local BASEPLATE_PADDING = PlotFactory.GroundSize.X -- extra ground around the plots

-- Cached references (rebuilt lazily from Workspace so the service is stateless-safe).
local plotsFolderRef: Folder? = nil

-- ── Internal helpers ──────────────────────────────────────────────────────────────

local function getGeneratedFolder(create: boolean): Folder?
	local existing = Workspace:FindFirstChild(Constants.World.GeneratedFolder)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if not create then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.World.GeneratedFolder
	folder.Parent = Workspace
	return folder
end

local function getPlotsFolder(create: boolean): Folder?
	if plotsFolderRef and plotsFolderRef.Parent then
		return plotsFolderRef
	end
	local generated = getGeneratedFolder(create)
	if not generated then
		return nil
	end
	local existing = generated:FindFirstChild(Constants.World.PlotsFolder)
	if existing and existing:IsA("Folder") then
		plotsFolderRef = existing
		return existing
	end
	if not create then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = Constants.World.PlotsFolder
	folder.Parent = generated
	plotsFolderRef = folder
	return folder
end

-- True if an author placed a Workspace/<AuthoredMapFolder>; if so we never generate.
local function hasAuthoredMap(): boolean
	local map = Workspace:FindFirstChild(Constants.World.AuthoredMapFolder)
	return map ~= nil
end

-- Compute the grid dimensions (columns × rows) for `count` plots.
local function gridDimensions(count: number): (number, number)
	local cols = math.ceil(math.sqrt(count))
	local rows = math.ceil(count / cols)
	return cols, rows
end

-- Origin CFrame (ground centre) for plot number `index` (1-based) in the grid.
local function plotOrigin(index: number, cols: number, rows: number): CFrame
	local zeroBased = index - 1
	local col = zeroBased % cols
	local row = math.floor(zeroBased / cols)
	local gridWidth = (cols - 1) * PLOT_STRIDE
	local gridDepth = (rows - 1) * PLOT_STRIDE
	local x = -gridWidth / 2 + col * PLOT_STRIDE
	local z = -gridDepth / 2 + row * PLOT_STRIDE
	-- Ground sits so its TOP surface is at y = 0 (players spawn on top).
	local groundCenterY = -PlotFactory.GroundSize.Y / 2
	return CFrame.new(x, groundCenterY, z)
end

local function ensureBaseplate(generated: Folder, cols: number, rows: number)
	if generated:FindFirstChild("Baseplate") then
		return
	end
	local width = (cols - 1) * PLOT_STRIDE + PlotFactory.GroundSize.X + BASEPLATE_PADDING * 2
	local depth = (rows - 1) * PLOT_STRIDE + PlotFactory.GroundSize.Z + BASEPLATE_PADDING * 2
	local base = Instance.new("Part")
	base.Name = "Baseplate"
	base.Anchored = true
	base.Size = Vector3.new(width, 4, depth)
	base.Position = Vector3.new(0, -PlotFactory.GroundSize.Y - 2, 0)
	base.Color = Color3.fromRGB(58, 64, 72)
	base.Material = Enum.Material.Slate
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = generated
end

local function ensureCentralSpawn(generated: Folder)
	if generated:FindFirstChild("CentralSpawn") then
		return
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CentralSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = generated
end

local function ensureLighting()
	-- Idempotent: only nudges a flag if our marker is absent.
	if Lighting:GetAttribute("BrainrotWorldLightingApplied") then
		return
	end
	Lighting.Ambient = Color3.fromRGB(120, 120, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting:SetAttribute("BrainrotWorldLightingApplied", true)
end

-- ── Public API ─────────────────────────────────────────────────────────────────

-- Return the plot Model for `plotId`, or nil if not generated / not present.
function WorldService.getPlotById(plotId: number): Model?
	local plots = getPlotsFolder(false)
	if not plots then
		return nil
	end
	for _, child in plots:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(Constants.Attributes.PlotId) == plotId then
			return child
		end
	end
	return nil
end

-- Return the grow-slot anchor Part for (plotId, slotIndex), or nil.
function WorldService.getSlotAnchor(plotId: number, slotIndex: number): BasePart?
	local plot = WorldService.getPlotById(plotId)
	if not plot then
		return nil
	end
	for _, descendant in plot:GetDescendants() do
		if
			descendant:IsA("BasePart")
			and descendant:GetAttribute(Constants.Attributes.SlotIndex) == slotIndex
		then
			return descendant
		end
	end
	return nil
end

-- Mark a plot's owner, teleport the player to its spawn, and (re)build slot visuals.
-- Called by Track A's PlotService.assign (INTEGRATION_CONTRACT §6). The player's saved
-- data is owned by Track A; this only touches Workspace.
function WorldService.buildPlotFor(player: Player, plotId: number)
	local plot = WorldService.getPlotById(plotId)
	if not plot then
		warn(`[WorldService] buildPlotFor: no plot {plotId}`)
		return
	end

	-- Owner attributes (§11, INTEGRATION_CONTRACT §4).
	plot:SetAttribute(Constants.Attributes.OwnerUserId, player.UserId)

	-- Update the owner sign text if present.
	local ownerSign = plot:FindFirstChild("OwnerSign")
	if ownerSign then
		local label = ownerSign:FindFirstChild("Label")
		local text = label and label:FindFirstChild("Text")
		if text and text:IsA("TextLabel") then
			text.Text = `{player.DisplayName}'s Plot`
		end
	end

	-- Clear any transient creature models from a previous owner before rebuild.
	WorldService.clearPlot(plotId)

	-- Teleport the player to the plot spawn point.
	local spawnPart = plot:FindFirstChild("SpawnPoint")
	if spawnPart and spawnPart:IsA("BasePart") then
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = spawnPart.CFrame + Vector3.new(0, 4, 0)
		end
	end
end

-- Clear TRANSIENT visuals (creature models) for a plot on owner leave. Never deletes
-- the plot itself or any persistent data (§11). Also resets owner attributes/sign so
-- the plot can be reassigned cleanly.
function WorldService.clearPlot(plotId: number)
	local plot = WorldService.getPlotById(plotId)
	if not plot then
		return
	end

	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("Model") and descendant.Name == "CreatureModel" then
			descendant:Destroy()
		end
	end

	plot:SetAttribute(Constants.Attributes.OwnerUserId, 0)
	local ownerSign = plot:FindFirstChild("OwnerSign")
	if ownerSign then
		local label = ownerSign:FindFirstChild("Label")
		local text = label and label:FindFirstChild("Text")
		if text and text:IsA("TextLabel") then
			text.Text = "Unclaimed Plot"
		end
	end
end

-- Generate the placeholder world idempotently. Safe to call repeatedly: it only
-- creates what is missing and never duplicates plots.
local function generateWorld()
	local count = GameConfig.PlotCount
	local cols, rows = gridDimensions(count)

	local generated = getGeneratedFolder(true) :: Folder
	ensureBaseplate(generated, cols, rows)
	ensureCentralSpawn(generated)
	ensureLighting()

	local plots = getPlotsFolder(true) :: Folder

	-- Index existing plots so we never rebuild one that already exists.
	local existingById: { [number]: boolean } = {}
	for _, child in plots:GetChildren() do
		if child:IsA("Model") then
			local id = child:GetAttribute(Constants.Attributes.PlotId)
			if typeof(id) == "number" then
				existingById[id] = true
			end
		end
	end

	for plotId = 1, count do
		if not existingById[plotId] then
			local origin = plotOrigin(plotId, cols, rows)
			local model = PlotFactory.build(plotId, origin)
			if model then
				model.Parent = plots
			end
		end
	end
end

function WorldService.Init()
	-- Authored map wins: skip placeholder generation entirely (§22).
	if hasAuthoredMap() then
		return
	end
	generateWorld()
end

function WorldService.Start() end

return WorldService
