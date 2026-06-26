--!strict
-- PlotFactory — builds a placeholder plot model (§11, §22). TRACK C owns this.
--
-- Each plot: owner sign, spawn point, farm ground, 12 grow-slot anchor parts (first
-- 2 unlocked, the rest locked markers), a rebirth altar, a shop sign, a decorative
-- border. Anchored parts only; spaced for large final creatures. The plot root is
-- tagged Constants.Tags.Plot with PlotId/OwnerUserId attributes; each grow-slot anchor
-- is tagged Constants.Tags.GrowSlot with SlotIndex + Locked attributes so the CLIENT
-- can locate its slots in 3D (§11, INTEGRATION_CONTRACT §4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))

local PlotFactory = {}

-- ── Layout constants (studs). Sized so the largest final creatures (BaseScale up
-- to ~2.6 × Giant 1.8) have clearance on every grow slot. ───────────────────────
local GROUND_SIZE = Vector3.new(96, 2, 96)
local GROUND_TOP = GROUND_SIZE.Y / 2 -- y of the ground surface relative to plot origin

local SLOT_COLUMNS = 4 -- 12 slots = 4 columns × 3 rows
local SLOT_ROWS = 3
local SLOT_SPACING = 18 -- centre-to-centre, leaves room for large creatures
local SLOT_ANCHOR_SIZE = Vector3.new(8, 1, 8)

local TOTAL_SLOTS = SLOT_COLUMNS * SLOT_ROWS -- 12

local UNLOCKED_SLOT_COUNT = 2 -- first 2 grow slots start unlocked (§11)

-- Colors are local to visuals only (never stored in data, §13).
local GROUND_COLOR = Color3.fromRGB(96, 132, 74)
local BORDER_COLOR = Color3.fromRGB(70, 52, 38)
local SLOT_DIRT_COLOR = Color3.fromRGB(110, 78, 52)
local SLOT_LOCKED_COLOR = Color3.fromRGB(70, 70, 78)
local SIGN_COLOR = Color3.fromRGB(150, 110, 70)
local SPAWN_COLOR = Color3.fromRGB(80, 170, 240)
local ALTAR_COLOR = Color3.fromRGB(150, 90, 210)
local SHOP_COLOR = Color3.fromRGB(230, 180, 70)

