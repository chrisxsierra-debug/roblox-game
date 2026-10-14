--!strict
-- DopplerRadarScreen.client.luau
-- Doppler radar HUD: a heading-up scope showing storm cells and tornadoes, the storm phase with a countdown,
-- the nearest tornado's distance/direction, scan feedback, and warning banners.
-- Storm data comes from attributes under ReplicatedStorage.StormState (published by TornadoManager).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("FunnelRunnersNetwork"))
local Config = require(Shared:WaitForChild("FunnelRunnersConfig"))
local stormState = ReplicatedStorage:WaitForChild("StormState")

local RANGE = 450 -- studs from the middle of the scope to its edge
local SCOPE_SIZE = 196
local SCAN_HINT = "Equip the Doppler and click to scan"

local COLORS = {
	Panel = Color3.fromRGB(14, 18, 22),
	Text = Color3.fromRGB(230, 235, 240),
	Muted = Color3.fromRGB(140, 150, 160),
	Grid = Color3.fromRGB(70, 140, 100),
	Scope = Color3.fromRGB(10, 26, 18),
	Sweep = Color3.fromRGB(110, 255, 170),
	Cell = Color3.fromRGB(240, 190, 60),
	Tornado = Color3.fromRGB(255, 70, 70),
	Clear = Color3.fromRGB(110, 220, 140),
}

-- Pill label, pill color and status line for each phase (%s = time left in the phase)
local PHASES: { [string]: { Label: string, Color: Color3, Status: string } } = {
	Forecast = { Label = "FORECAST", Color = COLORS.Cell, Status = "Storms developing. Touchdown in %s" },
	Minor = { Label = "WARNING", Color = COLORS.Tornado, Status = "Tornado on the ground. %s left" },
	FinalWarning = { Label = "EMERGENCY", Color = COLORS.Tornado, Status = "Violent wedge moving in. Touchdown in %s" },
	Final = { Label = "EMERGENCY", Color = COLORS.Tornado, Status = "EF5 wedge on the ground. %s left" },
	Intermission = { Label = "CLEARING", Color = COLORS.Clear, Status = "Storm clearing. Next storm in %s" },
}

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent: Instance, radius: UDim)
	create("UICorner", { CornerRadius = radius }, parent)
end

local screenGui = create("ScreenGui", { Name = "DopplerRadarHUD", ResetOnSpawn = false }, playerGui)

-- Bottom-right on desktop; middle-right and smaller on phones so it clears the jump button
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local panel = create("Frame", {
	Name = "RadarUnit",
	Size = UDim2.fromOffset(SCOPE_SIZE + 24, SCOPE_SIZE + 124),
	AnchorPoint = if isTouch then Vector2.new(1, 0.5) else Vector2.new(1, 1),
	Position = if isTouch then UDim2.new(1, -12, 0.5, 0) else UDim2.new(1, -16, 1, -16),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
}, screenGui)
round(panel, UDim.new(0, 12))
create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85 }, panel)
if isTouch then
	create("UIScale", { Scale = 0.75 }, panel)
end

-- Header: title and phase pill
create("TextLabel", {
	Text = "DOPPLER",
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.fromOffset(100, 16),
}, panel)

local phasePill = create("TextLabel", {
	Text = "CLEAR",
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = COLORS.Panel,
	BackgroundColor3 = COLORS.Clear,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 9),
	Size = UDim2.fromOffset(84, 18),
}, panel)
round(phasePill, UDim.new(1, 0))

-- Scope with range rings and crosshair
local scope = create("Frame", {
	Name = "Scope",
	Size = UDim2.fromOffset(SCOPE_SIZE, SCOPE_SIZE),
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 34),
	BackgroundColor3 = COLORS.Scope,
	BorderSizePixel = 0,
}, panel)
round(scope, UDim.new(1, 0))
create("UIStroke", { Color = COLORS.Grid, Transparency = 0.3, Thickness = 1.5 }, scope)

for _, fraction in { 1 / 3, 2 / 3 } do
	local ring = create("Frame", {
		Size = UDim2.fromScale(fraction, fraction),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, scope)
	round(ring, UDim.new(1, 0))
	create("UIStroke", { Color = COLORS.Grid, Transparency = 0.7 }, ring)
end
for _, size in { UDim2.new(1, 0, 0, 1), UDim2.new(0, 1, 1, 0) } do
	create("Frame", {
		Size = size,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = COLORS.Grid,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
	}, scope)
end

-- Sweep beam with a fading trail. Each beam sits in a full-size holder so it rotates around the scope's center.
local sweepHolders: { Frame } = {}
for i = 0, 5 do
	local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, scope)
	local beam = create("Frame", {
		Size = UDim2.new(0, 2, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = COLORS.Sweep,
		BackgroundTransparency = i * 0.15,
		BorderSizePixel = 0,
	}, holder)
	create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.9) }, beam)
	table.insert(sweepHolders, holder)
