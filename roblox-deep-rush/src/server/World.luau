--!nonstrict
--[[
	World.luau — the shaft, generated in chunks around whoever is in it.

	Shape of the world, and why:

	  DOWN IS FREE, UP IS EARNED. You descend by jumping into the shaft and
	  falling (Roblox has no fall damage, so a 900m drop is pure thrill and
	  costs nothing). You ascend on lift pads, which are spaced out and slow
	  unless you own the Express Lift. That asymmetry is the whole tension:
	  going deeper is always tempting and always a commitment.

	  SHELVES, NOT TUNNELS. Ore sits on shelves that jut out of the shaft
	  wall. You fall, you land, you clear the shelf, you drop again. It gives
	  the core loop a rhythm and it means a player never has to navigate.

	  CHUNKS. 150 studs of shaft each, built when someone is near and torn
	  down when nobody is. A 3,000m shaft as static geometry would be tens of
	  thousands of parts; this keeps a live server at a few hundred.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioConfig = require(Shared.Config.Audio)
local Config = require(Shared.Config.Game)
local HazardConfig = require(Shared.Config.Hazards)
local Layers = require(Shared.Config.Layers)
local Ores = require(Shared.Config.Ores)
local Rarity = require(Shared.Rarity)

local World = {}

local CHUNK_HEIGHT = 150 -- studs
local SHAFT_RADIUS = 62
local WALL_SEGMENTS = 10
local SHELVES_PER_CHUNK = 2
local NODES_PER_SHELF = 6
local LIFT_EVERY_CHUNKS = 1 -- every chunk: see the bedrock note in buildChunk
local KEEP_RADIUS = 2 -- chunks around a player kept alive
local MAX_DEPTH_METERS = 3000

local chunks: { [number]: Folder } = {}
local nodes: { [string]: any } = {}
local crates: { [string]: any } = {}
local nextId = 0

local container: Folder
local crateContainer: Folder

local rng = Random.new(os.time())

local function uid(prefix: string): string
	nextId += 1
	return prefix .. nextId
end

--- Depth in meters for a world position. y = 0 is the surface.
function World.depthOf(position: Vector3): number
	return math.max(0, (Config.SurfaceY - position.Y) / Config.StudsPerMeter)
end

function World.yForDepth(meters: number): number
	return Config.SurfaceY - meters * Config.StudsPerMeter
end

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

--- Attach a positional looping sound to a part. Silently does nothing until
--- the slot has an asset id, which is why the game is never broken-sounding
--- before you upload anything — it is just quieter.
local function attachLoop(part: BasePart, slot: string, volume: number, maxDistance: number)
	local id = AudioConfig.source(slot)
	if id == "" then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "Loop_" .. slot
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = maxDistance
	sound.Parent = part
	sound:Play()
end

local function layerColor(layer): Color3
	return Color3.fromRGB(layer.rock[1], layer.rock[2], layer.rock[3])
end

-- Ore nodes ----------------------------------------------------------------

--- How each `look` from Ores.Appearance renders. `spike` stretches the vein
--- pieces: metal seams lie flat in the rock, crystals stab out of it.
local LOOKS = {
	metal = { material = Enum.Material.Metal, transparency = 0, reflectance = 0.35, spike = 1.1, sparkle = false },
	gem = { material = Enum.Material.Glass, transparency = 0.18, reflectance = 0.3, spike = 1.9, sparkle = true },
	crystal = { material = Enum.Material.Neon, transparency = 0.05, reflectance = 0, spike = 2.4, sparkle = true },
	stone = { material = Enum.Material.Slate, transparency = 0, reflectance = 0, spike = 0.9, sparkle = false },
	void = { material = Enum.Material.Neon, transparency = 0.4, reflectance = 0, spike = 1.6, sparkle = true },
}

local BEACON_FROM_TIER = 4 -- Epic and up get a light column you can see from a shelf away
local LABEL_FROM_TIER = 3 -- Rare and up name themselves when you get close

local function oreColor(oreId: string): Color3
	local rgb = Ores.appearance(oreId).color
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

--- Build everything that depends on WHICH ore this node is. Called on spawn
--- and again on every respawn, because a node that always regrows the same
--- diamond is a diamond farm, not a mine.
local function dressNode(part: BasePart, ore, layer, depth: number)
	for _, child in ipairs(part:GetChildren()) do
		child:Destroy()
	end

	local appearance = Ores.appearance(ore.id)
	local look = LOOKS[appearance.look] or LOOKS.gem
	local tierIndex = Ores.TierIndex[ore.tier] or 1
	local tier = Ores.Tiers[tierIndex]
	local vein = oreColor(ore.id)
	local size = part.Size.X

	part.Color = layerColor(layer):Lerp(vein, 0.12)
	part:SetAttribute("Ore", ore.id)
	part:SetAttribute("Tier", ore.tier)

	-- The seam itself. Enough pieces to read as a vein, few enough that a
	-- shelf of six nodes is not a hundred parts.
	for piece = 1, rng:NextInteger(3, 5) do
		local thickness = size * rng:NextNumber(0.16, 0.3)
		local offset = Vector3.new(
			rng:NextNumber(-size * 0.42, size * 0.42),
			rng:NextNumber(-size * 0.42, size * 0.42),
			rng:NextNumber(-size * 0.42, size * 0.42)
		)
		local shard = makePart(
			"Vein" .. piece,
			Vector3.new(thickness, thickness * look.spike * rng:NextNumber(0.8, 1.5), thickness),
			CFrame.new(part.Position + offset)
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			vein,
			look.material
		)
		shard.CanCollide = false
		shard.Transparency = look.transparency
		shard.Reflectance = look.reflectance
		shard.Parent = part
	end

	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Range = 10 + tierIndex * 2.5
	light.Brightness = 0.5 + tier.glow * 2.4 + math.min(depth / 1800, 1)
	light.Color = vein
	light.Parent = part

	if look.sparkle then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Sparkle"
		emitter.Color = ColorSequence.new(vein)
		emitter.Size = NumberSequence.new(0.28)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.8, 1.6)
		emitter.Rate = 2 + tierIndex * 2
		emitter.Speed = NumberRange.new(0.4, 1.2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 1
		emitter.Parent = part
	end

	-- Rare and up say what they are. Below that the colour is enough, and a
	-- shelf of six labelled dirt clods is noise.
	if tierIndex >= LABEL_FROM_TIER then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "Label"
		billboard.Size = UDim2.new(0, 190, 0, 46)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, size * 0.9 + 2, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 120
		billboard.Parent = part

		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, 0, 0.6, 0)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.GothamBlack
		name.Text = ore.name
		name.TextColor3 = vein
		name.TextStrokeTransparency = 0.3
		name.TextScaled = true
		name.Parent = billboard

		local rank = Instance.new("TextLabel")
		rank.Size = UDim2.new(1, 0, 0.4, 0)
		rank.Position = UDim2.new(0, 0, 0.6, 0)
		rank.BackgroundTransparency = 1
		rank.Font = Enum.Font.GothamBold
		rank.Text = string.upper(ore.tier)
		rank.TextColor3 = Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3])
		rank.TextStrokeTransparency = 0.5
		rank.TextScaled = true
		rank.Parent = billboard
	end

	-- Epic and up throw a column of light up the shaft. This is the single
	-- biggest reason to keep descending instead of clearing one shelf: you
	-- can see, from where you are standing, that something down there is
	-- worth the drop.
	if tierIndex >= BEACON_FROM_TIER then
		local beacon = makePart(
			"Beacon",
			Vector3.new(size * 0.45, 110 + tierIndex * 28, size * 0.45),
			CFrame.new(part.Position + Vector3.new(0, 55 + tierIndex * 14, 0)),
			vein,
			Enum.Material.Neon
		)
		beacon.CanCollide = false
		beacon.Transparency = 0.86
		beacon.CastShadow = false
		beacon.Parent = part
	end
