--!strict
-- WeightedRandom — weighted selection helpers (§7 creature rolls, §8 mutation rolls).
-- Dependency-free and deterministic when you pass your own `rng`, which makes it
-- straightforward to unit-test with Lune.

local WeightedRandom = {}

export type Weighted = { Weight: number }

-- Sum the `.Weight` field of every item.
function WeightedRandom.totalWeight<T>(items: { T }, getWeight: (T) -> number): number
	local total = 0
	for _, item in items do
		total += getWeight(item)
	end
	return total
end

-- Choose one item proportional to its weight.
--   items    : array of candidates (must be non-empty)
--   getWeight: returns the (non-negative) weight of an item
--   rng      : optional () -> number in [0,1); defaults to math.random.
-- Returns the chosen item and its index.
function WeightedRandom.choose<T>(
	items: { T },
	getWeight: (T) -> number,
	rng: (() -> number)?
): (T, number)
	assert(#items > 0, "WeightedRandom.choose: items must be non-empty")
	local total = WeightedRandom.totalWeight(items, getWeight)
	assert(total > 0, "WeightedRandom.choose: total weight must be > 0")

	local roll = (rng or math.random)() * total
	local cumulative = 0
	for index, item in items do
		cumulative += getWeight(item)
		if roll < cumulative then
			return item, index
		end
	end
	-- Floating-point fallthrough: return the last item.
	return items[#items], #items
end

return WeightedRandom
