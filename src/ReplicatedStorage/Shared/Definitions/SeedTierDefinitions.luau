--!strict
-- SeedTierDefinitions — the 5 seed tiers (§10). Single source of truth for
-- grow durations, seed costs, base sell values, and unlock thresholds.
-- Dependency-free → Lune-testable.

export type SeedTierDefinition = {
	Tier: number,
	DisplayName: string,
	GrowDuration: number, -- seconds
	SeedCost: number, -- Coins to plant
	BaseSellValue: number, -- Coins, before creature/mutation/rebirth/VIP multipliers
	UnlockLifetimeCoins: number, -- Lifetime Coins required to unlock (§10)
	UnlockOnFirstRebirth: boolean, -- also unlocked once the player rebirths once
}

local SeedTierDefinitions = {}

-- Indexed by tier number (1..5).
SeedTierDefinitions.Tiers = {
	[1] = {
		Tier = 1,
		DisplayName = "Common",
		GrowDuration = 30,
		SeedCost = 5,
		BaseSellValue = 10,
		UnlockLifetimeCoins = 0,
		UnlockOnFirstRebirth = false,
	},
	[2] = {
		Tier = 2,
		DisplayName = "Uncommon",
		GrowDuration = 90,
		SeedCost = 25,
		BaseSellValue = 40,
		UnlockLifetimeCoins = 100,
		UnlockOnFirstRebirth = false,
	},
	[3] = {
		Tier = 3,
		DisplayName = "Rare",
		GrowDuration = 300,
		SeedCost = 100,
		BaseSellValue = 150,
		UnlockLifetimeCoins = 1000,
		UnlockOnFirstRebirth = false,
	},
	[4] = {
		Tier = 4,
		DisplayName = "Epic",
		GrowDuration = 900,
		SeedCost = 400,
		BaseSellValue = 600,
		UnlockLifetimeCoins = 5000,
		UnlockOnFirstRebirth = false,
	},
	[5] = {
		Tier = 5,
		DisplayName = "Legendary",
		GrowDuration = 3600,
		SeedCost = 2000,
		BaseSellValue = 3000,
		UnlockLifetimeCoins = 15000,
		UnlockOnFirstRebirth = true,
	},
} :: { [number]: SeedTierDefinition }

SeedTierDefinitions.MaxTier = 5

function SeedTierDefinitions.get(tier: number): SeedTierDefinition?
	return SeedTierDefinitions.Tiers[tier]
end

-- True if `tier` is unlocked given the player's lifetime coins and rebirth count (§10).
-- Unlocks are NEVER lost on rebirth, so this only ever grows.
function SeedTierDefinitions.isUnlocked(
	tier: number,
	lifetimeCoins: number,
	rebirths: number
): boolean
	local def = SeedTierDefinitions.Tiers[tier]
	if not def then
		return false
	end
	if def.UnlockOnFirstRebirth and rebirths >= 1 then
		return true
	end
	return lifetimeCoins >= def.UnlockLifetimeCoins
end

return SeedTierDefinitions
