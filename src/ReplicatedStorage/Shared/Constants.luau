--!strict
-- Constants — stable identifiers shared by client and server.
-- Dependency-free.

local Constants = {}

-- Remote names (§16). Keep client and server referencing these, never literals.
Constants.Remotes = {
	-- Client → Server
	PlantSeed = "PlantSeed",
	HarvestSlot = "HarvestSlot",
	BuySlot = "BuySlot",
	RequestRebirth = "RequestRebirth",
	RequestInstantGrowPurchase = "RequestInstantGrowPurchase",
	RequestFertilizerPurchase = "RequestFertilizerPurchase",
	RequestCoinPackPurchase = "RequestCoinPackPurchase",
	UpdateSettings = "UpdateSettings",

	-- Server → Client
	DataUpdated = "DataUpdated",
	SlotUpdated = "SlotUpdated",
	FarmAssigned = "FarmAssigned",
	Notification = "Notification",
	TutorialUpdated = "TutorialUpdated",
	PlayEffect = "PlayEffect",
	PurchaseResult = "PurchaseResult",
}

-- RemoteFunctions (used sparingly, §16)
Constants.RemoteFunctions = {
	RequestData = "RequestData",
}

-- Which remotes are RemoteEvents from client→server (the rest of Constants.Remotes
-- are server→client RemoteEvents). Used by the Remotes builder + RemoteValidator.
Constants.ClientToServerEvents = {
	"PlantSeed",
	"HarvestSlot",
	"BuySlot",
	"RequestRebirth",
	"RequestInstantGrowPurchase",
	"RequestFertilizerPurchase",
	"RequestCoinPackPurchase",
	"UpdateSettings",
}

Constants.ServerToClientEvents = {
	"DataUpdated",
	"SlotUpdated",
	"FarmAssigned",
	"Notification",
	"TutorialUpdated",
	"PlayEffect",
	"PurchaseResult",
}

-- Attribute / collection-tag keys used on plot instances (§11). The WORLD writes
-- these onto plot/slot parts; the CLIENT reads them to locate its slots in 3D.
Constants.Attributes = {
	PlotId = "PlotId",
	OwnerUserId = "OwnerUserId",
	SlotIndex = "SlotIndex",
	Locked = "Locked", -- true on a slot marker that isn't unlocked yet
}

Constants.Tags = {
	Plot = "BrainrotPlot",
	GrowSlot = "BrainrotGrowSlot",
}

-- Workspace folder names (§22). World generation lives under these; idempotent.
Constants.World = {
	GeneratedFolder = "GeneratedWorld",
	PlotsFolder = "Plots",
	AuthoredMapFolder = "Map", -- if present, skip placeholder generation
}

-- PlayEffect kinds (§28). Server sends Constants.Effects.X as EffectPayload.Kind.
Constants.Effects = {
	Plant = "Plant",
	StageChange = "StageChange",
	Ready = "Ready",
	Harvest = "Harvest",
	Mutation = "Mutation",
}

-- Rate-limit windows (requests per second) per remote (§17).
Constants.RateLimits = {
	PlantSeed = 5,
	HarvestSlot = 8,
	BuySlot = 4,
	RequestRebirth = 2,
	UpdateSettings = 3,
	Default = 10,
}

return Constants
