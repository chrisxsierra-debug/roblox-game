--!strict
-- AssetConfig — sound/particle/image asset IDs in one place (§28).
-- The game MUST function when these are 0 (skip the effect, don't error).

local AssetConfig = {}

-- Sound asset ids (rbxassetid). 0 = no sound, skip playback.
AssetConfig.Sounds = {
	Plant = 0,
	StageChange = 0,
	Ready = 0,
	Harvest = 0,
	CoinTick = 0,
	MutationRare = 0,
	ButtonClick = 0,
}

-- Image asset ids for UI icons. 0 = use a plain colored frame fallback.
AssetConfig.Images = {
	CoinIcon = 0,
	RebirthIcon = 0,
	LockIcon = 0,
}

function AssetConfig.isConfigured(id: number?): boolean
	return id ~= nil and id ~= 0
end

return AssetConfig
