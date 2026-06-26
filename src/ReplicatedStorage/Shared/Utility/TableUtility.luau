--!strict
-- TableUtility — small pure table helpers. Dependency-free → Lune-testable.

local TableUtility = {}

-- Recursive deep copy (handles nested tables; ignores metatables on purpose, §13).
function TableUtility.deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in value :: any do
		result[k] = TableUtility.deepCopy(v)
	end
	return (result :: any) :: T
end

-- Shallow-merge `overrides` into a copy of `base` (overrides win). One level deep.
function TableUtility.merge(base: { [any]: any }, overrides: { [any]: any }): { [any]: any }
	local result = TableUtility.deepCopy(base)
	for k, v in overrides do
		result[k] = v
	end
	return result
end

-- Count keys in a (possibly non-array) table.
function TableUtility.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

-- Reconcile `data` against `template`: ensures every key in template exists in
-- data (deep-copying defaults for missing keys). Returns whether anything changed.
-- Used by the data layer's default-profile reconciliation (§14).
function TableUtility.reconcile(data: { [any]: any }, template: { [any]: any }): boolean
	local changed = false
	for key, templateValue in template do
		if data[key] == nil then
			data[key] = TableUtility.deepCopy(templateValue)
			changed = true
		elseif typeof(templateValue) == "table" and typeof(data[key]) == "table" then
			if TableUtility.reconcile(data[key], templateValue) then
				changed = true
			end
		end
	end
	return changed
end

return TableUtility
