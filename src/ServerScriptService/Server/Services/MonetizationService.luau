--!strict
-- MonetizationService — game passes + ProcessReceipt (§23, §24). TRACK A. STUB.
--
-- Game passes: cache ownership of DoubleGrowth / AutoCollect / GoldenPlotVIP.
-- ProcessReceipt MUST be: server-authoritative, idempotent, retry-safe, resistant
-- to duplicate grants, logged (§24). For slot-targeted products (Instant Grow):
-- store a short-lived pending-purchase context, verify the slot still exists +
-- belongs to the player on receipt, grant once, record receipt id, clear context.
-- If the slot is gone, grant a safe fallback (e.g. a stored Instant-Grow token).
-- Skip any product/pass whose id is 0 (MonetizationConfig.isConfigured).

local MonetizationService = {}
MonetizationService.Name = "MonetizationService"

-- TODO(Track A): true if player owns the pass (cached). Returns false for id 0.
function MonetizationService.ownsPass(_userId: number, _passKey: string): boolean
	return false
end

function MonetizationService.Init()
	-- TODO(Track A): set MarketplaceService.ProcessReceipt; prefetch pass ownership.
end

function MonetizationService.Start() end

return MonetizationService