end

local function spawnNode(parent: Instance, position: Vector3, depth: number, layer)
	local id = uid("node")
	local size = rng:NextNumber(3.2, 5.4)

	local part = makePart(
		"OreNode",
		Vector3.new(size, size, size),
		CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
		layerColor(layer),
		Enum.Material.Rock
	)
	-- Solid, because walking through a boulder is the most obviously broken
	-- thing a mining game can do. Mined-out nodes go non-solid in
	-- World.consumeNode, so you are never stopped by an invisible rock.
	part.CanCollide = true
	part:SetAttribute("NodeId", id)
	part:SetAttribute("Depth", math.floor(depth))
	part.Parent = parent

	-- What this node IS, decided now and shown in the rock. The roll carries
	-- no luck: the wall does not know who will swing at it, and a node two
	-- players can see cannot be rolled on one player's stats. Luck moved to
	-- the swing instead — see Shared/Rarity.luau.
	local ore = Rarity.rollNodeOre(depth, rng)
	if ore then
		dressNode(part, ore, layer, depth)
	end

	nodes[id] = { id = id, part = part, depth = depth, layer = layer, ore = ore, alive = ore ~= nil }
	return id
end

--- A chop landing. `progress` is 0..1 through the swing.
---
--- The rock kicks back, the vein pieces go with it, and chips come off.
--- Without this the only thing that moved during mining was a progress bar,
--- and the rock simply blinked out at the end — which is why the whole action
--- read as a menu rather than as work.
---
--- Everything is driven from a stored rest pose rather than from wherever the
--- part currently is, so four chops in a row cannot walk a rock out of the
--- wall. The vein shards are positioned absolutely rather than welded — they
--- are anchored decoration — so they have to be moved by the same delta or
--- the rock jumps out from behind its own gold.
function World.chipNode(nodeId: string, progress: number)
	local node = nodes[nodeId]
	if not node or not node.alive or not node.part.Parent then
		return
	end

	local part = node.part
	if not node.rest then
		node.rest = part.CFrame
		node.veinRest = {}
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("BasePart") then
				node.veinRest[child] = child.CFrame
			end
		end
	end

	-- Deeper into the swing the rock gives more ground, so the last chop is
	-- visibly the one that breaks it.
	local give = 0.3 + progress * 0.7
	local offset = CFrame.new(
		rng:NextNumber(-0.5, 0.5) * give,
		-0.45 * give,
		rng:NextNumber(-0.5, 0.5) * give
	) * CFrame.Angles(rng:NextNumber(-0.09, 0.09) * give, rng:NextNumber(-0.12, 0.12) * give, 0)

	local settle = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	part.CFrame = node.rest * offset
	TweenService:Create(part, settle, { CFrame = node.rest }):Play()

	for child, rest in pairs(node.veinRest) do
		if child.Parent then
			child.CFrame = rest * offset
			TweenService:Create(child, settle, { CFrame = rest }):Play()
		end
	end

	local sparkle = part:FindFirstChild("Sparkle")
	if sparkle then
		sparkle:Emit(6 + math.floor(progress * 10))
	end

	local chips = part:FindFirstChild("Chips")
	if not chips then
		chips = Instance.new("ParticleEmitter")
		chips.Name = "Chips"
		chips.Color = ColorSequence.new(part.Color)
		chips.Size = NumberSequence.new(0.34)
		chips.Lifetime = NumberRange.new(0.3, 0.7)
		chips.Speed = NumberRange.new(6, 14)
		chips.SpreadAngle = Vector2.new(180, 180)
		chips.Acceleration = Vector3.new(0, -60, 0)
		chips.Rate = 0
		chips.LightEmission = 0.4
		chips.Parent = part
	end
	chips:Emit(8 + math.floor(progress * 12))
end

function World.getNode(nodeId: string)
	local node = nodes[nodeId]
	if node and node.alive and node.part.Parent then
		return node
	end
	return nil
end

