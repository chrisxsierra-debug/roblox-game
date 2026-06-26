--!strict
-- CreatureDefinitions — the 9 ORIGINAL placeholder creatures (§7).
-- All designs are original; do NOT add copyrighted/real meme characters (§1.12-13).
--
-- Colors are {r,g,b} 0-255 triples (converted to Color3 by CreatureModelFactory),
-- so this module stays dependency-free and Lune-testable.
-- `ModelBuilderId` selects which procedural builder the factory uses.

export type CreatureDefinition = {
	Id: string,
	DisplayName: string,
	Description: string,
	SeedTier: number,
	BaseWeight: number, -- selection weight WITHIN its seed tier
	BaseScale: number,
	StageColors: { { number } }, -- one {r,g,b} per growth stage (length = GrowthStageCount)
	FinalColor: { number },
	AccentColor: { number },
	ModelBuilderId: string,
	BaseValueMultiplier: number, -- multiplies the seed tier's BaseSellValue
	RevealText: string,
}

local CreatureDefinitions = {}

CreatureDefinitions.List = {
	-- ── Tier 1 ────────────────────────────────────────────────────────────
	{
		Id = "ToasterTurtle",
		DisplayName = "Toaster Turtle",
		Description = "A turtle whose shell is a slightly burnt toaster.",
		SeedTier = 1,
		BaseWeight = 40,
		BaseScale = 1.0,
		StageColors = { { 120, 180, 90 }, { 130, 190, 100 }, { 140, 200, 110 }, { 150, 210, 120 } },
		FinalColor = { 150, 210, 120 },
		AccentColor = { 200, 200, 205 },
		ModelBuilderId = "Quadruped",
		BaseValueMultiplier = 1.0,
		RevealText = "Pop! A Toaster Turtle.",
	},
	{
		Id = "TelevisionFrog",
		DisplayName = "Television Frog",
		Description = "A frog with a tiny static-filled TV for a head.",
		SeedTier = 1,
		BaseWeight = 35,
		BaseScale = 0.9,
		StageColors = { { 90, 160, 120 }, { 95, 170, 130 }, { 100, 180, 140 }, { 110, 190, 150 } },
		FinalColor = { 110, 190, 150 },
		AccentColor = { 60, 60, 70 },
		ModelBuilderId = "Blob",
		BaseValueMultiplier = 1.1,
		RevealText = "*bzzt* A Television Frog.",
	},
	{
		Id = "TrafficConeChicken",
		DisplayName = "Traffic Cone Chicken",
		Description = "A chicken wearing a giant traffic cone like a hat.",
		SeedTier = 1,
		BaseWeight = 25,
		BaseScale = 0.95,
		StageColors = { { 235, 235, 220 }, { 240, 240, 225 }, { 245, 245, 230 }, { 250, 250, 235 } },
		FinalColor = { 250, 250, 235 },
		AccentColor = { 255, 120, 30 },
		ModelBuilderId = "Biped",
		BaseValueMultiplier = 1.25,
		RevealText = "Cluck! A Traffic Cone Chicken.",
	},

	-- ── Tier 2 ────────────────────────────────────────────────────────────
	{
		Id = "VacuumShark",
		DisplayName = "Vacuum Shark",
		Description = "A land shark with a vacuum-nozzle snout.",
		SeedTier = 2,
		BaseWeight = 55,
		BaseScale = 1.2,
		StageColors = { { 120, 140, 160 }, { 110, 130, 155 }, { 100, 120, 150 }, { 90, 115, 150 } },
		FinalColor = { 90, 115, 150 },
		AccentColor = { 40, 50, 60 },
		ModelBuilderId = "Blob",
		BaseValueMultiplier = 1.0,
		RevealText = "Vrrrm! A Vacuum Shark.",
	},
	{
		Id = "BananaKnight",
		DisplayName = "Banana Knight",
		Description = "A banana in cardboard armor, sworn to peel.",
		SeedTier = 2,
		BaseWeight = 45,
		BaseScale = 1.0,
		StageColors = { { 230, 215, 90 }, { 235, 220, 95 }, { 240, 225, 100 }, { 245, 230, 110 } },
		FinalColor = { 245, 230, 110 },
		AccentColor = { 170, 130, 80 },
		ModelBuilderId = "Biped",
		BaseValueMultiplier = 1.3,
		RevealText = "For the snack! A Banana Knight.",
	},

	-- ── Tier 3 ────────────────────────────────────────────────────────────
	{
		Id = "DiscoGiraffe",
		DisplayName = "Disco Giraffe",
		Description = "A giraffe whose spots are spinning disco lights.",
		SeedTier = 3,
		BaseWeight = 55,
		BaseScale = 1.6,
		StageColors = { { 220, 180, 90 }, { 225, 170, 110 }, { 230, 160, 140 }, { 235, 150, 170 } },
		FinalColor = { 235, 150, 170 },
		AccentColor = { 120, 220, 255 },
		ModelBuilderId = "Tall",
		BaseValueMultiplier = 1.0,
		RevealText = "Boogie! A Disco Giraffe.",
	},
	{
		Id = "RefrigeratorGorilla",
		DisplayName = "Refrigerator Gorilla",
		Description = "A gorilla with the build (and chill) of a fridge.",
		SeedTier = 3,
		BaseWeight = 45,
		BaseScale = 1.7,
		StageColors = { { 200, 205, 210 }, { 195, 200, 208 }, { 190, 195, 205 }, { 185, 192, 205 } },
		FinalColor = { 185, 192, 205 },
		AccentColor = { 70, 75, 85 },
		ModelBuilderId = "Biped",
		BaseValueMultiplier = 1.35,
		RevealText = "*hmmmm* A Refrigerator Gorilla.",
	},

	-- ── Tier 4 ────────────────────────────────────────────────────────────
	{
		Id = "MoonCow",
		DisplayName = "Moon Cow",
		Description = "A floating cow with a tiny moon in orbit.",
		SeedTier = 4,
		BaseWeight = 100,
		BaseScale = 2.0,
		StageColors = { { 235, 235, 245 }, { 230, 230, 245 }, { 225, 225, 248 }, { 220, 222, 250 } },
		FinalColor = { 220, 222, 250 },
		AccentColor = { 180, 185, 210 },
		ModelBuilderId = "Quadruped",
		BaseValueMultiplier = 1.0,
		RevealText = "Moo... in space. A Moon Cow.",
	},

	-- ── Tier 5 ────────────────────────────────────────────────────────────
	{
		Id = "CosmicShoppingCartDragon",
		DisplayName = "Cosmic Shopping Cart Dragon",
		Description = "A dragon built from shopping carts and glowing cosmic parts.",
		SeedTier = 5,
		BaseWeight = 100,
		BaseScale = 2.6,
		StageColors = { { 120, 90, 200 }, { 130, 90, 215 }, { 140, 90, 230 }, { 150, 90, 245 } },
		FinalColor = { 150, 90, 245 },
		AccentColor = { 90, 230, 255 },
		ModelBuilderId = "Tall",
		BaseValueMultiplier = 1.0,
		RevealText = "CLATTER-ROAR! A Cosmic Shopping Cart Dragon.",
	},
} :: { CreatureDefinition }

CreatureDefinitions.ById = {} :: { [string]: CreatureDefinition }
for _, c in CreatureDefinitions.List do
	CreatureDefinitions.ById[c.Id] = c
end

function CreatureDefinitions.get(id: string): CreatureDefinition?
	return CreatureDefinitions.ById[id]
end

-- All creatures belonging to a given seed tier (used for weighted rolls).
function CreatureDefinitions.getByTier(tier: number): { CreatureDefinition }
	local result = {}
	for _, c in CreatureDefinitions.List do
		if c.SeedTier == tier then
			table.insert(result, c)
		end
	end
	return result
end

return CreatureDefinitions