end

local northMarker = create("TextLabel", {
	Text = "N",
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = COLORS.Grid,
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(14, 14),
	ZIndex = 3,
}, scope)

-- You, always pointing up (the scope turns with your camera)
local me = create("Frame", {
	Size = UDim2.fromOffset(7, 7),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 5,
}, scope)
round(me, UDim.new(1, 0))
create("Frame", {
	Size = UDim2.fromOffset(2, 9),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0.5, -3),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ZIndex = 5,
}, scope)

-- Readouts under the scope
local infoTop = 34 + SCOPE_SIZE + 10
local statusLabel = create("TextLabel", {
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = COLORS.Text,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, infoTop),
	Size = UDim2.new(1, -28, 0, 32),
}, panel)
local nearestLabel = create("TextLabel", {
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, infoTop + 36),
	Size = UDim2.new(1, -28, 0, 16),
}, panel)
local scanLabel = create("TextLabel", {
	Text = SCAN_HINT,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, infoTop + 56),
	Size = UDim2.new(1, -28, 0, 16),
}, panel)

-- Warning banner across the top of the screen
local banner = create("Frame", {
	Name = "EmergencyBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 16),
	Size = UDim2.fromOffset(460, 56),
	BackgroundColor3 = Color3.fromRGB(60, 14, 14),
	BackgroundTransparency = 0.1,
	BorderSizePixel = 0,
	Visible = false,
}, screenGui)
round(banner, UDim.new(0, 10))
create("UIStroke", { Color = COLORS.Tornado, Thickness = 2 }, banner)
local bannerTitle = create("TextLabel", {
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextColor3 = COLORS.Tornado,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 20),
}, banner)
local bannerBody = create("TextLabel", {
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = COLORS.Text,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 0, 18),
}, banner)

local bannerToken = 0
local function showBanner(title: string, body: string, seconds: number)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerBody.Text = body
	banner.Visible = true
	task.delay(seconds, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

local function onPhaseChanged()
	local phase = stormState:GetAttribute("Phase")
	if phase == "Minor" then
		showBanner("TORNADO WARNING", "A tornado is touching down. Check your radar.", 6)
	elseif phase == "FinalWarning" then
		showBanner("TORNADO EMERGENCY", "A violent wedge tornado is moving in. Watch your radar.", 7)
	elseif phase == "Final" then
		showBanner("EF5 WEDGE ON THE GROUND", "Get to the storm bunker or get out of its path.", 7)
	else
		banner.Visible = false
	end
end
stormState:GetAttributeChangedSignal("Phase"):Connect(onPhaseChanged)

-- Scan results from the handheld Doppler
local scanToken = 0
Network.DopplerScanResult.OnClientEvent:Connect(function(tokens: number, dist: number, success: boolean)
	if success then
		scanLabel.Text = string.format("Scan: +%d tokens at %d studs", tokens, math.floor(dist))
		scanLabel.TextColor3 = COLORS.Clear
	elseif dist < 0 then
		scanLabel.Text = "Scan: no tornado on the ground"
		scanLabel.TextColor3 = COLORS.Muted
	else
		scanLabel.Text = string.format("Scan: too far (%d studs, max %d)", math.floor(dist), Config.Doppler.MaxScanDistance)
		scanLabel.TextColor3 = COLORS.Cell
	end
	scanToken += 1
	local token = scanToken
	task.delay(4, function()
		if scanToken == token then
			scanLabel.Text = SCAN_HINT
			scanLabel.TextColor3 = COLORS.Muted
		end
	end)
end)

local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local function compass(delta: Vector3): string
	-- North is -Z
	local degrees = (math.deg(math.atan2(delta.X, -delta.Z)) + 360) % 360
	return COMPASS[math.floor((degrees + 22.5) / 45) % 8 + 1]
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

type Blip = { Frame: Frame, Ring: UIStroke, Label: TextLabel, Display: Vector3? }
local blips: { [Instance]: Blip } = {}

local function getBlip(info: Instance): Blip
	local existing = blips[info]
	if existing then
		return existing
	end
	local frame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 4 }, scope)
	round(frame, UDim.new(1, 0))
	local blip: Blip = {
		Frame = frame,
		Ring = create("UIStroke", { Thickness = 2 }, frame),
		Label = create("TextLabel", {
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = COLORS.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 4, 0.5, 0),
			Size = UDim2.fromOffset(30, 12),
			BackgroundTransparency = 1,
			ZIndex = 4,
		}, frame),
		Display = nil,
	}
	blips[info] = blip
	return blip
end

