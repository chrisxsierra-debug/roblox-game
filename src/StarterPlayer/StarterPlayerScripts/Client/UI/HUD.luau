--!strict
-- HUD — always-on counters (§19). TRACK B. STUB.
-- Coins, progress-to-next-seed bar, rebirth count, income multiplier, current
-- seed tier, and the Shop button. Large, top-anchored, safe-area aware.

local HUD = {}

-- TODO(Track B): create(parentGui) -> { setData = function(snapshot) ... } controller.
function HUD.create(_parent: Instance): { [string]: any }
	return {}
end

return HUD
