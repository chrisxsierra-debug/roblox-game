--!strict
-- FarmService — the core plant/harvest loop + remote handlers (§5, §17).
-- TRACK A. STUB. This is the heart of the server: it validates every PlantSeed
-- and HarvestSlot request and rolls creature/mutation on the server.
--
-- PlantSeed validation (§17): data loaded; owns plot; slot index integer in
--   1..UnlockedSlots; slot empty; seed tier exists + unlocked; can afford; not
--   rate-limited; tutorial allows it. Then: deduct cost, roll creature (weighted
--   within tier via WeightedRandom), roll mutation, compute ReadyAt, store slot,
--   mark dirty, replicate sanitized slot.
-- HarvestSlot validation (§17): valid slot; owned; has crop; now >= ReadyAt;
--   not already harvested; valid defs; not rate-limited. Then: compute payout via
--   EconomyConfig.computePayout, add coins + lifetime, update stats, check unlocks,
--   clear slot, mark dirty, trigger effects, replicate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local FarmService = {}
FarmService.Name = "FarmService"

-- TODO(Track A): full validation + roll + store. Return ok, errorCode.
function FarmService.plant(
	_player: Player,
	_slotIndex: number,
	_seedTier: number
): (boolean, string?)
	return false, "not_implemented"
end

-- TODO(Track A): full validation + payout. Return ok, payout.
function FarmService.harvest(_player: Player, _slotIndex: number): (boolean, number?)
	return false, nil
end

function FarmService.Init()
	-- TODO(Track A): connect Remotes.Events.PlantSeed / HarvestSlot with the
	-- RemoteValidator + RateLimiter guarding every call.
	local _ = Remotes
end

function FarmService.Start() end

return FarmService
