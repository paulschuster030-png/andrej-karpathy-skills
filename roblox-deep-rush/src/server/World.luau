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

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
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
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
	end

	task.delay(Config.NodeRespawn, function()
		if node.part.Parent then
			node.alive = true
			node.part.Transparency = 0
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

	for slot = 1, SHELVES_PER_CHUNK do
		local _, cframe = buildShelf(folder, chunkIndex, slot)
		if slot == 1 and chunkIndex % LIFT_EVERY_CHUNKS == 0 and chunkIndex > 0 then
			buildLiftPad(folder, cframe)
		end
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
