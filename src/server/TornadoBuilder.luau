--!strict
-- TornadoBuilder.luau
-- Builds tornado models on demand for TornadoManager.
-- Every visual part is welded to VortexRoot, so moving the root moves the whole tornado.
-- A new tornado starts invisible: ShowClouds -> Touchdown -> Dissipate drive what players see.

local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local LAYERS = 22

export type Shape = {
	BottomRadius: number,
	TopRadius: number,
	Height: number, -- height of the cloud base above the ground
	CloudDiameter: number,
}

type Layer = { Part: BasePart, Target: number, T: number } -- T: 0 at the ground, 1 at the cloud base
type Emitter = { Emitter: ParticleEmitter, T: number }

export type Tornado = {
	Model: Model,
	Root: BasePart,
	Layers: { Layer },
	Clouds: { Layer },
	Emitters: { Emitter },
	Roar: Sound,
}

local TornadoBuilder = {}

local function smokeEmitter(props: { [string]: any }): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SMOKE_TEXTURE
	emitter.LightInfluence = 1
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Enabled = false
	for key, value in props do
		(emitter :: any)[key] = value
	end
	return emitter
end

local function radiusAt(shape: Shape, t: number): number
	return shape.BottomRadius + (t ^ 1.6) * (shape.TopRadius - shape.BottomRadius)
end

function TornadoBuilder.Build(name: string, shape: Shape, groundPosition: Vector3, parent: Instance): Tornado
	local model = Instance.new("Model")
	model.Name = name

	-- The tornado's mover and physics center
	local root = Instance.new("Part")
	root.Name = "VortexRoot"
	root.Size = Vector3.new(14, 4, 14)
	root.Position = Vector3.new(groundPosition.X, 2, groundPosition.Z)
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	CollectionService:AddTag(root, "TornadoVortex")

	local function attachVisual(part: BasePart)
		part.Anchored = false
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end

	local tornado: Tornado = {
		Model = model,
		Root = root,
		Layers = {},
		Clouds = {},
		Emitters = {},
		Roar = Instance.new("Sound"),
	}

	-- Funnel: stacked rings, narrow at the ground and flaring out toward the cloud base
	local layerHeight = shape.Height / LAYERS
	for i = 0, LAYERS - 1 do
		local t = i / (LAYERS - 1)
		local radius = radiusAt(shape, t)
		local target = 0.35 - t * 0.2
		local layer = Instance.new("Part")
		layer.Name = "FunnelLayer_" .. i
		layer.Shape = Enum.PartType.Cylinder
		layer.Size = Vector3.new(layerHeight + 0.5, radius * 2, radius * 2)
		layer.CFrame = root.CFrame * CFrame.new(0, i * layerHeight + layerHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		layer.Color = Color3.fromRGB(78, 72, 66):Lerp(Color3.fromRGB(58, 62, 70), t)
		layer.Transparency = 1
		attachVisual(layer)
		table.insert(tornado.Layers, { Part = layer, Target = target, T = t })

		-- Smoke puffs off the funnel surface soften the stacked edges
		if i % 2 == 0 then
			local emitter = smokeEmitter({
				Shape = Enum.ParticleEmitterShape.Sphere,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
				Rate = 14,
				Lifetime = NumberRange.new(2, 3),
				Speed = NumberRange.new(2, 6),
				Size = NumberSequence.new(math.min(radius * 0.5, 45), math.min(radius * 0.8, 60)),
				Transparency = NumberSequence.new(0.45, 1),
				Color = ColorSequence.new(layer.Color),
			})
			emitter.Parent = layer
			table.insert(tornado.Emitters, { Emitter = emitter, T = t })
		end
	end

	-- Dark wall cloud the funnel hangs from
	for _, cloud in {
		{ Height = shape.Height - 2, Diameter = shape.TopRadius * 2.4, Thickness = 10 },
		{ Height = shape.Height + 10, Diameter = shape.CloudDiameter, Thickness = 14 },
	} do
		local disc = Instance.new("Part")
		disc.Name = "WallCloud"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(cloud.Thickness, cloud.Diameter, cloud.Diameter)
		disc.CFrame = root.CFrame * CFrame.new(0, cloud.Height, 0) * CFrame.Angles(0, 0, math.rad(90))
		disc.Color = Color3.fromRGB(55, 58, 65)
		disc.Transparency = 1
		attachVisual(disc)
		table.insert(tornado.Clouds, { Part = disc, Target = 0.08, T = 1 })
	end

	-- Swirling streaks: emitters around the funnel fire sideways, all in the same direction of rotation
	for _, t in { 0.07, 0.23, 0.43, 0.68, 0.9 } do
		local radius = radiusAt(shape, t) + 4
		for k = 1, 6 do
			local angle = k * math.pi / 3
			local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tangent = Vector3.new(-radial.Z, 0, radial.X)
			local attachment = Instance.new("Attachment")
			attachment.Name = "SwirlEmitter"
			attachment.CFrame = CFrame.fromMatrix(radial * radius + Vector3.new(0, t * shape.Height, 0), radial, tangent)
			attachment.Parent = root
			local emitter = smokeEmitter({
				EmissionDirection = Enum.NormalId.Top, -- attachment's Y axis = tangent
				Rate = 6,
				Lifetime = NumberRange.new(1.5, 2.5),
				Speed = NumberRange.new(30, 50),
				Drag = 1.5,
				SpreadAngle = Vector2.new(15, 15),
				Size = NumberSequence.new(10 + radius * 0.15, 20 + radius * 0.25),
				Transparency = NumberSequence.new(0.35, 1),
				Color = ColorSequence.new(Color3.fromRGB(75, 75, 80)),
			})
			emitter.Parent = attachment
			table.insert(tornado.Emitters, { Emitter = emitter, T = t })
		end
	end

	-- Ground debris cloud at the base
	local dustAttachment = Instance.new("Attachment")
	dustAttachment.Name = "DebrisCloud"
	dustAttachment.Position = Vector3.new(0, 4, 0)
	dustAttachment.Parent = root
	local dustScale = shape.BottomRadius / 34
	local dust = smokeEmitter({
		Rate = 60,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(25 * dustScale, 45 * dustScale),
		SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 6, 0),
		Drag = 1.2,
		RotSpeed = NumberRange.new(-60, 60),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 20 * dustScale),
			NumberSequenceKeypoint.new(1, 70 * dustScale),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.6, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Color = ColorSequence.new(Color3.fromRGB(95, 82, 68), Color3.fromRGB(70, 65, 60)),
	})
	dust.Parent = dustAttachment
	table.insert(tornado.Emitters, { Emitter = dust, T = 0 })

	-- Howling roar audio, starts at touchdown
	local roar = tornado.Roar
	roar.Name = "TornadoRoarAudio"
	roar.SoundId = "rbxassetid://9114223171"
	roar.Volume = 0
	roar.Looped = true
	roar.RollOffMaxDistance = 500
	roar.RollOffMinDistance = 50
	roar.Parent = root

	model.Parent = parent
	return tornado