local sweepAngle = 0
RunService.RenderStepped:Connect(function(dt)
	sweepAngle = (sweepAngle + 120 * dt) % 360
	for i, holder in sweepHolders do
		holder.Rotation = sweepAngle - (i - 1) * 3
	end

	-- Heading-up: "up" on the scope is where the camera faces
	local look = Workspace.CurrentCamera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)

	-- Returns scope position (0-1) for a flat world offset; far things get pinned to the edge
	local function toScope(delta: Vector3): (number, number, boolean)
		local x = delta:Dot(right) / RANGE
		local y = -delta:Dot(forward) / RANGE
		local length = math.sqrt(x * x + y * y)
		local outside = length > 0.95
		if outside then
			x, y = x / length * 0.95, y / length * 0.95
		end
		return 0.5 + x * 0.5, 0.5 + y * 0.5, outside
	end

	local nx, ny = toScope(Vector3.new(0, 0, -RANGE * 0.86))
	northMarker.Position = UDim2.fromScale(nx, ny)

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local origin = if root then root.Position else Workspace.CurrentCamera.Focus.Position

	local nearestTornado: Instance?, tornadoDistance = nil, math.huge
	local nearestCell: Instance?, cellDistance = nil, math.huge

	for _, info in stormState:GetChildren() do
		local position = info:GetAttribute("Position") :: Vector3?
		if not position then
			continue
		end
		local blip = getBlip(info)
		local display = if blip.Display then blip.Display:Lerp(position, math.min(1, dt * 8)) else position
		blip.Display = display

		local delta = Vector3.new(display.X - origin.X, 0, display.Z - origin.Z)
		local sx, sy, outside = toScope(delta)
		blip.Frame.Position = UDim2.fromScale(sx, sy)

		if info:GetAttribute("TouchedDown") then
			local size = 10 * (1 + math.sin(os.clock() * 6) * 0.15)
			blip.Frame.Size = UDim2.fromOffset(size, size)
			blip.Frame.BackgroundColor3 = COLORS.Tornado
			blip.Frame.BackgroundTransparency = 0
			blip.Ring.Color = Color3.new(1, 1, 1)
			blip.Ring.Transparency = 0.4
			blip.Label.Text = tostring(info:GetAttribute("Category") or "")
			if delta.Magnitude < tornadoDistance then
				nearestTornado, tornadoDistance = info, delta.Magnitude
			end
		else
			-- Developing storm cell: a soft blob that gently breathes
			local size = math.clamp((info:GetAttribute("Radius") or 10) * 1.1, 14, 40) * (1 + math.sin(os.clock() * 2) * 0.05)
			blip.Frame.Size = UDim2.fromOffset(size, size)
			blip.Frame.BackgroundColor3 = COLORS.Cell
			blip.Frame.BackgroundTransparency = 0.45
			blip.Ring.Color = COLORS.Cell
			blip.Ring.Transparency = 0.2
			blip.Label.Text = ""
			if delta.Magnitude < cellDistance then
				nearestCell, cellDistance = info, delta.Magnitude
			end
		end
		if outside then
			blip.Frame.Size = UDim2.fromOffset(8, 8)
		end
	end

	-- Drop blips for storms that are gone
	for info, blip in blips do
		if info.Parent ~= stormState then
			blip.Frame:Destroy()
			blips[info] = nil
		end
	end

	-- Phase pill and status line
	local phase = stormState:GetAttribute("Phase")
	local phaseInfo = if typeof(phase) == "string" then PHASES[phase] else nil
	local remaining = (stormState:GetAttribute("PhaseEndsAt") or 0) - Workspace:GetServerTimeNow()
	if phaseInfo then
		phasePill.Text = phaseInfo.Label
		phasePill.BackgroundColor3 = phaseInfo.Color
		statusLabel.Text = string.format(phaseInfo.Status, formatTime(remaining))
	else
		phasePill.Text = "CLEAR"
		phasePill.BackgroundColor3 = COLORS.Clear
		statusLabel.Text = "No storms on radar"
	end

	-- Nearest tornado (or developing cell)
	if nearestTornado then
		local position = nearestTornado:GetAttribute("Position") :: Vector3
		local wind = nearestTornado:GetAttribute("Wind") or 0
		nearestLabel.Text = string.format(
			"%s  %d studs %s  %s",
			tostring(nearestTornado:GetAttribute("Category")),
			math.floor(tornadoDistance),
			compass(position - origin),
			if wind > 0 then string.format("%d mph", wind) else ""
		)
		nearestLabel.TextColor3 = COLORS.Tornado
	elseif nearestCell then
		local position = nearestCell:GetAttribute("Position") :: Vector3
		nearestLabel.Text = string.format("Storm cell  %d studs %s", math.floor(cellDistance), compass(position - origin))
		nearestLabel.TextColor3 = COLORS.Cell
	else
		nearestLabel.Text = "Nothing nearby"
		nearestLabel.TextColor3 = COLORS.Muted
	end
end)

print("[Client] DopplerRadarScreen online.")
