--!strict
-- CreatureModelFactory — builds placeholder creature models from primitive Parts (§21).
-- TRACK C owns this.
--
-- Build creatures procedurally (anchored Parts + WeldConstraints) by ModelBuilderId
-- (Quadruped/Biped/Blob/Tall). 4 simplifying growth stages drive size + StageColors.
-- Mutation visuals: Shiny = reflective glass, Golden = gold metal, Giant = scale up,
-- Glitched = restrained ForceField + slight offset (NO rapid flashing). Particles are
-- limited for mobile. Models are parented under the slot anchor so they replicate, and
-- old models are cleaned up first (INTEGRATION_CONTRACT §4).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig"))
local Definitions = Shared:WaitForChild("Definitions")
local CreatureDefinitions = require(Definitions:WaitForChild("CreatureDefinitions"))
local MutationDefinitions = require(Definitions:WaitForChild("MutationDefinitions"))

local CreatureModelFactory = {}

local STAGE_COUNT = GameConfig.GrowthStageCount -- 4 (Egg, Sprout, Awkward, Full)
local MODEL_NAME = "CreatureModel" -- single model per slot; cleaned up on respawn

-- Per-stage scale of the final size. Early stages are smaller AND simpler (§21).
local STAGE_SCALE = { 0.35, 0.55, 0.78, 1.0 }
-- Below this stage index the model is rendered as a simple egg/blob (simplification).
local SIMPLE_BELOW_STAGE = 2 -- stages 0 and 1 are simplified egg forms

-- Convert an {r,g,b} 0-255 triple from the definitions into a Color3.
function CreatureModelFactory.toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Resolve a mutation material string (e.g. "Metal") to an Enum.Material, defaulting
-- to Plastic if the name is missing/unknown.
function CreatureModelFactory.toMaterial(name: string?): Enum.Material
	if name then
		local material = (Enum.Material :: any)[name]
		if material then
			return material
		end
	end
	return Enum.Material.Plastic
end

-- Clamp an incoming stage index into the valid range [0, STAGE_COUNT-1].
local function clampStage(stageIndex: number): number
	return math.clamp(math.floor(stageIndex), 0, STAGE_COUNT - 1)
end

-- Pick the StageColor for a stage, defaulting to FinalColor when missing.
local function stageColor(def, stageIndex: number): Color3
	local triple = def.StageColors[stageIndex + 1] or def.FinalColor
	return CreatureModelFactory.toColor3(triple)
end

