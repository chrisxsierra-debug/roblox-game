--!strict
-- CreatureModelFactory — builds placeholder creature models from primitive Parts (§21).
-- TRACK C owns this. STUB.
--
-- Build creatures procedurally (Parts + WeldConstraints + PointLights +
-- ParticleEmitters + BillboardGuis) by ModelBuilderId (Quadruped/Biped/Blob/Tall).
-- Convert StageColors/FinalColor/AccentColor ({r,g,b}) via Color3.fromRGB and the
-- mutation Material string via Enum.Material[...]. Each growth stage may simplify
-- the model. Mutation visuals: Shiny=reflective, Golden=gold metallic, Giant=scale,
-- Glitched=restrained particles + offset parts. NO rapid flashing. Clean up models.

local CreatureModelFactory = {}

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

-- TODO(Track C): build(creatureId, mutationId, stageIndex) -> Model
function CreatureModelFactory.build(
	_creatureId: string,
	_mutationId: string,
	_stageIndex: number
): Model?
	return nil
end

return CreatureModelFactory
