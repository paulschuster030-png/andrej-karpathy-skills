--!nonstrict
--[[
	robloxstub.luau — enough of the Roblox API to actually RUN the server.

	The compile check proves the code parses. The protocol check proves the
	two halves agree on their remotes. Neither proves the lift works.

	This does: it stubs Instances, Vector3/CFrame, the task scheduler and the
	services, so tools/sim-spec.luau can start the real server modules, join a
	fake player, and assert that mining a node fills cargo and standing on a
	lift pad puts you back at the surface.

	Deliberate limitations, so nobody reads more into a green run than is there:
	  * CFrame carries position and ignores rotation. Every check that depends
	    on orientation is out of scope.
	  * There is no physics. Nothing falls, nothing collides. Collision
	    settings are recorded so they can be asserted, not simulated.
	  * Time is virtual and advanced by hand, which is a feature: node
	    respawns and lift channels are tested in milliseconds.
]]

local Stub = {}

-- Scheduler ---------------------------------------------------------------
-- Cooperative and virtual. Server modules are full of `while true do ...
-- task.wait(n) end`, which would hang a real run; here they park and only
-- advance when the spec says so.

local clock = 0
local sleeping = {} -- { thread, wakeAt }

local function schedule(thread, delay)
	table.insert(sleeping, { thread = thread, wakeAt = clock + math.max(delay or 0, 0) })
end

local taskLib = {}

function taskLib.wait(duration)
	local thread = coroutine.running()
	schedule(thread, duration or 0)
	return coroutine.yield()
end

function taskLib.spawn(fn, ...)
	local thread = coroutine.create(fn)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		error("task.spawn: " .. tostring(err), 0)
	end
	return thread
end

function taskLib.delay(duration, fn, ...)
	local args = table.pack(...)
	local thread = coroutine.create(function()
		taskLib.wait(duration)
		fn(table.unpack(args, 1, args.n))
	end)
	local ok, err = coroutine.resume(thread)
	if not ok then
		error("task.delay: " .. tostring(err), 0)
	end
	return thread
end

function taskLib.defer(fn, ...)
	return taskLib.delay(0, fn, ...)
end

--- Push virtual time forward, waking anything due. Steps in small slices so
--- a loop that waits 0.1s runs the right number of times across a 5s advance.
function Stub.advance(seconds, slice)
	slice = slice or 0.05
	local target = clock + seconds
	while clock < target do
		clock = math.min(clock + slice, target)
		local due = {}
		local remaining = {}
		for _, entry in ipairs(sleeping) do
			if entry.wakeAt <= clock then
				table.insert(due, entry)
			else
				table.insert(remaining, entry)
			end
		end
		sleeping = remaining
		for _, entry in ipairs(due) do
			if coroutine.status(entry.thread) == "suspended" then
				local ok, err = coroutine.resume(entry.thread)
				if not ok then
					error("scheduled thread: " .. tostring(err), 0)
				end
			end
		end
	end
end

function Stub.now()
	return clock
end

-- Signals -----------------------------------------------------------------

local function makeSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(fn)
		table.insert(handlers, fn)
		local connection = {}
		function connection:Disconnect()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end
		connection.Connected = true
		return connection
	end

	function signal:Once(fn)
		local connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)
		return connection
	end

	function signal:Wait()
		-- Nothing in the server blocks on a signal we do not also fire, so
		-- returning immediately is safe and keeps the scheduler simple.
		return nil
	end

	function signal:Fire(...)
		for _, fn in ipairs(table.clone(handlers)) do
			local ok, err = pcall(fn, ...)
			if not ok then
				error("signal handler: " .. tostring(err), 0)
			end
		end
	end

	return signal
end

Stub.makeSignal = makeSignal

-- Maths -------------------------------------------------------------------

local Vector3 = {}
Vector3.__index = Vector3

