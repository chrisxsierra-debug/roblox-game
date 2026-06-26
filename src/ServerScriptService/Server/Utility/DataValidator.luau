--!strict
-- DataValidator — sanitize/clamp loaded profile data (§14). TRACK A. STUB.
--
-- Responsibilities: coerce malformed numbers, clamp to sane ranges, repair
-- duplicate/oversized Slots arrays, prune the ProcessedReceipts map, and ensure
-- required fields exist (pair with TableUtility.reconcile against the default).

local DataValidator = {}

-- Coerce a value to a finite number within [min, max], falling back to default.
function DataValidator.sanitizeNumber(value: any, default: number, min: number, max: number): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return default
	end
	return math.clamp(value, min, max)
end

-- TODO(Track A): full-profile sanitize (slots, receipts, stats). Returns the
-- (mutated) data and whether anything was repaired.
function DataValidator.sanitizeProfile(data: any): (any, boolean)
	return data, false
end

return DataValidator
