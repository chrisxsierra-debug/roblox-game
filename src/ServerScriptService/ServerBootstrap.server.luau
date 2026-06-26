--!strict
-- ServerBootstrap — the single server entry point.
-- Loads every service in a deterministic order and drives the Init()/Start()
-- lifecycle (§26). Adding a service = add its name to SERVICE_ORDER below.

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")

-- Order matters: data must be ready before anything that reads it; world/plot
-- before farm logic; monetization/admin last.
local SERVICE_ORDER = {
	"PlayerDataService",
	"WorldService",
	"PlotService",
	"GrowthService",
	"EconomyService",
	"FarmService",
	"RebirthService",
	"TutorialService",
	"AutoCollectService",
	"MonetizationService",
	"AdminService",
}

local loaded: { [string]: any } = {}

-- Require + Init in order.
for _, name in SERVICE_ORDER do
	local moduleScript = Services:FindFirstChild(name)
	if not moduleScript then
		warn(`[ServerBootstrap] missing service module: {name}`)
		continue
	end
	local ok, service = pcall(require, moduleScript)
	if not ok then
		warn(`[ServerBootstrap] failed to require {name}: {service}`)
		continue
	end
	loaded[name] = service
	if type(service) == "table" and type(service.Init) == "function" then
		local initOk, err = pcall(service.Init, service)
		if not initOk then
			warn(`[ServerBootstrap] {name}:Init() errored: {err}`)
		end
	end
end

-- Then Start in the same order.
for _, name in SERVICE_ORDER do
	local service = loaded[name]
	if type(service) == "table" and type(service.Start) == "function" then
		local startOk, err = pcall(service.Start, service)
		if not startOk then
			warn(`[ServerBootstrap] {name}:Start() errored: {err}`)
		end
	end
end

print("[ServerBootstrap] Brainrot Farm server initialized.")
