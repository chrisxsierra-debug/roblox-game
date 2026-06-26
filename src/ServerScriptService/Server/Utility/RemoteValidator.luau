--!strict
-- RemoteValidator — argument validation helpers for remote handlers (§17). TRACK A.
-- Partially implemented: the type guards are real; wire them into FarmService etc.
--
-- The server must accept ONLY a slot index and a seed tier from the client for
-- planting — never coins, payouts, durations, ready times, creature/mutation ids,
-- multipliers, or ownership (§17).

local RemoteValidator = {}

-- True if `v` is an integer within [min, max].
function RemoteValidator.isIntInRange(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= min and v <= max
end

-- Validate a PlantSeed payload shape (range of slot enforced by caller vs
-- UnlockedSlots). maxTier should be SeedTierDefinitions.MaxTier.
function RemoteValidator.validatePlant(
	slotIndex: any,
	seedTier: any,
	maxSlots: number,
	maxTier: number
): boolean
	return RemoteValidator.isIntInRange(slotIndex, 1, maxSlots)
		and RemoteValidator.isIntInRange(seedTier, 1, maxTier)
end

-- Validate a single slot-index payload (Harvest / Instant-Grow target / etc.).
function RemoteValidator.validateSlotIndex(slotIndex: any, maxSlots: number): boolean
	return RemoteValidator.isIntInRange(slotIndex, 1, maxSlots)
end

-- True if `v` is a finite number within [min, max] (allows fractions, e.g. volumes).
function RemoteValidator.isNumberInRange(v: any, min: number, max: number): boolean
	return type(v) == "number" and v == v and v >= min and v <= max
end

-- Validate an UpdateSettings payload shape (contract §3): a table with
-- MusicVolume/SoundVolume in [0, 1] and a boolean ReducedEffects. Returns the
-- sanitized settings on success, or nil if the shape is invalid.
function RemoteValidator.validateSettings(settings: any): {
	MusicVolume: number,
	SoundVolume: number,
	ReducedEffects: boolean,
}?
	if type(settings) ~= "table" then
		return nil
	end
	if not RemoteValidator.isNumberInRange(settings.MusicVolume, 0, 1) then
		return nil
	end
	if not RemoteValidator.isNumberInRange(settings.SoundVolume, 0, 1) then
		return nil
	end
	if type(settings.ReducedEffects) ~= "boolean" then
		return nil
	end
	return {
		MusicVolume = settings.MusicVolume,
		SoundVolume = settings.SoundVolume,
		ReducedEffects = settings.ReducedEffects,
	}
end

return RemoteValidator