--- Break a node: hide it, then bring it back as something else.
---
--- We never destroy and recreate the part, because the id has to stay stable
--- for the client's target lock. The dressing is rebuilt from a fresh roll,
--- which matters more now that the ore is visible: a node that regrew the
--- same diamond every nine seconds would be a diamond farm, and the first
--- player to find one would never move again.
function World.consumeNode(nodeId: string)
	local node = nodes[nodeId]
	if not node or not node.alive then
		return
	end

	node.alive = false
	local part = node.part
	if part.Parent then
		part.Transparency = 1
		part.CanCollide = false
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("BasePart") then
				child.Transparency = 1
			elseif child:IsA("PointLight") or child:IsA("ParticleEmitter") then
				child.Enabled = false
			elseif child:IsA("BillboardGui") then
				child.Enabled = false
			end
		end
	end

	task.delay(Config.NodeRespawn, function()
		if not node.part.Parent then
			return
		end
		local ore = Rarity.rollNodeOre(node.depth, rng)
		if not ore then
			return
		end
		node.ore = ore
		node.alive = true
		-- New dressing, new children: the old rest pose refers to parts that
		-- no longer exist, and the body must start from where it belongs
		-- rather than wherever the last chop left it mid-tween.
		if node.rest then
			node.part.CFrame = node.rest
		end
		node.rest = nil
		node.veinRest = nil
		node.part.Transparency = 0
		node.part.CanCollide = true
		dressNode(node.part, ore, node.layer, node.depth)
	end)
end

-- Chunk building -----------------------------------------------------------

local function buildShelf(parent: Instance, chunkIndex: number, slot: number)
	local baseY = -chunkIndex * CHUNK_HEIGHT
	local y = baseY - rng:NextNumber(20, CHUNK_HEIGHT - 20)
	local angle = rng:NextNumber(0, math.pi * 2)
	local depth = World.depthOf(Vector3.new(0, y, 0))
	local layer = Layers.at(depth)

	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local shelfCenter = outward * (SHAFT_RADIUS - 17)
	local cframe = CFrame.lookAt(Vector3.new(shelfCenter.X, y, shelfCenter.Z), Vector3.new(0, y, 0))

	local shelf = makePart("Shelf", Vector3.new(54, 3, 36), cframe, layerColor(layer), Enum.Material.Rock)
	shelf.Parent = parent

	for _ = 1, NODES_PER_SHELF do
		local offset = cframe:PointToWorldSpace(Vector3.new(rng:NextNumber(-15, 15), 3.4, rng:NextNumber(-9, 9)))
		spawnNode(parent, offset, World.depthOf(offset), layer)
	end

	-- A couple of nodes embedded in the wall above the shelf, so the shelf
	-- is a place to stand rather than the only place ore exists.
	for _ = 1, 2 do
		local wallAngle = angle + rng:NextNumber(-0.35, 0.35)
		local wallY = y + rng:NextNumber(6, 22)
		local position = Vector3.new(math.cos(wallAngle), 0, math.sin(wallAngle)) * (SHAFT_RADIUS - 3)
		local at = Vector3.new(position.X, wallY, position.Z)
		spawnNode(parent, at, World.depthOf(at), layer)
	end

	return shelf, cframe, y
end

local function buildLiftPad(parent: Instance, cframe: CFrame)
	local pad = makePart(
		"LiftPad",
		Vector3.new(12, 1.4, 12),
		cframe * CFrame.new(0, 2.6, 0),
		Color3.fromRGB(90, 255, 180),
		Enum.Material.Neon
	)
	pad:SetAttribute("LiftPad", true)
	pad.Parent = parent

	-- A column of green light running up the shaft. The label only reads at
	-- 260 studs and only if you are looking at it; this you see from anywhere
	-- in the chunk, which is the difference between "there is a way up" and
	-- "I could not find one".
	local column = makePart(
		"LiftBeacon",
		Vector3.new(3.2, 150, 3.2),
		cframe * CFrame.new(0, 78, 0),
		Color3.fromRGB(90, 255, 180),
		Enum.Material.Neon
	)
	column.CanCollide = false
	column.CastShadow = false
	column.Transparency = 0.82
	column.Parent = pad

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 255, 200)
	glow.Range = 34
	glow.Brightness = 3
	glow.Parent = pad

	attachLoop(pad, "liftMotor", 0.3, 90)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(9, 3)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 260
	billboard.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "▲ LIFT"
	label.TextColor3 = Color3.fromRGB(120, 255, 200)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = billboard
end

-- Hazard zones ------------------------------------------------------------

