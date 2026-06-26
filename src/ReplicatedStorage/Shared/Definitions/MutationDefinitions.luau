--!strict
-- MutationDefinitions — the harvest mutation table (§8).
-- Weights are RAW; normalize them in code (do NOT assume they sum to 1).
-- Material is a string name (converted to Enum.Material by CreatureModelFactory).
-- Color is an {r,g,b} 0-255 triple (converted to Color3 by the factory).
-- Dependency-free → Lune-testable.

export type MutationDefinition = {
	Id: string,
	DisplayName: string,
	Weight: number,
	ValueMultiplier: number,
	ScaleMultiplier: number,
	Material: string?, -- e.g. "Glass", "Metal", "Neon"; nil = leave creature default
	Color: { number }?, -- {r,g,b} 0-255; nil = leave creature default
	Particles: boolean,
	RevealMessage: string,
	AnnouncementLevel: number, -- 0 = none, 1 = local toast, 2 = server-wide notify
}

local MutationDefinitions = {}

-- Ordered list (rarest last). Weights from §8.
MutationDefinitions.List = {
	{
		Id = "Normal",
		DisplayName = "Normal",
		Weight = 94.0,
		ValueMultiplier = 1,
		ScaleMultiplier = 1,
		Material = nil,
		Color = nil,
		Particles = false,
		RevealMessage = "",
		AnnouncementLevel = 0,
	},
	{
		Id = "Shiny",
		DisplayName = "Shiny",
		Weight = 4.0,
		ValueMultiplier = 2,
		ScaleMultiplier = 1,
		Material = "Glass",
		Color = nil,
		Particles = true,
		RevealMessage = "It's Shiny!",
		AnnouncementLevel = 1,
	},
	{
		Id = "Golden",
		DisplayName = "Golden",
		Weight = 1.5,
		ValueMultiplier = 5,
		ScaleMultiplier = 1,
		Material = "Metal",
		Color = { 255, 215, 0 },
		Particles = true,
		RevealMessage = "GOLDEN! Worth a fortune!",
		AnnouncementLevel = 1,
	},
	{
		Id = "Giant",
		DisplayName = "Giant",
		Weight = 0.45,
		ValueMultiplier = 10,
		ScaleMultiplier = 1.8,
		Material = nil,
		Color = nil,
		Particles = true,
		RevealMessage = "IT'S ABSOLUTELY MASSIVE!",
		AnnouncementLevel = 2,
	},
	{
		Id = "Glitched",
		DisplayName = "Glitched",
		Weight = 0.05,
		ValueMultiplier = 25,
		ScaleMultiplier = 1.1,
		Material = "ForceField",
		Color = { 120, 255, 180 },
		Particles = true,
		RevealMessage = "?!?! A GLITCHED CREATURE ?!?!",
		AnnouncementLevel = 2,
	},
} :: { MutationDefinition }

-- Map for O(1) lookup by id.
MutationDefinitions.ById = {} :: { [string]: MutationDefinition }
for _, m in MutationDefinitions.List do
	MutationDefinitions.ById[m.Id] = m
end

function MutationDefinitions.get(id: string): MutationDefinition?
	return MutationDefinitions.ById[id]
end

-- Sum of all raw weights (for normalization / weighted selection).
function MutationDefinitions.totalWeight(): number
	local total = 0
	for _, m in MutationDefinitions.List do
		total += m.Weight
	end
	return total
end

return MutationDefinitions
