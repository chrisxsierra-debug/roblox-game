--!strict
-- EconomyService — coins, slot purchases, seed unlocks (§10, §17).
-- TRACK A. STUB. Reads EconomyConfig + SeedTierDefinitions (server-only require).
--
-- Responsibilities:
--   * addCoins / spendCoins with clamping; keep LifetimeCoins in sync on earn.
--   * BuySlot validation (§17): < MaxSlots, cost matches server config, can afford.
--   * Re-check seed-tier unlocks whenever LifetimeCoins increases (§10).
--   * NEVER trust client-sent amounts.

local EconomyService = {}
EconomyService.Name = "EconomyService"

-- TODO(Track A): add coins, bump LifetimeCoins on positive earns, mark dirty.
function EconomyService.addCoins(_userId: number, _amount: number, _isEarning: boolean) end

-- TODO(Track A): spend coins if affordable; return success.
function EconomyService.trySpend(_userId: number, _amount: number): boolean
	return false
end

function EconomyService.Init() end
function EconomyService.Start() end

return EconomyService