--- A danger zone you can see. Persistent kinds sit armed forever; pulsing
--- kinds run their own telegraph -> burst -> rest loop and flip an `Armed`
--- attribute, which is the only thing Server/Hazards.luau reads. Keeping the
--- animation here and the damage there means neither module has to know about
--- the other, which is what stops World and Economy forming a require cycle.
local function buildHazardZone(parent: Instance, cframe: CFrame, layer)
	local kind = HazardConfig.kindOf(layer)
	if not kind then
		return
	end

	local kindId = layer.hazard.kind
	local color = HazardConfig.color(kindId)

	local zone = makePart(
		"HazardZone",
		Vector3.new(kind.radius * 2, kind.height, kind.radius * 2),
		cframe * CFrame.new(0, kind.height / 2 - 2, 0),
		color,
		Enum.Material.ForceField
	)
	zone.CanCollide = false
	zone.Transparency = kind.transparency
	zone:SetAttribute("HazardZone", kindId)
	zone:SetAttribute("HazardRadius", kind.radius)
	zone:SetAttribute("HazardHeight", kind.height)
	zone:SetAttribute("Armed", kind.mode == "persistent")
	zone.Parent = parent

	local attachment = Instance.new("Attachment")
	attachment.Parent = zone

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.Size = NumberSequence.new(kind.mode == "pulsing" and 3.5 or 2.2)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Lifetime = NumberRange.new(1.4, 2.8)
	particles.Rate = kind.particleRate
	particles.Speed = NumberRange.new(kind.particleSpeed * 0.5, kind.particleSpeed)
	particles.SpreadAngle = Vector2.new(50, 50)
	particles.LightEmission = 0.7
	particles.Parent = attachment

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = kind.radius * 1.6
	light.Brightness = kind.mode == "persistent" and 1.6 or 0.5
	light.Parent = zone

	-- You should hear a gas pocket through rock before you round the corner
	-- into it. Range is generous for that reason.
	local slot = AudioConfig.ZoneLoops[kindId]
	if slot then
		attachLoop(zone, slot, kind.mode == "persistent" and 0.45 or 0.35, kind.radius * 6)
	end

	-- A floating sign, because a player should be able to name the thing that
	-- is about to hurt them before it does.
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(11, 3)
	billboard.StudsOffset = Vector3.new(0, kind.height / 2 + 3, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.Parent = zone

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = `{kind.icon} {kind.name}`
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard

	if kind.mode ~= "pulsing" then
		return
	end

	-- Pulsing zones are a rhythm, not a coin flip. Same period every cycle so
	-- a player can learn to walk through one.
	task.spawn(function()
		task.wait(rng:NextNumber(0, kind.rest))
		while zone.Parent do
			zone:SetAttribute("Armed", false)
			zone.Transparency = kind.transparency
			light.Brightness = 0.5
			particles.Rate = kind.particleRate * 0.4
			task.wait(kind.rest)
			if not zone.Parent then
				return
			end

			-- Telegraph: it gets brighter and louder before anything lands.
			particles.Rate = kind.particleRate * 1.6
			TweenService:Create(zone, TweenInfo.new(kind.telegraph), {
				Transparency = math.max(0, kind.transparency - 0.35),
			}):Play()
			TweenService:Create(light, TweenInfo.new(kind.telegraph), { Brightness = 5 }):Play()
			task.wait(kind.telegraph)
			if not zone.Parent then
				return
			end

			zone:SetAttribute("Armed", true)
			particles.Rate = kind.particleRate * 4
			zone.Transparency = math.max(0, kind.transparency - 0.5)

			if kind.debris then
				for _ = 1, 5 do
					local rock = makePart(
						"Debris",
						Vector3.new(rng:NextNumber(1.4, 3.4), rng:NextNumber(1.4, 3), rng:NextNumber(1.4, 3.4)),
						zone.CFrame * CFrame.new(
							rng:NextNumber(-kind.radius, kind.radius),
							kind.height / 2,
							rng:NextNumber(-kind.radius, kind.radius)
						),
						layerColor(layer),
						Enum.Material.Rock
					)
					rock.Anchored = false
					rock.CanCollide = false
					rock.Parent = zone.Parent
					task.delay(3, function()
						if rock.Parent then
							rock:Destroy()
						end
					end)
				end
			end

			task.wait(kind.active)
		end
	end)
end

-- Set dressing ------------------------------------------------------------

--- Rubble, a crate and a dropped lamp on a shelf. None of it is interactive;
--- all of it is the difference between "a ledge" and "somewhere people work".
local function dressShelf(parent: Instance, cframe: CFrame, layer)
	local color = layerColor(layer)

	for _ = 1, rng:NextInteger(3, 6) do
		local size = rng:NextNumber(1.2, 3.2)
		local rubble = makePart(
			"Rubble",
			Vector3.new(size, size * rng:NextNumber(0.5, 0.9), size * rng:NextNumber(0.7, 1.3)),
			cframe * CFrame.new(rng:NextNumber(-16, 16), 2 + size / 2, rng:NextNumber(-10, 10))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			color:Lerp(Color3.fromRGB(0, 0, 0), rng:NextNumber(0.1, 0.35)),
			Enum.Material.Rock
		)
		rubble.Parent = parent
	end

	if rng:NextNumber() < 0.45 then
		local crate = makePart(
			"Prop",
			Vector3.new(3.4, 3.4, 3.4),
			cframe * CFrame.new(rng:NextNumber(-14, 14), 3.7, rng:NextNumber(-8, 8))
				* CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color3.fromRGB(122, 88, 46),
			Enum.Material.WoodPlanks
		)
		crate.Parent = parent
	end

	if rng:NextNumber() < 0.5 then
		local lamp = makePart(
			"Prop",
			Vector3.new(1.2, 1.6, 1.2),
			cframe * CFrame.new(rng:NextNumber(-15, 15), 2.8, rng:NextNumber(-9, 9)),
			Color3.fromRGB(255, 226, 170),
			Enum.Material.Neon
		)

		lamp.Parent = parent

		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 214, 150)
		glow.Range = 26
		glow.Brightness = 2.2
		glow.Parent = lamp
	end
end

--- Timber frames and hanging lamps down the shaft wall. These do most of the
--- work of making the shaft feel built rather than generated: they give the
--- eye a repeating vertical rhythm to measure the fall against.
local function buildSupports(parent: Instance, chunkIndex: number)
	local baseY = -chunkIndex * CHUNK_HEIGHT
	local timber = Color3.fromRGB(96, 68, 38)

	for frame = 0, 1 do
		local y = baseY - 30 - frame * 78
		local angle = (chunkIndex * 1.1 + frame * 2.4) % (math.pi * 2)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = outward * (SHAFT_RADIUS - 2)
		local facing = CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(0, y, 0))

		local post = makePart("Support", Vector3.new(2.2, 26, 2.2), facing * CFrame.new(-9, 0, 0), timber, Enum.Material.Wood)
		post.Parent = parent

		local post2 = makePart("Support", Vector3.new(2.2, 26, 2.2), facing * CFrame.new(9, 0, 0), timber, Enum.Material.Wood)
		post2.Parent = parent

		local beam = makePart("Support", Vector3.new(20, 2.2, 2.2), facing * CFrame.new(0, 13, 0), timber, Enum.Material.Wood)
		beam.Parent = parent

		local lamp = makePart(
			"ShaftLamp",
			Vector3.new(1.6, 1.6, 1.6),
			facing * CFrame.new(0, 10, 1.4),
			Color3.fromRGB(255, 210, 140),
			Enum.Material.Neon
		)
		lamp.CanCollide = false
		lamp.Parent = parent

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 130)
		light.Range = 44
		light.Brightness = 2.6
		light.Parent = lamp
	end
end

--- Stalactites hanging into the shaft. Cheap, and they break up the ring
--- silhouette that otherwise reads as a stack of hoops.
local function buildStalactites(parent: Instance, chunkIndex: number, layer)
	local baseY = -chunkIndex * CHUNK_HEIGHT
	for _ = 1, 5 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local y = baseY - rng:NextNumber(4, CHUNK_HEIGHT - 4)
		local reach = rng:NextNumber(6, 18)
		local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHAFT_RADIUS - 4)
		local spike = makePart(
			"Spike",
			Vector3.new(rng:NextNumber(1.6, 3.6), reach, rng:NextNumber(1.6, 3.6)),
			CFrame.new(Vector3.new(at.X, y, at.Z))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			layerColor(layer):Lerp(Color3.fromRGB(0, 0, 0), 0.25),
			Enum.Material.Slate
		)
		spike.Parent = parent
	end
