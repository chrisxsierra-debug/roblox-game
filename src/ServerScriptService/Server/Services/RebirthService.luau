--!strict
-- RebirthService — rebirth flow (§10, §17). TRACK A. STUB.
--
-- Requirement (server-computed): EconomyConfig.getRebirthRequirement(rebirths).
-- On rebirth: reset Coins->20, UnlockedSlots->2, clear Slots; PRESERVE
-- LifetimeCoins, seed unlocks, tutorial, purchases; +1 Rebirth (+0.5x income);
-- unlock Tier 5 after first rebirth. Requires a short-lived confirmation token (§17).

local RebirthService = {}
RebirthService.Name = "RebirthService"

-- TODO(Track A): issue a short-lived confirmation token for a valid request.
function RebirthService.requestConfirmation(_player: Player): string?
	return nil
end

-- TODO(Track A): validate token + requirement, then perform the reset.
function RebirthService.perform(_player: Player, _token: string): (boolean, string?)
	return false, "not_implemented"
end

function RebirthService.Init() end
function RebirthService.Start() end

return RebirthService
