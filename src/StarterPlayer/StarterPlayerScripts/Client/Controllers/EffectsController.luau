--!strict
-- EffectsController — plays juice from PlayEffect events (§28). TRACK B.
-- Plant puff, stage bounce/sparkle, READY billboard glow, harvest coin burst +
-- floating payout text + coin-counter tween + mutation effect. Respects the
-- ReducedEffects setting and AssetConfig ids of 0 (skip silently). No rapid flashing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Types = require(Shared:WaitForChild("Types"))
local Config = Shared:WaitForChild("Config")
local AssetConfig = require(Config:WaitForChild("AssetConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local UIController = require(script.Parent:WaitForChild("UIController"))
local FarmController = require(script.Parent:WaitForChild("FarmController"))
local UITheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UITheme"))

type EffectPayload = Types.EffectPayload

local EffectsController = {}
EffectsController.Name = "EffectsController"

-- ── Settings (respect ReducedEffects, §28) ─────────────────────────────────
-- The snapshot carries no Settings, so default to full effects until UpdateSettings
-- echoes through the HUD. ReducedEffects is read defensively from the snapshot if a
-- future field appears; otherwise effects play.
local reducedEffects = false

-- ── Slot anchor lookup (shared with FarmController's discovery via tags) ────
local function findSlotPart(slotIndex: number?): BasePart?
	if not slotIndex then
		return nil
	end
	local snapshot = UIController.getSnapshot()
	local plotId = snapshot and snapshot.PlotId
	for _, inst in CollectionService:GetTagged(Constants.Tags.GrowSlot) do
		if
			inst:IsA("BasePart")
			and inst:GetAttribute(Constants.Attributes.SlotIndex) == slotIndex
		then
			if plotId == nil or inst:GetAttribute(Constants.Attributes.PlotId) == plotId then
				return inst
			end
		end
	end
	return nil
end

-- ── Sound (skip when AssetConfig id == 0, §28) ─────────────────────────────
local function playSound(soundId: number)
	if not AssetConfig.isConfigured(soundId) then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = string.format("rbxassetid://%d", soundId)
	sound.Volume = 0.5
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
	-- Safety cleanup in case Ended never fires.
	task.delay(6, function()
		if sound and sound.Parent then
			sound:Destroy()
		end
	end)
end

-- ── World-space particle puff (no rapid flashing, §28) ─────────────────────
local function spawnPuff(part: BasePart, color: Color3)
	if reducedEffects then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rate = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new(1.2)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
	emitter:Emit(18)

	task.delay(1.2, function()
		attachment:Destroy()
	end)
end

-- A short scale bounce on the server-spawned creature model under the slot anchor.
local function bounceModel(part: BasePart)
	if reducedEffects then
		return
	end
	local model = part:FindFirstChildOfClass("Model")
	local primary = model and model.PrimaryPart
	if not primary then
		return
	end
	-- Gentle Y squash/stretch via a temporary weld-free scale tween on size.
	local original = primary.Size
	local squash = TweenService:Create(
		primary,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = original * Vector3.new(1.15, 0.85, 1.15) }
	)
	squash.Completed:Connect(function()
		TweenService:Create(
			primary,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = original }
		):Play()
	end)
	squash:Play()
end

-- ── Floating payout text + coin counter pop ────────────────────────────────
local function floatPayout(part: BasePart?, amount: number)
	if not part then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PayoutFloat"
	billboard.Size = UDim2.fromOffset(140, 50)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UITheme.Fonts.Number
	label.TextColor3 = UITheme.Colors.Coin
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Text = string.format("+%d", amount)
	label.Parent = billboard

	if reducedEffects then
		task.delay(1, function()
			billboard:Destroy()
		end)
		return
	end

	local rise = TweenService:Create(
		billboard,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 9, 0) }
	)
	local fade = TweenService:Create(
		label,
		TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	)
	fade.Completed:Connect(function()
		billboard:Destroy()
	end)
	rise:Play()
	fade:Play()
end

-- A brief glow Highlight on a ready creature (single fade-in/out, no flashing).
local function readyGlow(part: BasePart)
	if reducedEffects then
		return
	end
	if part:FindFirstChild("ReadyGlow") then
		return
	end
	local hl = Instance.new("Highlight")
	hl.Name = "ReadyGlow"
	hl.FillColor = UITheme.Colors.Success
	hl.FillTransparency = 1
	hl.OutlineColor = UITheme.Colors.Success
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = part

	TweenService:Create(hl, TweenInfo.new(0.5), { FillTransparency = 0.7 }):Play()
	-- Leave the glow on until the crop is harvested (slot anchor reused); cleaned
	-- up by the next plant via spawnPuff lifecycle / model rebuild.
	task.delay(30, function()
		if hl and hl.Parent then
			hl:Destroy()
		end
	end)
end

-- ── PlayEffect router (§5 payloads) ────────────────────────────────────────
local function onPlayEffect(payload: EffectPayload)
	if typeof(payload) ~= "table" or not payload.Kind then
		return
	end
	local part = findSlotPart(payload.SlotIndex)

	if payload.Kind == Constants.Effects.Plant then
		playSound(AssetConfig.Sounds.Plant)
		if part then
			spawnPuff(part, Color3.fromRGB(140, 100, 70))
		end
	elseif payload.Kind == Constants.Effects.StageChange then
		playSound(AssetConfig.Sounds.StageChange)
		if part then
			bounceModel(part)
			spawnPuff(part, UITheme.Colors.AccentAlt)
		end
	elseif payload.Kind == Constants.Effects.Ready then
		playSound(AssetConfig.Sounds.Ready)
		if part then
			readyGlow(part)
		end
	elseif payload.Kind == Constants.Effects.Harvest then
		playSound(AssetConfig.Sounds.Harvest)
		if part then
			spawnPuff(part, UITheme.Colors.Coin)
			local existing = part:FindFirstChild("ReadyGlow")
			if existing then
				existing:Destroy()
			end
		end
		if payload.Amount and payload.Amount > 0 then
			floatPayout(part, payload.Amount)
			playSound(AssetConfig.Sounds.CoinTick)
		end
	elseif payload.Kind == Constants.Effects.Mutation then
		playSound(AssetConfig.Sounds.MutationRare)
		if part then
			spawnPuff(part, UITheme.Colors.Accent)
			bounceModel(part)
		end
	end
end

function EffectsController.Init()
	-- Drive local StageChange juice from FarmController's timestamp-based detector
	-- (server also sends an authoritative StageChange PlayEffect; both are cosmetic).
	FarmController.setStageChangeHandler(function(slotIndex: number, _stage: number)
		if reducedEffects then
			return
		end
		local part = findSlotPart(slotIndex)
		if part then
			bounceModel(part)
		end
	end)

	-- Resolve initial ReducedEffects from the first snapshot if the field exists.
	UIController.onSnapshot(function(snapshot)
		local settings = (snapshot :: any).Settings
		if typeof(settings) == "table" and typeof(settings.ReducedEffects) == "boolean" then
			reducedEffects = settings.ReducedEffects
		end
	end)
end

function EffectsController.Start()
	Remotes.Events[Constants.Remotes.PlayEffect].OnClientEvent:Connect(onPlayEffect)

	-- The accessibility "reduced effects" setting now rides on the snapshot; keep our
	-- local flag in sync so heavy particle/tween effects are skipped when it's on.
	UIController.onSnapshot(function(snapshot)
		reducedEffects = snapshot.ReducedEffects == true
	end)
end

return EffectsController
