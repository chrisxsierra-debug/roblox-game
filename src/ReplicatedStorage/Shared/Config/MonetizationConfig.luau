--!strict
-- MonetizationConfig — all game-pass and developer-product IDs in ONE place (§23).
--
-- RULES (§23):
--   * Every unconfigured ID defaults to 0.
--   * The game must NOT error when IDs are 0.
--   * The client must NOT show purchase buttons for IDs that are still 0.
--
-- Fill these in from the Creator Dashboard. See MONETIZATION_SETUP.md.

local MonetizationConfig = {}

-- ── Game passes (permanent) ───────────────────────────────────────────────
MonetizationConfig.GamePasses = {
	-- Halves grow duration for FUTURE crops (§18).
	DoubleGrowth = {
		Id = 0,
		Name = "2x Growth Speed",
		SuggestedRobux = 199,
		GrowthMultiplier = 2,
	},
	-- Auto-harvests ready crops while the player is online (§23, server-side §29).
	AutoCollect = {
		Id = 0,
		Name = "Auto-Collect",
		SuggestedRobux = 149,
	},
	-- Golden farm + cosmetic sign + 15% income (applied at most once) + exclusive variant.
	GoldenPlotVIP = {
		Id = 0,
		Name = "Golden Plot VIP",
		SuggestedRobux = 499,
	},
}

-- ── Developer products (consumable) ───────────────────────────────────────
MonetizationConfig.Products = {
	-- Completes one selected planted slot (§24).
	InstantGrow = {
		Id = 0,
		Name = "Instant Grow",
		SuggestedRobux = 29,
	},
	-- Grants 10 fertilizer charges; each removes 25% of a crop's remaining time (§23).
	FertilizerPack = {
		Id = 0,
		Name = "Fertilizer Pack",
		SuggestedRobux = 49,
		Charges = 10,
		TimeReductionPerCharge = 0.25,
	},
	CoinPackSmall = { Id = 0, Name = "Small Coin Pack", SuggestedRobux = 49, Coins = 1000 },
	CoinPackMedium = { Id = 0, Name = "Medium Coin Pack", SuggestedRobux = 199, Coins = 5000 },
	CoinPackLarge = { Id = 0, Name = "Large Coin Pack", SuggestedRobux = 499, Coins = 15000 },
}

-- True if an id has been configured (non-zero). Use this to decide whether to
-- show a purchase button (§23).
function MonetizationConfig.isConfigured(id: number?): boolean
	return id ~= nil and id ~= 0
end

return MonetizationConfig
