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

return RemoteValidator
