--!strict
-- TimeUtility — time helpers. Uses os.time/os.clock only (available in both
-- Roblox and Lune), so it stays Lune-testable.

local TimeUtility = {}

-- Absolute server time in seconds. ALWAYS use this for growth math (§9, §15);
-- never trust a client clock.
function TimeUtility.now(): number
	return os.time()
end

-- Clamp `n` into [min, max].
function TimeUtility.clamp(n: number, min: number, max: number): number
	if n < min then
		return min
	elseif n > max then
		return max
	end
	return n
end

-- Seconds remaining until readyAt (never negative).
function TimeUtility.remaining(readyAt: number, now: number): number
	return math.max(0, readyAt - now)
end

-- True if a crop planted with this readyAt is finished at `now`.
function TimeUtility.isReady(readyAt: number, now: number): boolean
	return now >= readyAt
end

-- Human-readable short duration, e.g. 95 -> "1m 35s", 3600 -> "1h 0m".
function TimeUtility.format(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return string.format("%ds", seconds)
	elseif seconds < 3600 then
		return string.format("%dm %ds", seconds // 60, seconds % 60)
	end
	return string.format("%dh %dm", seconds // 3600, (seconds % 3600) // 60)
end

return TimeUtility