-- Anchored body Part with sensible defaults.
local function makePart(name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

-- ── Procedural body builders. Each returns the list of {part, localOffset} relative
-- to the model centre (y up from the ground). Sizes are in "final" studs; the caller
-- scales the whole thing by stage + creature BaseScale + mutation ScaleMultiplier. ──

local function buildQuadruped(bodyColor: Color3, accentColor: Color3): { { any } }
	local parts = {}
	local body = makePart("Body", Vector3.new(4, 2.2, 6), bodyColor)
	table.insert(parts, { body, Vector3.new(0, 3, 0) })
	local head = makePart("Head", Vector3.new(2.4, 2.2, 2.4), bodyColor)
	table.insert(parts, { head, Vector3.new(0, 4, 3.6) })
	local snout = makePart("Snout", Vector3.new(1.2, 1, 1.2), accentColor)
	table.insert(parts, { snout, Vector3.new(0, 3.6, 5) })
	for i, off in
		{
			Vector3.new(1.4, 0, 2),
			Vector3.new(-1.4, 0, 2),
			Vector3.new(1.4, 0, -2),
			Vector3.new(-1.4, 0, -2),
		}
	do
		local leg = makePart(`Leg{i}`, Vector3.new(0.9, 2.4, 0.9), accentColor)
		table.insert(parts, { leg, Vector3.new(off.X, 1.2, off.Z) })
	end
	return parts
end

local function buildBiped(bodyColor: Color3, accentColor: Color3): { { any } }
	local parts = {}
	local torso = makePart("Torso", Vector3.new(3, 4, 2), bodyColor)
	table.insert(parts, { torso, Vector3.new(0, 4.5, 0) })
	local head = makePart("Head", Vector3.new(2.4, 2.4, 2.4), bodyColor)
	table.insert(parts, { head, Vector3.new(0, 7.7, 0) })
	for i, x in { 2.1, -2.1 } do
		local arm = makePart(`Arm{i}`, Vector3.new(1, 3.5, 1), accentColor)
		table.insert(parts, { arm, Vector3.new(x, 4.5, 0) })
	end
	for i, x in { 0.9, -0.9 } do
		local leg = makePart(`Leg{i}`, Vector3.new(1.1, 3, 1.1), accentColor)
		table.insert(parts, { leg, Vector3.new(x, 1.5, 0) })
	end
	return parts
end

local function buildBlob(bodyColor: Color3, accentColor: Color3): { { any } }
	local parts = {}
	local body = makePart("Body", Vector3.new(5, 4.5, 5), bodyColor)
	body.Shape = Enum.PartType.Ball
	table.insert(parts, { body, Vector3.new(0, 2.6, 0) })
	for i, off in { Vector3.new(1.1, 1.2, 2.2), Vector3.new(-1.1, 1.2, 2.2) } do
		local eye = makePart(`Eye{i}`, Vector3.new(0.9, 0.9, 0.9), accentColor)
		eye.Shape = Enum.PartType.Ball
		table.insert(parts, { eye, Vector3.new(off.X, 2.6 + off.Y, off.Z) })
	end
	return parts
end

local function buildTall(bodyColor: Color3, accentColor: Color3): { { any } }
	local parts = {}
	local neck = makePart("Neck", Vector3.new(1.6, 6, 1.6), bodyColor)
	table.insert(parts, { neck, Vector3.new(0, 6, 0) })
	local body = makePart("Body", Vector3.new(3.5, 3, 4), bodyColor)
	table.insert(parts, { body, Vector3.new(0, 2.5, 0) })
	local head = makePart("Head", Vector3.new(2, 2, 2.6), accentColor)
	table.insert(parts, { head, Vector3.new(0, 9.5, 0.6) })
	for i, off in
		{
			Vector3.new(1.2, 0, 1.2),
			Vector3.new(-1.2, 0, 1.2),
			Vector3.new(1.2, 0, -1.2),
			Vector3.new(-1.2, 0, -1.2),
		}
	do
		local leg = makePart(`Leg{i}`, Vector3.new(0.8, 2.5, 0.8), accentColor)
		table.insert(parts, { leg, Vector3.new(off.X, 1.25, off.Z) })
	end
	return parts
end

-- Simplified early-stage form: a single egg/blob part regardless of builder (§21).
local function buildEgg(bodyColor: Color3, accentColor: Color3): { { any } }
	local parts = {}
	local egg = makePart("Egg", Vector3.new(3, 3.6, 3), bodyColor)
	egg.Shape = Enum.PartType.Ball
	table.insert(parts, { egg, Vector3.new(0, 2, 0) })
	local spot = makePart("Spot", Vector3.new(1, 1, 1), accentColor)
	spot.Shape = Enum.PartType.Ball
	table.insert(parts, { spot, Vector3.new(0.8, 2.6, 1.2) })
	return parts
end

local BUILDERS: { [string]: (Color3, Color3) -> { { any } } } = {
	Quadruped = buildQuadruped,
	Biped = buildBiped,
	Blob = buildBlob,
	Tall = buildTall,
}

-- Apply mutation cosmetics to every part of the model. Restrained, no flashing (§21).
local function applyMutation(model: Model, mutationDef)
	if not mutationDef or mutationDef.Id == "Normal" then
		return
	end

	local material = CreatureModelFactory.toMaterial(mutationDef.Material)
	local overrideColor: Color3? = if mutationDef.Color
		then CreatureModelFactory.toColor3(mutationDef.Color)
		else nil
	local reflectance = 0
	if mutationDef.Id == "Shiny" then
		reflectance = 0.6 -- reflective, not animated
	elseif mutationDef.Id == "Golden" then
		reflectance = 0.4
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if mutationDef.Material then
				descendant.Material = material
			end
			if overrideColor then
				descendant.Color = overrideColor
			end
			descendant.Reflectance = reflectance
			if mutationDef.Id == "Glitched" then
				-- Slight static offset + transparency; ForceField material already
				-- shimmers gently on its own (no scripted flashing).
				descendant.Transparency = 0.15
				descendant.CFrame = descendant.CFrame
					* CFrame.new((math.random() - 0.5) * 0.6, 0, (math.random() - 0.5) * 0.6)
			end
		end
	end

	-- A single restrained particle emitter on the primary part for mobile budget.
	if mutationDef.Particles then
		local host = model.PrimaryPart
		if host then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "MutationSparkle"
			emitter.Rate = 6 -- low rate: mobile-friendly, not a particle storm
			emitter.Lifetime = NumberRange.new(0.8, 1.4)
			emitter.Speed = NumberRange.new(0.5, 1.5)
			emitter.Size = NumberSequence.new(0.4)
			emitter.Transparency = NumberSequence.new(0.3)
			if overrideColor then
				emitter.Color = ColorSequence.new(overrideColor)
			end
			emitter.Parent = host
		end
	end
end

-- Build a creature Model (NOT parented). Kept signature-compatible with the stub.
function CreatureModelFactory.build(
	creatureId: string,
	mutationId: string,
	stageIndex: number
): Model?
	local creatureDef = CreatureDefinitions.get(creatureId)
	if not creatureDef then
		return nil
	end
	local mutationDef = MutationDefinitions.get(mutationId)
	local stage = clampStage(stageIndex)

	local bodyColor = stageColor(creatureDef, stage)
	local accentColor = CreatureModelFactory.toColor3(creatureDef.AccentColor)

	local builder = BUILDERS[creatureDef.ModelBuilderId] or buildBlob
	local specs = if stage < SIMPLE_BELOW_STAGE
		then buildEgg(bodyColor, accentColor)
		else builder(bodyColor, accentColor)

	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute("CreatureId", creatureId)
	model:SetAttribute("MutationId", mutationId)
	model:SetAttribute("StageIndex", stage)

	-- Combined scale: stage progress × creature BaseScale × mutation ScaleMultiplier.
	local mutationScale = if mutationDef then mutationDef.ScaleMultiplier else 1
	local scale = STAGE_SCALE[stage + 1] * creatureDef.BaseScale * mutationScale

	local primary: BasePart? = nil
	for _, spec in specs do
		local part: Part = spec[1]
		local offset: Vector3 = spec[2]
		part.Size = part.Size * scale
		-- Build relative to the model origin; the caller pins origin to the slot.
		part.CFrame = CFrame.new(offset * scale)
		part.Parent = model
		if not primary then
			primary = part
		end
	end
	model.PrimaryPart = primary

	-- Weld every part to the primary so the model moves as one rigid unit.
	if primary then
		for _, part in model:GetChildren() do
			if part:IsA("BasePart") and part ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = primary
			end
		end
	end

	applyMutation(model, mutationDef)

	return model
end

-- Remove any existing creature model parented under a slot anchor (cleanup, §21).
local function clearExisting(slotAnchor: Instance)
	local existing = slotAnchor:FindFirstChild(MODEL_NAME)
	if existing then
		existing:Destroy()
	end
end

-- Build a creature and parent it ON TOP of the slot anchor so it replicates to
-- clients (INTEGRATION_CONTRACT §4). Cleans up any prior model first. Returns the
-- model, or nil if the creature id is unknown.
function CreatureModelFactory.spawnAt(
	slotAnchor: BasePart,
	creatureId: string,
	mutationId: string,
	stageIndex: number
): Model?
	clearExisting(slotAnchor)

	local model = CreatureModelFactory.build(creatureId, mutationId, stageIndex)
	if not model then
		return nil
	end

	-- Pivot the model so its base sits on the top face of the slot anchor.
	local topY = slotAnchor.Position.Y + slotAnchor.Size.Y / 2
	local base = CFrame.new(slotAnchor.Position.X, topY, slotAnchor.Position.Z)
	model:PivotTo(base)
	model.Parent = slotAnchor

	return model
end

-- Rebuild a creature model at a new stage in-place. Reads the creature/mutation from
-- the model's attributes, replaces it under the same parent, and returns the new
-- model (or the original if it cannot be rebuilt).
function CreatureModelFactory.updateStage(model: Model, stageIndex: number): Model
	local creatureId = model:GetAttribute("CreatureId")
	local mutationId = model:GetAttribute("MutationId")
	local parent = model.Parent
	if typeof(creatureId) ~= "string" or typeof(mutationId) ~= "string" or not parent then
		return model
	end

	if parent:IsA("BasePart") then
		local rebuilt = CreatureModelFactory.spawnAt(parent, creatureId, mutationId, stageIndex)
		if rebuilt then
			return rebuilt
		end
	end
	return model
end

return CreatureModelFactory