end

--- Decorative crystal clusters growing out of the wall.
---
--- Nothing to mine here — they carry no NodeId and targeting ignores them.
--- They exist because a 3,000m shaft of rock and six ore nodes per shelf
--- reads as unfinished, and because light coming out of the wall is what
--- makes a cave feel like a place rather than a tube. They take their colour
--- from the layer, so each stratum looks like somewhere else.
local function buildCrystals(parent: Instance, chunkIndex: number, layer)
	local baseY = -chunkIndex * CHUNK_HEIGHT
	local accent = layerColor(layer):Lerp(Color3.fromRGB(120, 210, 255), 0.65)

	for _ = 1, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local y = baseY - rng:NextNumber(6, CHUNK_HEIGHT - 6)
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local root = out * (SHAFT_RADIUS - 2)

		local anchorShard: BasePart? = nil
		for shard = 1, rng:NextInteger(2, 4) do
			local length = rng:NextNumber(2.5, 6.5)
			local jitter = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
			local crystal = makePart(
				"WallCrystal" .. shard,
				Vector3.new(rng:NextNumber(0.5, 1.1), length, rng:NextNumber(0.5, 1.1)),
				CFrame.new(Vector3.new(root.X, y, root.Z) + jitter)
					* CFrame.Angles(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0, 6), rng:NextNumber(-1.2, 1.2)),
				accent,
				Enum.Material.Neon
			)
			crystal.CanCollide = false
			crystal.CastShadow = false
			crystal.Transparency = 0.25
			crystal.Parent = parent
			anchorShard = anchorShard or crystal
		end

		if anchorShard then
			local glow = Instance.new("PointLight")
			glow.Range = 16
			glow.Brightness = 0.9
			glow.Color = accent
			glow.Parent = anchorShard
		end
	end
end

--- Lamps bolted to the shaft wall, every chunk, all the way down.
---
--- The strata carry their own ambient light and the ore lights itself, but
--- between the two there were long stretches lit by nothing at all. These
--- are what make the shaft read as a mine somebody built rather than a hole
--- that happens to have things in it — and they are the reason you can see
--- the far wall from a shelf.
local function buildLamps(parent: Instance, chunkIndex: number, layer)
	local baseY = -chunkIndex * CHUNK_HEIGHT
	local warm = Color3.fromRGB(255, 206, 140)

	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2 + chunkIndex * 0.4
		local y = baseY - (index / 6) * CHUNK_HEIGHT
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = out * (SHAFT_RADIUS - 3)

		local bracket = makePart(
			"LampBracket",
			Vector3.new(1.2, 1.2, 3),
			CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(0, y, 0)),
			Color3.fromRGB(52, 50, 56),
			Enum.Material.Metal
		)
		bracket.CanCollide = false
		bracket.Parent = parent

		local bulb = makePart(
			"LampBulb",
			Vector3.new(2.2, 0.8, 2.2),
			CFrame.new(bracket.Position) * CFrame.new(0, -1, 0),
			warm,
			Enum.Material.Neon
		)
		bulb.CanCollide = false
		bulb.CastShadow = false
		bulb.Parent = parent

		local light = Instance.new("PointLight")
		light.Color = warm
		-- Deep lamps burn harder: down there they are most of the light there
		-- is, and the layer ambient has fallen away.
		light.Range = 46 + math.min(chunkIndex, 20) * 0.8
		light.Brightness = 2.2 + math.min(chunkIndex / 14, 1.6)
		light.Parent = bulb
	end
end

local function buildChunk(chunkIndex: number)
	if chunks[chunkIndex] then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Chunk" .. chunkIndex
	chunks[chunkIndex] = folder

	local centerY = -chunkIndex * CHUNK_HEIGHT - CHUNK_HEIGHT / 2
	local depth = World.depthOf(Vector3.new(0, centerY, 0))
	local layer = Layers.at(depth)
	local color = layerColor(layer)

	-- Wall ring.
	local segmentWidth = 2 * math.pi * SHAFT_RADIUS / WALL_SEGMENTS + 4
	for i = 1, WALL_SEGMENTS do
		local angle = (i / WALL_SEGMENTS) * math.pi * 2
		local position = Vector3.new(math.cos(angle) * (SHAFT_RADIUS + 5), centerY, math.sin(angle) * (SHAFT_RADIUS + 5))
		local cframe = CFrame.lookAt(position, Vector3.new(0, centerY, 0))
		local wall = makePart(
			"Wall",
			Vector3.new(segmentWidth, CHUNK_HEIGHT + 2, 10),
			cframe,
			color:Lerp(Color3.fromRGB(0, 0, 0), rng:NextNumber(0, 0.18)),
			Enum.Material.Slate
		)
		wall.Parent = folder
	end

	buildSupports(folder, chunkIndex)
	buildStalactites(folder, chunkIndex, layer)
	buildCrystals(folder, chunkIndex, layer)
	buildLamps(folder, chunkIndex, layer)

	local hazardsWanted = HazardConfig.densityFor(layer)
	local hazardsPlaced = 0

	for slot = 1, SHELVES_PER_CHUNK do
		local _, cframe = buildShelf(folder, chunkIndex, slot)
		dressShelf(folder, cframe, layer)

		if slot == 1 and chunkIndex % LIFT_EVERY_CHUNKS == 0 and chunkIndex > 0 then
			buildLiftPad(folder, cframe)
		elseif hazardsPlaced < hazardsWanted then
			-- Never on the same shelf as a lift: the way out must always be
			-- somewhere a player can stand safely.
			buildHazardZone(folder, cframe * CFrame.new(rng:NextNumber(-10, 10), 0, 0), layer)
			hazardsPlaced += 1
		end
	end

	-- Any hazards the shelves could not hold go in the open shaft, where they
	-- are something to fall past rather than something to walk into.
	while hazardsPlaced < hazardsWanted do
		local angle = rng:NextNumber(0, math.pi * 2)
		local y = centerY + rng:NextNumber(-CHUNK_HEIGHT / 2, CHUNK_HEIGHT / 2)
		local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(10, SHAFT_RADIUS - 22)
		buildHazardZone(folder, CFrame.new(Vector3.new(at.X, y, at.Z)), layer)
		hazardsPlaced += 1
	end

	-- The floor of the world, and the way off it.
	--
	-- This used to be bedrock and nothing else, which made the bottom of the
	-- shaft a permanent trap: the nearest lift pad sat below the floor, the
	-- next two were 172 and 536 studs overhead, and a Roblox character jumps
	-- about seven. Anyone who fell the whole way was stuck for good.
	if depth >= MAX_DEPTH_METERS then
		local floorY = World.yForDepth(MAX_DEPTH_METERS) - 6
		local floor = makePart(
			"Bedrock",
			Vector3.new(SHAFT_RADIUS * 2.4, 12, SHAFT_RADIUS * 2.4),
			CFrame.new(0, floorY, 0),
			Color3.fromRGB(8, 6, 12),
			Enum.Material.Basalt
		)
		floor.Parent = folder

		local dais = makePart(
			"BedrockDais",
			Vector3.new(30, 2, 30),
			CFrame.new(0, floorY + 7, 0),
			Color3.fromRGB(22, 18, 30),
			Enum.Material.Slate
		)
		dais.Parent = folder

		buildLiftPad(folder, CFrame.new(0, floorY + 6, 0))
	end

	folder.Parent = container
