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
local Config = require(Shared.Config.Game)
local HazardConfig = require(Shared.Config.Hazards)
local Layers = require(Shared.Config.Layers)

local World = {}

local CHUNK_HEIGHT = 150 -- studs
local SHAFT_RADIUS = 62
local WALL_SEGMENTS = 10
local SHELVES_PER_CHUNK = 2
local NODES_PER_SHELF = 6
local LIFT_EVERY_CHUNKS = 2
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

local function layerColor(layer): Color3
	return Color3.fromRGB(layer.rock[1], layer.rock[2], layer.rock[3])
end

-- Ore nodes ----------------------------------------------------------------

local function spawnNode(parent: Instance, position: Vector3, depth: number, layer)
	local id = uid("node")
	local size = rng:NextNumber(3.2, 5.4)

	local part = makePart(
		"OreNode",
		Vector3.new(size, size, size),
		CFrame.new(position) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
		layerColor(layer):Lerp(Color3.fromRGB(255, 255, 255), 0.18),
		Enum.Material.Slate
	)
	part.CanCollide = false
	part:SetAttribute("NodeId", id)
	part:SetAttribute("Depth", math.floor(depth))
	part.Parent = parent

	-- A faint glow so nodes read as targets at a glance, brighter the deeper
	-- you are (where the ambient light is nearly gone).
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 0.6 + math.min(depth / 1500, 1.4)
	light.Color = layerColor(layer):Lerp(Color3.fromRGB(255, 220, 150), 0.5)
	light.Parent = part

	-- Shards around the main block. A single cube reads as a placeholder; a
	-- cluster reads as a vein someone has to dig out. They carry no NodeId, so
	-- targeting and mining still see exactly one node.
	for shard = 1, rng:NextInteger(2, 4) do
		local shardSize = size * rng:NextNumber(0.3, 0.55)
		local offset = Vector3.new(
			rng:NextNumber(-size * 0.6, size * 0.6),
			rng:NextNumber(-size * 0.5, size * 0.5),
			rng:NextNumber(-size * 0.6, size * 0.6)
		)
		local piece = makePart(
			"Shard" .. shard,
			Vector3.new(shardSize, shardSize * rng:NextNumber(1.1, 2.2), shardSize),
			CFrame.new(position + offset)
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)),
			part.Color:Lerp(Color3.fromRGB(255, 255, 255), 0.25),
			Enum.Material.Glass
		)
		piece.CanCollide = false
		piece.Transparency = 0.15
		piece.Parent = part
	end

	nodes[id] = { id = id, part = part, depth = depth, alive = true }
	return id
end

function World.getNode(nodeId: string)
	local node = nodes[nodeId]
	if node and node.alive and node.part.Parent then
		return node
	end
	return nil
end

--- Break a node: hide it, then bring it back. We never destroy and recreate
--- because the id has to stay stable for the client's target lock.
function World.consumeNode(nodeId: string)
	local node = nodes[nodeId]
	if not node or not node.alive then
		return
	end

	node.alive = false
	local part = node.part
	if part.Parent then
		part.Transparency = 1
		for _, piece in ipairs(part:GetChildren()) do
			if piece:IsA("BasePart") then
				piece.Transparency = 1
			end
		end
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
	end

	task.delay(Config.NodeRespawn, function()
		if node.part.Parent then
			node.alive = true
			node.part.Transparency = 0
			for _, piece in ipairs(node.part:GetChildren()) do
				if piece:IsA("BasePart") then
					piece.Transparency = 0.15
				end
			end
			local light = node.part:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = true
			end
		end
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

	local shelf = makePart("Shelf", Vector3.new(38, 3, 26), cframe, layerColor(layer), Enum.Material.Rock)
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
		rubble.CanCollide = false
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
		lamp.CanCollide = false
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
		post.CanCollide = false
		post.Parent = parent

		local post2 = makePart("Support", Vector3.new(2.2, 26, 2.2), facing * CFrame.new(9, 0, 0), timber, Enum.Material.Wood)
		post2.CanCollide = false
		post2.Parent = parent

		local beam = makePart("Support", Vector3.new(20, 2.2, 2.2), facing * CFrame.new(0, 13, 0), timber, Enum.Material.Wood)
		beam.CanCollide = false
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
		spike.CanCollide = false
		spike.Parent = parent
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

	-- The floor of the world.
	if depth >= MAX_DEPTH_METERS then
		local floor = makePart(
			"Bedrock",
			Vector3.new(SHAFT_RADIUS * 2.4, 12, SHAFT_RADIUS * 2.4),
			CFrame.new(0, World.yForDepth(MAX_DEPTH_METERS) - 6, 0),
			Color3.fromRGB(8, 6, 12),
			Enum.Material.Basalt
		)
		floor.Parent = folder
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
	spawnLocation.Color = Color3.fromRGB(120, 200, 255)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Parent = hub
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
		brace.CanCollide = false
		brace.Parent = hub
	end

	local wheelHouse = makePart("Headframe", Vector3.new(26, 4, 26), CFrame.new(0, 78, 0), steel, Enum.Material.Metal)
	wheelHouse.CanCollide = false
	wheelHouse.Parent = hub

	local wheel = makePart("Wheel", Vector3.new(3, 22, 22), CFrame.new(0, 88, 0), Color3.fromRGB(198, 96, 40), Enum.Material.Metal)
	wheel.Shape = Enum.PartType.Cylinder
	wheel.CanCollide = false
	wheel.Parent = hub

	-- Railing around the mouth, so the drop reads as deliberate rather than
	-- like the floor simply stops.
	for post = 1, 28 do
		local angle = (post / 28) * math.pi * 2
		local at = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (SHAFT_RADIUS + 4)
		local rail = makePart("Rail", Vector3.new(0.7, 4.2, 0.7), CFrame.new(at.X, 2.1, at.Z), Color3.fromRGB(216, 170, 60), Enum.Material.Metal)
		rail.CanCollide = false
		rail.Parent = hub
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
	roof.CanCollide = false
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
	door.CanCollide = false
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
			pile.CanCollide = false
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
end

return World