-- Create an anchored Part with the common defaults, parented to `parent`.
local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- Attach a single-face label so signs/altars read clearly in 3D.
local function addLabel(part: BasePart, text: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face
	gui.CanvasSize = Vector2.new(400, 200)
	gui.Adornee = part
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(245, 245, 245)
	label.Text = text
	label.Parent = gui
end

-- Build one grow-slot anchor part. `slotIndex` is 1-based; first UNLOCKED_SLOT_COUNT
-- start unlocked, the rest are locked markers (§11, INTEGRATION_CONTRACT §4).
local function buildSlotAnchor(plotId: number, slotIndex: number, localPosition: Vector3): Part
	local locked = slotIndex > UNLOCKED_SLOT_COUNT
	local color = if locked then SLOT_LOCKED_COLOR else SLOT_DIRT_COLOR
	local anchor = makePart(`Slot{slotIndex}`, SLOT_ANCHOR_SIZE, color, Enum.Material.Ground)
	anchor.CanCollide = false -- creatures sit on top; players walk through dirt
	anchor.CFrame = CFrame.new(localPosition)

	anchor:SetAttribute(Constants.Attributes.PlotId, plotId)
	anchor:SetAttribute(Constants.Attributes.SlotIndex, slotIndex)
	anchor:SetAttribute(Constants.Attributes.Locked, locked)
	CollectionService:AddTag(anchor, Constants.Tags.GrowSlot)

	-- A lock marker on locked slots; harmless cosmetic, removed implicitly when the
	-- slot is unlocked + a creature is parented (Track C does not own unlock state).
	if locked then
		local marker = makePart(
			"LockMarker",
			Vector3.new(2, 2, 2),
			Color3.fromRGB(40, 40, 46),
			Enum.Material.Metal
		)
		marker.CanCollide = false
		marker.Transparency = 0.2
		marker.CFrame = CFrame.new(localPosition + Vector3.new(0, 2.5, 0))
			* CFrame.Angles(0, 0, math.rad(45))
		marker.Parent = anchor
	end

	return anchor
end

-- Build a plot Model at `origin`. Returns the Model (caller parents it under the
-- Plots folder). All parts anchored + idempotently rebuildable by the caller.
function PlotFactory.build(plotId: number, origin: CFrame): Model?
	local plot = Instance.new("Model")
	plot.Name = `Plot_{plotId}`

	-- Ground.
	local ground = makePart("Ground", GROUND_SIZE, GROUND_COLOR, Enum.Material.Grass)
	ground.CFrame = origin
	ground.Parent = plot
	plot.PrimaryPart = ground

	-- Decorative border (4 thin walls around the ground edge).
	local borderHeight = 3
	local borderThickness = 2
	local half = GROUND_SIZE.X / 2
	local borders = {
		{
			Vector3.new(GROUND_SIZE.X + borderThickness, borderHeight, borderThickness),
			Vector3.new(0, borderHeight / 2 + GROUND_TOP, half),
		},
		{
			Vector3.new(GROUND_SIZE.X + borderThickness, borderHeight, borderThickness),
			Vector3.new(0, borderHeight / 2 + GROUND_TOP, -half),
		},
		{
			Vector3.new(borderThickness, borderHeight, GROUND_SIZE.Z + borderThickness),
			Vector3.new(half, borderHeight / 2 + GROUND_TOP, 0),
		},
		{
			Vector3.new(borderThickness, borderHeight, GROUND_SIZE.Z + borderThickness),
			Vector3.new(-half, borderHeight / 2 + GROUND_TOP, 0),
		},
	}
	for i, spec in borders do
		local wall = makePart(`Border{i}`, spec[1], BORDER_COLOR, Enum.Material.WoodPlanks)
		wall.CFrame = origin * CFrame.new(spec[2])
		wall.Parent = plot
	end

	-- Owner sign (front-left), shows the plot owner's name once assigned.
	local ownerSign =
		makePart("OwnerSign", Vector3.new(10, 6, 1), SIGN_COLOR, Enum.Material.WoodPlanks)
	ownerSign.CFrame = origin * CFrame.new(-half + 8, GROUND_TOP + 4, -half + 3)
	addLabel(ownerSign, "Unclaimed Plot", Enum.NormalId.Back)
	ownerSign.Parent = plot

	-- Spawn point (front-centre) — players teleport here on assignment.
	local spawnPart = makePart("SpawnPoint", Vector3.new(8, 1, 8), SPAWN_COLOR, Enum.Material.Neon)
	spawnPart.CanCollide = true
	spawnPart.CFrame = origin * CFrame.new(0, GROUND_TOP + 0.5, -half + 8)
	spawnPart.Parent = plot

	-- Grow-slot anchors laid out in a SLOT_COLUMNS × SLOT_ROWS grid, centred.
	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "GrowSlots"
	slotsFolder.Parent = plot

	local gridWidth = (SLOT_COLUMNS - 1) * SLOT_SPACING
	local gridDepth = (SLOT_ROWS - 1) * SLOT_SPACING
	local slotIndex = 0
	for row = 0, SLOT_ROWS - 1 do
		for col = 0, SLOT_COLUMNS - 1 do
			slotIndex += 1
			if slotIndex > TOTAL_SLOTS then
				break
			end
			local x = -gridWidth / 2 + col * SLOT_SPACING
			local z = -gridDepth / 2 + row * SLOT_SPACING + 4 -- nudged back from spawn
			local localPos = (origin * CFrame.new(x, GROUND_TOP + SLOT_ANCHOR_SIZE.Y / 2, z)).Position
			local anchor = buildSlotAnchor(plotId, slotIndex, localPos)
			anchor.Parent = slotsFolder
		end
	end

	-- Rebirth altar (back-left).
	local altar = makePart("RebirthAltar", Vector3.new(8, 5, 8), ALTAR_COLOR, Enum.Material.Neon)
	altar.CFrame = origin * CFrame.new(-half + 10, GROUND_TOP + 2.5, half - 10)
	addLabel(altar, "REBIRTH", Enum.NormalId.Front)
	altar.Parent = plot

	-- Shop sign (back-right).
	local shopSign =
		makePart("ShopSign", Vector3.new(10, 6, 1), SHOP_COLOR, Enum.Material.SmoothPlastic)
	shopSign.CFrame = origin * CFrame.new(half - 8, GROUND_TOP + 4, half - 3)
	addLabel(shopSign, "SHOP", Enum.NormalId.Front)
	shopSign.Parent = plot

	-- Tag + attribute the plot root (§11, INTEGRATION_CONTRACT §4). OwnerUserId is
	-- 0 until Track A assigns an owner via WorldService.buildPlotFor.
	plot:SetAttribute(Constants.Attributes.PlotId, plotId)
	plot:SetAttribute(Constants.Attributes.OwnerUserId, 0)
	CollectionService:AddTag(plot, Constants.Tags.Plot)

	return plot
end

-- Exposed for WorldService so generation + queries agree on the layout.
PlotFactory.GroundSize = GROUND_SIZE
PlotFactory.TotalSlots = TOTAL_SLOTS
PlotFactory.UnlockedSlotCount = UNLOCKED_SLOT_COUNT

-- Sanity: TOTAL_SLOTS must match the data-layer slot count (12). GrowthStageCount is
-- unrelated but referencing GameConfig keeps the dependency explicit for Track A.
assert(GameConfig.PlotCount >= 1, "PlotCount must be >= 1")

return PlotFactory