local function vec(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

function Vector3.new(x, y, z)
	return vec(x, y, z)
end

Vector3.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end

Vector3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	elseif key == "Unit" then
		local m = math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
		if m == 0 then return vec(0, 0, 0) end
		return vec(self.X / m, self.Y / m, self.Z / m)
	end
	return rawget(Vector3, key)
end

function Vector3:Dot(other)
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

local Vector2 = {}
Vector2.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2)
	end
	return rawget(Vector2, key)
end
local function vec2(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end

local CFrame = {}
CFrame.__index = function(self, key)
	if key == "Position" or key == "p" then
		return rawget(self, "_position")
	end
	if key == "LookVector" then
		return vec(0, 0, -1)
	end
	return rawget(CFrame, key)
end
CFrame.__mul = function(a, b)
	if getmetatable(b) == CFrame then
		return CFrame.new(a._position + b._position)
	end
	return CFrame.new(a._position + b)
end

function CFrame.new(x, y, z)
	local position = type(x) == "table" and x or vec(x, y, z)
	return setmetatable({ _position = position }, CFrame)
end

function CFrame.Angles()
	return CFrame.new(0, 0, 0)
end

function CFrame.lookAt(from)
	return CFrame.new(from)
end

function CFrame:PointToWorldSpace(offset)
	return self._position + offset
end

local Color3 = {}
Color3.__index = Color3
function Color3.fromRGB(r, g, b)
	return setmetatable({ R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }, Color3)
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end
function Color3:Lerp(other, alpha)
	return Color3.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

local RandomClass = {}
RandomClass.__index = RandomClass
function RandomClass:NextNumber(min, max)
	if min == nil then return math.random() end
	return min + math.random() * (max - min)
end
function RandomClass:NextInteger(min, max)
	return math.random(min, max)
end
local Random = {}
function Random.new(seed)
	if seed then math.randomseed(math.floor(seed) % 2147483647) end
	return setmetatable({}, RandomClass)
end

-- UI and sequence datatypes -----------------------------------------------
-- Only shapes, no behaviour: the server builds billboards and trails, and
-- nothing in a headless run reads these back.

local UDim2 = {}
function UDim2.new(sx, ox, sy, oy) return { ScaleX = sx, OffsetX = ox, ScaleY = sy, OffsetY = oy } end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end

local UDim = {}
function UDim.new(scale, offset) return { Scale = scale, Offset = offset } end

local NumberRange = {}
function NumberRange.new(min, max) return { Min = min, Max = max or min } end

local NumberSequenceKeypoint = {}
function NumberSequenceKeypoint.new(time, value) return { Time = time, Value = value } end

local NumberSequence = {}
function NumberSequence.new(value) return { Keypoints = value } end

local ColorSequence = {}
function ColorSequence.new(value) return { Keypoints = value } end

local TweenInfo = {}
function TweenInfo.new(...) return { ... } end

-- Enums -------------------------------------------------------------------
-- Any Enum.Whatever.Value resolves to a stable token, which is all the server
-- code does with them.

local function enumBucket(name)
	return setmetatable({}, {
		__index = function(_, key)
			return { EnumType = name, Name = key, Value = key }
		end,
	})
end

local Enum = setmetatable({}, {
	__index = function(_, key)
		return enumBucket(key)
	end,
})

-- Instances ---------------------------------------------------------------

local allParts = {}

local PART_CLASSES = {
	Part = true, SpawnLocation = true, MeshPart = true, WedgePart = true,
}

local function newInstance(className)
	local children = {}
	local attributes = {}
	local proxy = {}

	local fields = {
		ClassName = className,
		Name = className,
		Parent = nil,
		Anchored = false,
		CanCollide = true,
		Transparency = 0,
		Size = vec(1, 1, 1),
		Position = vec(0, 0, 0),
		CFrame = CFrame.new(0, 0, 0),
		Value = nil,
		Enabled = true,
		Health = 100,
		WalkSpeed = 16,
		Volume = 0,
	}

	local api = {}

	function api:IsA(query)
		if query == className then return true end
		if query == "BasePart" then return PART_CLASSES[className] == true end
		if query == "GuiObject" then return className:find("Label") ~= nil or className:find("Frame") ~= nil end
		return false
	end

	function api:GetChildren()
		return table.clone(children)
	end

	function api:GetDescendants()
		local out = {}
		for _, child in ipairs(children) do
			table.insert(out, child)
			for _, deep in ipairs(child:GetDescendants()) do
				table.insert(out, deep)
			end
		end
		return out
	end

	function api:FindFirstChild(name)
		for _, child in ipairs(children) do
			if child.Name == name then return child end
		end
		return nil
	end

	function api:FindFirstChildOfClass(query)
		for _, child in ipairs(children) do
			if child.ClassName == query then return child end
		end
		return nil
	end

	function api:WaitForChild(name)
		return api:FindFirstChild(name)
	end

	function api:SetAttribute(key, value)
		attributes[key] = value
	end

	function api:GetAttribute(key)
		return attributes[key]
	end

	function api:Destroy()
		fields.Parent = nil
		local index = table.find(allParts, proxy)
		if index then table.remove(allParts, index) end
	end

	function api:Clone()
		return newInstance(className)
	end

	function api:Play() end
	function api:Emit() end
	function api:TakeDamage(amount)
		fields.Health = math.max(0, fields.Health - amount)
	end
	function api:GetPropertyChangedSignal()
		return makeSignal()
	end

	-- Events every stubbed instance may be asked for.
	local events = {
		Touched = makeSignal(),
		Died = makeSignal(),
		CharacterAdded = makeSignal(),
		Changed = makeSignal(),
		Activated = makeSignal(),
		OnServerEvent = makeSignal(),
		OnClientEvent = makeSignal(),
		Completed = makeSignal(),
	}

	setmetatable(proxy, {
		__index = function(_, key)
			if api[key] ~= nil then return api[key] end
			if events[key] ~= nil then return events[key] end
			if key == "_children" then return children end
			if key == "_attributes" then return attributes end
			if fields[key] ~= nil then return fields[key] end
			-- Roblox instances resolve unknown names to children, which is how
			-- `remotesFolder.Mine` works. Without this the whole Net module
			-- looks broken when it is fine.
			for _, child in ipairs(children) do
				if child.Name == key then return child end
			end
			return nil
		end,
		__newindex = function(_, key, value)
			if key == "Parent" then
				local previous = fields.Parent
				if previous then
					local list = previous._children
					local index = table.find(list, proxy)
					if index then table.remove(list, index) end
				end
				fields.Parent = value
				if value then
					table.insert(value._children, proxy)
				end
				return
			end
			if key == "CFrame" then
				fields.CFrame = value
				fields.Position = value.Position
				return
			end
			if key == "Position" then
				fields.Position = value
				fields.CFrame = CFrame.new(value)
				return
			end
			fields[key] = value
		end,
	})

	-- RemoteEvent / RemoteFunction surface.
	if className == "RemoteEvent" then
		function api:FireClient(...) end
		function api:FireAllClients(...) end
	elseif className == "RemoteFunction" then
		fields.OnServerInvoke = nil
	end

	if PART_CLASSES[className] then
		table.insert(allParts, proxy)
	end

	return proxy
end

local Instance = {}
function Instance.new(className)
	return newInstance(className)
end

-- Services ----------------------------------------------------------------

local services = {}

local function makePlayers()
	local players = newInstance("Players")
	players.Name = "Players"
	local list = {}

	players.PlayerAdded = makeSignal()
	players.PlayerRemoving = makeSignal()

	function players:GetPlayers()
		return table.clone(list)
	end

	function players:GetPlayerByUserId(userId)
		for _, player in ipairs(list) do
			if player.UserId == userId then return player end
		end
		return nil
	end

	function players:GetNameFromUserIdAsync(userId)
		return "User" .. userId
	end

	--- Test helper: join a player with a character standing at `position`.
	function players:_join(name, userId, position)
		local player = newInstance("Player")
		player.Name = name
		player.UserId = userId
		player.DisplayName = name

		local character = newInstance("Model")
		character.Name = name

		local root = newInstance("Part")
		root.Name = "HumanoidRootPart"
		root.Position = position or vec(0, 5, 0)
		root.Parent = character

		local humanoid = newInstance("Humanoid")
		humanoid.Name = "Humanoid"
		humanoid.Parent = character

		-- R15 naming; Server/Tools.luau also accepts the R6 "Right Arm".
		local hand = newInstance("Part")
		hand.Name = "RightHand"
		hand.Position = position or vec(0, 5, 0)
		hand.Parent = character

		-- Server/Cosmetics.luau hangs the nameplate here, so without a Head
		-- the rank badge silently never exists and the spec cannot see it.
		local head = newInstance("Part")
		head.Name = "Head"
		head.Position = position or vec(0, 5, 0)
		head.Parent = character

		player.Character = character
		player.Parent = players

		table.insert(list, player)
		players.PlayerAdded:Fire(player)
		return player
	end

	function players:_leave(player)
		local index = table.find(list, player)
		if index then table.remove(list, index) end
		players.PlayerRemoving:Fire(player)
	end

	return players
end

local function makeWorkspace()
	local workspace = newInstance("Workspace")
	workspace.Name = "Workspace"
	workspace.FallenPartsDestroyHeight = -500 -- Roblox's default

	function workspace:GetPartBoundsInRadius(position, radius)
		local found = {}
		for _, part in ipairs(allParts) do
			if part.Parent ~= nil and (part.Position - position).Magnitude <= radius then
				table.insert(found, part)
			end
		end
		return found
	end

	return workspace
end

function Stub.build(sharedTree)
	local players = makePlayers()
	local workspace = makeWorkspace()

	local replicatedStorage = newInstance("ReplicatedStorage")
	replicatedStorage.Name = "ReplicatedStorage"
	if sharedTree then
		sharedTree.Parent = replicatedStorage
	end

	services.Players = players
	services.Workspace = workspace
	services.ReplicatedStorage = replicatedStorage
	services.RunService = (function()
		local run = newInstance("RunService")
		run.Heartbeat = makeSignal()
		run.RenderStepped = makeSignal()
		function run:IsServer() return true end
		function run:IsStudio() return false end
		return run
	end)()
	services.TweenService = (function()
		local tween = newInstance("TweenService")
		function tween:Create()
			local handle = newInstance("Tween")
			function handle:Play() end
			return handle
		end
		return tween
	end)()
	services.Debris = (function()
		local debris = newInstance("Debris")
		function debris:AddItem() end
		return debris
	end)()
	services.MarketplaceService = (function()
		local market = newInstance("MarketplaceService")
		market.PromptGamePassPurchaseFinished = makeSignal()
		function market:UserOwnsGamePassAsync() return false end
		return market
	end)()
	services.DataStoreService = (function()
		local store = newInstance("DataStoreService")
		function store:GetDataStore() return nil end
		function store:GetOrderedDataStore() return nil end
		return store
	end)()
	services.AdService = (function()
		local ads = newInstance("AdService")
		ads.Loaded = makeSignal()
		function ads:IsLoaded() return true end
		return ads
	end)()
	services.SocialService = newInstance("SocialService")
	services.SoundService = newInstance("SoundService")
	services.Lighting = newInstance("Lighting")
	services.ContextActionService = newInstance("ContextActionService")
	services.UserInputService = newInstance("UserInputService")

	local game = newInstance("DataModel")
	game.JobId = "simulation"
	function game:GetService(name)
		local service = services[name]
		if not service then
			service = newInstance(name)
			services[name] = service
		end
		return service
	end
	function game:BindToClose() end

	return {
		game = game,
		workspace = workspace,
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = { new = vec2 },
		CFrame = CFrame,
		Color3 = Color3,
		Random = Random,
		Enum = Enum,
		task = taskLib,
		UDim2 = UDim2,
		UDim = UDim,
		NumberRange = NumberRange,
		NumberSequence = NumberSequence,
		NumberSequenceKeypoint = NumberSequenceKeypoint,
		ColorSequence = ColorSequence,
		TweenInfo = TweenInfo,
		players = players,
		services = services,
		allParts = allParts,
	}
end

return Stub