end

local function destroyChunk(chunkIndex: number)
	local folder = chunks[chunkIndex]
	if not folder then
		return
	end

	for _, descendant in ipairs(folder:GetDescendants()) do
		local id = descendant:GetAttribute("NodeId")
		if id then
			nodes[id] = nil
		end
	end

	folder:Destroy()
	chunks[chunkIndex] = nil
end

-- Surface hub --------------------------------------------------------------

local function buildSurface()
	-- The place file ships with a floor and a spawn so that opening it in
	-- Studio shows something and nobody can arrive before the world does.
	-- Both sit over the shaft mouth, so they go the moment the real surface
	-- is about to exist.
	local placeholder = workspace:FindFirstChild("StudioPlaceholder")
	if placeholder then
		placeholder:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "Surface"

	-- Ring platform with the shaft mouth in the middle.
	local segments = 16
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local radius = SHAFT_RADIUS + 45
		local position = Vector3.new(math.cos(angle) * radius, -2, math.sin(angle) * radius)
		local slab = makePart(
			"Deck",
			Vector3.new(56, 4, 46),
			CFrame.lookAt(position, Vector3.new(0, -2, 0)),
			Color3.fromRGB(96, 100, 108),
			Enum.Material.Metal
		)
		slab.Parent = hub
	end

	-- The vault. Standing near this is what "banking" means.
	local vault = makePart(
		"Vault",
		Vector3.new(22, 16, 14),
		CFrame.new(0, 6, SHAFT_RADIUS + 34),
		Color3.fromRGB(232, 184, 66),
		Enum.Material.Metal
	)
	vault:SetAttribute("Vault", true)
	vault.Parent = hub
	World.vaultPosition = vault.Position

	local vaultSign = Instance.new("BillboardGui")
	vaultSign.Size = UDim2.fromScale(16, 5)
	vaultSign.StudsOffset = Vector3.new(0, 12, 0)
	vaultSign.AlwaysOnTop = false
	vaultSign.MaxDistance = 400
	vaultSign.Parent = vault

	local vaultLabel = Instance.new("TextLabel")
	vaultLabel.Size = UDim2.fromScale(1, 1)
	vaultLabel.BackgroundTransparency = 1
	vaultLabel.Font = Enum.Font.GothamBlack
	vaultLabel.Text = "💰 VAULT — bank your cargo here"
	vaultLabel.TextColor3 = Color3.fromRGB(255, 225, 140)
	vaultLabel.TextScaled = true
	vaultLabel.TextStrokeTransparency = 0.3
	vaultLabel.Parent = vaultSign

	-- Spawn ring, deliberately close to the shaft mouth: a new player should
	-- see the hole and the vault in the same glance.
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "SurfaceSpawn"
	spawnLocation.Size = Vector3.new(24, 1, 24)
	spawnLocation.CFrame = CFrame.new(0, 1, SHAFT_RADIUS + 18)
	spawnLocation.Anchored = true
	spawnLocation.Neutral = true
	spawnLocation.Color = Color3.fromRGB(Config.SpawnColor[1], Config.SpawnColor[2], Config.SpawnColor[3])
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Parent = hub

	-- A ring and a soft light around the pad. The surface has a gold vault, a
	-- green lift and red gate beacons; home needs its own colour or it is just
	-- another glowing square.
	local spawnColor = Color3.fromRGB(Config.SpawnColor[1], Config.SpawnColor[2], Config.SpawnColor[3])
	local ring = makePart(
		"SpawnRing",
		Vector3.new(34, 0.6, 34),
		CFrame.new(0, 0.4, SHAFT_RADIUS + 18),
		spawnColor,
		Enum.Material.Neon
	)
	ring.CanCollide = false
	ring.Transparency = 0.35
	ring.Parent = hub

	local spawnGlow = Instance.new("PointLight")
	spawnGlow.Color = spawnColor
	spawnGlow.Range = 40
	spawnGlow.Brightness = 2.4
	spawnGlow.Parent = spawnLocation
	World.spawnPosition = spawnLocation.Position + Vector3.new(0, 4, 0)

	local sign = makePart(
		"Sign",
		Vector3.new(40, 1, 1),
		CFrame.new(0, 14, SHAFT_RADIUS + 6),
		Color3.fromRGB(30, 30, 36),
		Enum.Material.SmoothPlastic
	)
	sign.Transparency = 1
	sign.CanCollide = false
	sign.Parent = hub

	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.fromScale(30, 6)
	signGui.AlwaysOnTop = false
	signGui.MaxDistance = 500
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.BackgroundTransparency = 1
	signLabel.Font = Enum.Font.GothamBlack
	signLabel.Text = "▼ JUMP IN ▼"
	signLabel.TextColor3 = Color3.fromRGB(255, 90, 120)
	signLabel.TextScaled = true
	signLabel.TextStrokeTransparency = 0.3
	signLabel.Parent = signGui

	-- Headframe over the shaft mouth. This is the silhouette every real mine
	-- has, and it is what turns "a hole in a platform" into a place.
	local steel = Color3.fromRGB(72, 76, 86)
	for leg = 1, 4 do
		local angle = (leg / 4) * math.pi * 2 + math.pi / 4
		local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHAFT_RADIUS + 12)
		local tower = makePart(
			"Headframe",
			Vector3.new(3, 78, 3),
			CFrame.new(at.X, 38, at.Z) * CFrame.Angles(math.rad(math.sin(angle) * 6), 0, math.rad(-math.cos(angle) * 6)),
			steel,
			Enum.Material.Metal
		)
		tower.Parent = hub

		local brace = makePart(
			"Headframe",
			Vector3.new(3, 2.4, 2.4),
			CFrame.new(at.X * 0.62, 62, at.Z * 0.62),
			steel,
			Enum.Material.Metal
		)
		brace.Parent = hub
	end

	local wheelHouse = makePart("Headframe", Vector3.new(26, 4, 26), CFrame.new(0, 78, 0), steel, Enum.Material.Metal)
	wheelHouse.Parent = hub

	local wheel = makePart("Wheel", Vector3.new(3, 22, 22), CFrame.new(0, 88, 0), Color3.fromRGB(198, 96, 40), Enum.Material.Metal)
	wheel.Shape = Enum.PartType.Cylinder
	wheel.CanCollide = false
	wheel.Parent = hub

	-- A solid railing with a gate. Solid, because a barrier you walk through
	-- is scenery pretending to be architecture. With a gate, because jumping
	-- into the shaft is the entire game and the way in has to be obvious.
	local GATE_ANGLE = math.pi / 2 -- the spawn sits on +Z
	local GATE_HALF_WIDTH = 0.42 -- radians; about a 48-degree opening
	for post = 1, 28 do
		local angle = (post / 28) * math.pi * 2
		local offset = math.abs(((angle - GATE_ANGLE + math.pi) % (math.pi * 2)) - math.pi)
		if offset > GATE_HALF_WIDTH then
			local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHAFT_RADIUS + 4)
			local rail = makePart("Rail", Vector3.new(1.1, 5, 1.1), CFrame.new(at.X, 2.5, at.Z), Color3.fromRGB(216, 170, 60), Enum.Material.Metal)
			rail.Parent = hub
		end
	end

	-- Gate posts, taller and lit, so the opening reads as the entrance rather
	-- than as a hole someone forgot to fence.
	for _, side in ipairs({ -1, 1 }) do
		local angle = GATE_ANGLE + side * GATE_HALF_WIDTH
		local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHAFT_RADIUS + 4)
		local gatePost = makePart("GatePost", Vector3.new(2, 11, 2), CFrame.new(at.X, 5.5, at.Z), Color3.fromRGB(232, 184, 66), Enum.Material.Metal)
		gatePost.Parent = hub

		local beacon = makePart("GateBeacon", Vector3.new(2.4, 1.4, 2.4), CFrame.new(at.X, 11.4, at.Z), Color3.fromRGB(255, 120, 90), Enum.Material.Neon)
		beacon.CanCollide = false
		beacon.Parent = hub

		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 120, 90)
		glow.Range = 26
		glow.Brightness = 3
		glow.Parent = beacon
	end

	-- Floodlights. The surface should be the brightest place in the game, so
	-- that descending visibly costs you light.
	for mast = 1, 4 do
		local angle = (mast / 4) * math.pi * 2 + 0.4
		local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHAFT_RADIUS + 40)
		local pole = makePart("Mast", Vector3.new(1.6, 30, 1.6), CFrame.new(at.X, 15, at.Z), steel, Enum.Material.Metal)
		pole.Parent = hub

		local head = makePart("Floodlight", Vector3.new(5, 3, 5), CFrame.new(at.X, 30, at.Z), Color3.fromRGB(255, 246, 214), Enum.Material.Neon)
		head.CanCollide = false
		head.Parent = hub

		local beam = Instance.new("SpotLight")
		beam.Color = Color3.fromRGB(255, 240, 205)
		beam.Range = 90
		beam.Brightness = 3
		beam.Angle = 110
		beam.Face = Enum.NormalId.Bottom
		beam.Parent = head
	end

	-- The upgrade shack, opposite the vault. It has no function; it is there
	-- so the surface has two landmarks instead of one, which is what makes it
	-- possible to say "meet me by the shack".
	local shack = makePart("Shack", Vector3.new(20, 12, 16), CFrame.new(-46, 4, SHAFT_RADIUS + 22), Color3.fromRGB(108, 74, 44), Enum.Material.WoodPlanks)
	shack.Parent = hub

	local roof = makePart("Shack", Vector3.new(24, 1.4, 20), CFrame.new(-46, 10.6, SHAFT_RADIUS + 22), Color3.fromRGB(150, 62, 42), Enum.Material.Metal)
	roof.Parent = hub

	local shackSign = Instance.new("BillboardGui")
	shackSign.Size = UDim2.fromScale(14, 3.5)
	shackSign.StudsOffset = Vector3.new(0, 9, 0)
	shackSign.MaxDistance = 300
	shackSign.Parent = shack

	local shackLabel = Instance.new("TextLabel")
	shackLabel.Size = UDim2.fromScale(1, 1)
	shackLabel.BackgroundTransparency = 1
	shackLabel.Font = Enum.Font.GothamBlack
	shackLabel.Text = "⛏️ UPGRADES"
	shackLabel.TextColor3 = Color3.fromRGB(120, 230, 255)
	shackLabel.TextScaled = true
	shackLabel.TextStrokeTransparency = 0.35
	shackLabel.Parent = shackSign

	-- Vault door, so the vault looks like something you put things into.
	local door = makePart("VaultDoor", Vector3.new(9, 11, 1.4), CFrame.new(0, 5, SHAFT_RADIUS + 26.6), Color3.fromRGB(52, 44, 24), Enum.Material.Metal)
	door.Parent = hub

	local dial = makePart("VaultDial", Vector3.new(1, 4, 4), CFrame.new(0, 6, SHAFT_RADIUS + 25.8), Color3.fromRGB(255, 226, 150), Enum.Material.Metal)
	dial.Shape = Enum.PartType.Cylinder
	dial.CanCollide = false
	dial.Parent = hub

	-- Scattered props. Cheap, and they carry most of the "people work here".
	local propRng = Random.new(4242)
	for _ = 1, 22 do
		local angle = propRng:NextNumber(0, math.pi * 2)
		local distance = propRng:NextNumber(SHAFT_RADIUS + 12, SHAFT_RADIUS + 62)
		local at = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local roll = propRng:NextNumber()

		if roll < 0.45 then
			local crate = makePart("Prop", Vector3.new(4, 4, 4), CFrame.new(at.X, 2, at.Z) * CFrame.Angles(0, propRng:NextNumber(0, 6), 0), Color3.fromRGB(122, 88, 46), Enum.Material.WoodPlanks)
			crate.Parent = hub
		elseif roll < 0.75 then
			local barrel = makePart("Prop", Vector3.new(3.6, 5, 3.6), CFrame.new(at.X, 2.5, at.Z), Color3.fromRGB(70, 96, 78), Enum.Material.Metal)
			barrel.Shape = Enum.PartType.Cylinder
			barrel.CFrame = CFrame.new(at.X, 2.5, at.Z) * CFrame.Angles(0, 0, math.rad(90))
			barrel.Parent = hub
		else
			local pile = makePart("Prop", Vector3.new(propRng:NextNumber(2, 5), propRng:NextNumber(1.4, 3), propRng:NextNumber(2, 5)), CFrame.new(at.X, 1.4, at.Z) * CFrame.Angles(0, propRng:NextNumber(0, 6), 0), Color3.fromRGB(96, 88, 78), Enum.Material.Rock)
			pile.Parent = hub
		end
	end

	hub.Parent = container