end

local function fade(part: BasePart, transparency: number, duration: number, delay: number)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, delay)
	TweenService:Create(part, info, { Transparency = transparency }):Play()
end

-- The wall cloud forms overhead; the funnel is still hidden
function TornadoBuilder.ShowClouds(tornado: Tornado, duration: number)
	for _, cloud in tornado.Clouds do
		fade(cloud.Part, cloud.Target, duration, 0)
	end
end

-- The funnel lowers out of the cloud: top rings appear first, the ground last
function TornadoBuilder.Touchdown(tornado: Tornado, duration: number)
	for _, layer in tornado.Layers do
		fade(layer.Part, layer.Target, duration * 0.4, (1 - layer.T) * duration * 0.6)
	end
	for _, entry in tornado.Emitters do
		task.delay((1 - entry.T) * duration * 0.6, function()
			entry.Emitter.Enabled = true
		end)
	end
	tornado.Roar:Play()
	TweenService:Create(tornado.Roar, TweenInfo.new(duration), { Volume = 3.5 }):Play()
end

-- The funnel ropes out from the ground up, then the cloud clears and the model is removed
function TornadoBuilder.Dissipate(tornado: Tornado, duration: number)
	for _, layer in tornado.Layers do
		fade(layer.Part, 1, duration * 0.4, layer.T * duration * 0.4)
	end
	for _, entry in tornado.Emitters do
		task.delay(entry.T * duration * 0.4, function()
			entry.Emitter.Enabled = false
		end)
	end
	for _, cloud in tornado.Clouds do
		fade(cloud.Part, 1, duration * 0.3, duration * 0.7)
	end
	TweenService:Create(tornado.Roar, TweenInfo.new(duration * 0.8), { Volume = 0 }):Play()
	task.delay(duration + 0.5, function()
		tornado.Model:Destroy()
	end)
end

return TornadoBuilder
