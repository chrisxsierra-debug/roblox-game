--!strict
-- RateLimiter — simple per-key sliding-window limiter (§17). TRACK A may extend.
-- Fully implemented: guards remote handlers against spam.
--
-- Usage:
--   local limiter = RateLimiter.new()
--   if not limiter:allow(userId .. ":PlantSeed", 5) then return end  -- 5/sec

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: { _hits: { [string]: { number } } },
	RateLimiter
))

function RateLimiter.new(): RateLimiter
	return setmetatable({ _hits = {} }, RateLimiter)
end

-- Returns true if this call is allowed (and records it), false if `key` has
-- already had `maxPerSecond` calls in the last 1s window.
function RateLimiter.allow(self: RateLimiter, key: string, maxPerSecond: number): boolean
	local now = os.clock()
	local window = self._hits[key]
	if not window then
		window = {}
		self._hits[key] = window
	end

	-- Drop timestamps older than 1 second.
	local cutoff = now - 1
	local kept = {}
	for _, t in window do
		if t > cutoff then
			table.insert(kept, t)
		end
	end

	if #kept >= maxPerSecond then
		self._hits[key] = kept
		return false
	end

	table.insert(kept, now)
	self._hits[key] = kept
	return true
end

-- Forget a key, or every key under a "<prefix>:" namespace (e.g. on player leave,
-- pass the userId to drop all "<userId>:<Action>" windows). Delimiter-aware so
-- clearing userId "12" does NOT also wipe "120", "123", … (their keys start "120:").
function RateLimiter.clear(self: RateLimiter, keyPrefix: string)
	local namespaced = keyPrefix .. ":"
	for key in self._hits do
		if key == keyPrefix or string.sub(key, 1, #namespaced) == namespaced then
			self._hits[key] = nil
		end
	end
end

return RateLimiter