end

-- Crates -------------------------------------------------------------------

--- Drop a lootable crate. Owner-only for a few seconds, then anyone's.
function World.spawnCrate(position: Vector3, ownerUserId: number, items, value: number)
	local id = uid("crate")

	local part = makePart(
		"CargoCrate",
		Vector3.new(5, 5, 5),
		CFrame.new(position),
		Color3.fromRGB(214, 160, 60),
		Enum.Material.WoodPlanks
	)
	part:SetAttribute("CrateId", id)
	part:SetAttribute("Owner", ownerUserId)
	part.Anchored = false
	part.Parent = crateContainer

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 200, 90)
	light.Range = 20
	light.Brightness = 2
	light.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 3)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "📦 CARGO"
	label.TextColor3 = Color3.fromRGB(255, 210, 120)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Parent = billboard

	-- It drops so it lands on whatever shelf is below you, then freezes.
	-- Left unanchored it would keep falling to the bottom of the shaft and be
	-- unrecoverable by the person who just lost it.
	task.delay(2.5, function()
		if part.Parent then
			part.Anchored = true
		end
	end)

	crates[id] = {
		id = id,
		part = part,
		owner = ownerUserId,
		items = items,
		value = value,
		openAt = os.time() + Config.CrateFreeForAllDelay,
	}

	task.delay(Config.CrateLifetime, function()
		World.removeCrate(id)
	end)

	return id
