--!strict
-- Types — shared type definitions for the whole project (§12-13).
-- This module exports types only and returns an empty table at runtime, so it
-- is safe to require from anywhere.

export type FarmSlot = {
	SeedTierId: number?,
	CreatureId: string?,
	MutationId: string?,
	PlantedAt: number?, -- os.time() at planting (absolute, for offline growth §15)
	ReadyAt: number?, -- os.time() when the crop finishes
	GrowthSpeedMultiplier: number?, -- combined multiplier applied at plant time (§18)
}

export type TutorialState = {
	Completed: boolean,
	Step: number,
}

export type Statistics = {
	TotalPlanted: number,
	TotalHarvested: number,
	TotalCoinsEarned: number,
	HighestMutationRank: number,
	PlaySeconds: number,
}

export type Settings = {
	MusicVolume: number,
	SoundVolume: number,
	ReducedEffects: boolean,
}

export type Purchases = {
	ProcessedReceipts: { [string]: number },
}

export type PlayerData = {
	DataVersion: number,

	Coins: number,
	LifetimeCoins: number,
	Rebirths: number,

	UnlockedSlots: number,
	HighestSeedTier: number,

	Slots: { FarmSlot },

	Tutorial: TutorialState,
	Statistics: Statistics,
	Settings: Settings,
	Purchases: Purchases,

	FertilizerCharges: number,

	LastSeenAt: number,
}

-- A sanitized snapshot the server sends to the client (§16). Never includes
-- internal/security fields.
export type DataSnapshot = {
	Coins: number,
	LifetimeCoins: number,
	Rebirths: number,
	IncomeMultiplier: number,
	UnlockedSlots: number,
	HighestSeedTier: number,
	Slots: { FarmSlot },
	Tutorial: TutorialState,
	FertilizerCharges: number,
}

return {}
