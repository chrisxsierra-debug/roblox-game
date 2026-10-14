--!strict
-- FunnelRunnersConfig.luau
-- Directly mapped from Funnel Runners (StormEscape) UE5 decompiled debug symbols
-- Reflects FTornadoGenerationParameters, EMinorTornadoState, and EFinalTornadoState

export type TornadoParameters = {
	Name: string,
	Category: string,
	FunnelTopRadius: number,
	FunnelBottomRadius: number,
	FunnelHeight: number,
	SuctionRadius: number,
	SuctionForce: number,
	UpdraftLift: number,
	OrbitSpeed: number,
	CoreDamagePerSecond: number,
	WindSpeedMin: number,
	WindSpeedMax: number,
	VortexColor: Color3,
}

local FunnelRunnersConfig = {
	-- States directly from decompiled EMinorTornadoState & EFinalTornadoState
	TornadoStates = {
		Forecast = "Forecast",
		Spawned = "Spawned",
		Active = "Active",
		FinalArrival = "FinalArrival",
		Devastating = "Devastating",
		Decaying = "Decaying",
		Despawned = "Despawned",
	},

	-- FTornadoGenerationParameters for Minor vs Final Tornado
	MinorTornado = {
		Name = "Minor Funnel (EF2)",
		Category = "EF2",
		FunnelTopRadius = 24,
		FunnelBottomRadius = 6,
		FunnelHeight = 90,
		SuctionRadius = 65,
		SuctionForce = 120,
		UpdraftLift = 140,
		OrbitSpeed = 3.5,
		CoreDamagePerSecond = 20,
		WindSpeedMin = 112,
		WindSpeedMax = 135,
		VortexColor = Color3.fromRGB(110, 115, 120),
	} :: TornadoParameters,

	FinalTornado = {
		Name = "Final Monster Wedge (EF5)",
		Category = "EF5",
		FunnelTopRadius = 65,
		FunnelBottomRadius = 18,
		FunnelHeight = 160,
		SuctionRadius = 135,
		SuctionForce = 260,
		UpdraftLift = 280,
		OrbitSpeed = 6.0,
		CoreDamagePerSecond = 75,
		WindSpeedMin = 210,
		WindSpeedMax = 295,
		VortexColor = Color3.fromRGB(35, 40, 48),
	} :: TornadoParameters,

	-- Round Timings from ATornadoManager
	Manager = {
		ForecastDuration = 25,     -- Chasers prepare and watch Doppler
		MinorTornadoDuration = 70,  -- First wave minor tornado
		FinalWarningDuration = 30,  -- Emergency sirens blare, countdown to EF5
		FinalTornadoDuration = 90,  -- Devastating final monster tornado
		IntermissionDuration = 15,  -- Score calculation and cleanup
	},

	-- APortableDoppler parameters
	Doppler = {
		ScanCooldown = 2.5,
		BaseResearchTokens = 25,
		MaxScanDistance = 220,
		SignalLossDistance = 35, -- Signal static noise when right in the eye
	},

	-- House Destruction Parameters from UTornadoHouseDamageComponent
	Destruction = {
		DebrisScanRing = 80,
		TossMinVelocity = 70,
		TossMaxVelocity = 150,
		OrbitDurationSeconds = 4.5, -- How long debris/players orbit before being thrown
	},
}

return FunnelRunnersConfig