end

function World.getCrate(crateId: string)
	local crate = crates[crateId]
	if crate and crate.part.Parent then
		return crate
	end
	return nil
end

function World.removeCrate(crateId: string)
	local crate = crates[crateId]
	if not crate then
		return
	end
	if crate.part.Parent then
		crate.part:Destroy()
	end
	crates[crateId] = nil
end

function World.cratesNear(position: Vector3, radius: number)
	local found = {}
	for _, crate in pairs(crates) do
		if crate.part.Parent and (crate.part.Position - position).Magnitude <= radius then
			table.insert(found, crate)
		end
	end
	return found
end

-- Lifecycle ----------------------------------------------------------------

local function streamChunks()
	local wanted = { [0] = true }

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local index = math.max(0, math.floor(-root.Position.Y / CHUNK_HEIGHT))
			for offset = -KEEP_RADIUS, KEEP_RADIUS do
				local target = index + offset
				if target >= 0 and World.depthOf(Vector3.new(0, -target * CHUNK_HEIGHT, 0)) <= MAX_DEPTH_METERS then
					wanted[target] = true
				end
			end
		end
	end

	for index in pairs(wanted) do
		buildChunk(index)
	end
	for index in pairs(chunks) do
		if not wanted[index] then
			destroyChunk(index)
		end
	end
end

function World.start()
	-- FallenPartsDestroyHeight is NOT set here, and that is not an oversight.
	-- Roblox only lets a plugin write it, so the assignment threw with
	-- "lacking capability Plugin" and took the entire world generator with
	-- it. It is a saved property, so the builder writes -9,400 straight into
	-- the place file instead; see tools/build-rbxlx.mjs.
	--
	-- Why it has to be moved rather than dropped: the default is -500 and this
	-- shaft bottoms out at -9,000, so at the default the lower two thirds of
	-- the world — and every player and dropped crate in it — is deleted on
	-- arrival.

	container = Instance.new("Folder")
	container.Name = "DeepRushWorld"
	container.Parent = workspace

	crateContainer = Instance.new("Folder")
	crateContainer.Name = "Crates"
	crateContainer.Parent = container

	buildSurface()
	buildChunk(0)
	buildChunk(1)

	task.spawn(function()
		while true do
			streamChunks()
			task.wait(1)
		end
	end)

	-- Nobody falls out of the world.
	--
	-- Raising FallenPartsDestroyHeight to clear the shaft had a cost nobody
	-- would guess: a player who ends up under the geometry no longer dies and
	-- respawns after a second, they fall for ten. That reads exactly like a
	-- broken game. Bedrock is solid so this should never fire, but "should
	-- never" is not a thing to leave to chunk streaming.
	task.spawn(function()
		local floorY = World.yForDepth(MAX_DEPTH_METERS) - 30
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < floorY and World.spawnPosition then
					root.CFrame = CFrame.new(World.spawnPosition)
				end
			end
		end
	end)
end

return World
