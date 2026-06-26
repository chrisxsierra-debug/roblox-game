--!strict
-- FarmClient — the single client entry point (§19). Loads controllers and drives
-- their Init()/Start() lifecycle, mirroring ServerBootstrap.

local controllersFolder = script.Parent:WaitForChild("Client"):WaitForChild("Controllers")

-- UIController first (builds the screen), then the rest.
local CONTROLLER_ORDER = {
	"UIController",
	"FarmController",
	"TutorialController",
	"EffectsController",
}

local loaded: { [string]: any } = {}

for _, name in CONTROLLER_ORDER do
	local moduleScript = controllersFolder:FindFirstChild(name)
	if not moduleScript then
		warn(`[FarmClient] missing controller: {name}`)
		continue
	end
	local ok, controller = pcall(require, moduleScript)
	if not ok then
		warn(`[FarmClient] failed to require {name}: {controller}`)
		continue
	end
	loaded[name] = controller
	if type(controller) == "table" and type(controller.Init) == "function" then
		local initOk, err = pcall(controller.Init, controller)
		if not initOk then
			warn(`[FarmClient] {name}:Init() errored: {err}`)
		end
	end
end

for _, name in CONTROLLER_ORDER do
	local controller = loaded[name]
	if type(controller) == "table" and type(controller.Start) == "function" then
		local startOk, err = pcall(controller.Start, controller)
		if not startOk then
			warn(`[FarmClient] {name}:Start() errored: {err}`)
		end
	end
end

print("[FarmClient] Brainrot Farm client initialized.")
