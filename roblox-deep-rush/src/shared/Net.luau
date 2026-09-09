--!nonstrict
--[[
	Net.luau — every remote in the game, declared in one place.

	The server builds the remote tree on first require; the client waits for
	it. Server handlers get a token-bucket rate limit for free, because an
	unthrottled RemoteEvent is the single most common way a Roblox game gets
	taken apart by an exploiter.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local IS_SERVER = RunService:IsServer()

-- name -> requests per second allowed from a single client.
-- Mining is the hot path; everything else is a UI click.
Net.Events = {
	Mine = 12,
	Bank = 4,
	BuyUpgrade = 8,
	BuyDrone = 4,
	EquipDrone = 4,
	Snatch = 2,
	GrabCrate = 6,
	ClaimQuest = 8,
	RerollDaily = 2,
	Rebirth = 2,
	UseLift = 3,
	ReportDepth = 20,

	-- Co-play. Ping is the only one with real traffic; it is the entire
	-- coordination vocabulary now that chat is age-gated.
	CrewBeacon = 2,
	CrewJoin = 3,
	CrewLeave = 3,
	Ping = 3,
	Rescue = 4,

	-- Long-arc retention and status.
	ClaimContract = 6,
	ClaimDescent = 6,
	EquipCosmetic = 6,
	BuyCosmetic = 4,
	WatchAd = 1,
}

-- Server -> client only.
Net.Signals = {
	"State", -- partial state patch
	"Toast", -- corner notification
	"Reveal", -- big centre-screen ore reveal
	"Rift", -- rift start/stop/tick
	"Effect", -- one-shot client feedback (shake, sfx, particles)
	"Marked", -- another player crossed the greed threshold
	"Crew", -- crew roster and nearby beacons
	"Pings", -- a teammate marked something in the world
	"Ad", -- rewarded-video availability changed
}

Net.Functions = {
	"GetState",
	"GetBoards",
}

local root: Instance
local events: Folder
local signals: Folder
local functions: Folder

local function build()
	if IS_SERVER then
		root = Instance.new("Folder")
		root.Name = "DeepRushNet"

		events = Instance.new("Folder")
		events.Name = "Events"
		events.Parent = root

		signals = Instance.new("Folder")
		signals.Name = "Signals"
		signals.Parent = root

		functions = Instance.new("Folder")
		functions.Name = "Functions"
		functions.Parent = root

		for name in pairs(Net.Events) do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = events
		end
		for _, name in ipairs(Net.Signals) do
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = signals
		end
		for _, name in ipairs(Net.Functions) do
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = functions
		end

		root.Parent = ReplicatedStorage
	else
		root = ReplicatedStorage:WaitForChild("DeepRushNet", 30)
		assert(root, "DeepRush: server never published its remotes")
		events = root:WaitForChild("Events")
		signals = root:WaitForChild("Signals")
		functions = root:WaitForChild("Functions")
	end
end

build()

-- Rate limiting -----------------------------------------------------------
local buckets: { [Player]: { [string]: { tokens: number, last: number } } } = {}

Players.PlayerRemoving:Connect(function(player)
	buckets[player] = nil
end)

local function allow(player: Player, name: string, perSecond: number): boolean
	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local bucket = playerBuckets[name]
	local now = os.clock()
	if not bucket then
		bucket = { tokens = perSecond, last = now }
		playerBuckets[name] = bucket
	end

	-- Refill, capped at one second of burst.
	bucket.tokens = math.min(perSecond, bucket.tokens + (now - bucket.last) * perSecond)
	bucket.last = now

	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

-- Server API --------------------------------------------------------------

--- Handle a client event. Over-rate calls are dropped silently — telling a
--- cheater which limit they hit is free information for them.
function Net.on(name: string, handler: (Player, ...any) -> ())
	assert(IS_SERVER, "Net.on is server-only")
	local perSecond = Net.Events[name]
	assert(perSecond, `Net: unknown event "{name}"`)

	events[name].OnServerEvent:Connect(function(player, ...)
		if not allow(player, name, perSecond) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(`DeepRush: handler "{name}" failed for {player.Name}: {err}`)
		end
	end)
end

function Net.handle(name: string, handler: (Player, ...any) -> any)
	assert(IS_SERVER, "Net.handle is server-only")
	functions[name].OnServerInvoke = function(player, ...)
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`DeepRush: function "{name}" failed for {player.Name}: {result}`)
			return nil
		end
		return result
	end
end

function Net.to(player: Player, signal: string, ...)
	assert(IS_SERVER, "Net.to is server-only")
	local remote = signals:FindFirstChild(signal)
	if remote then
		remote:FireClient(player, ...)
	end
end

function Net.all(signal: string, ...)
	assert(IS_SERVER, "Net.all is server-only")
	local remote = signals:FindFirstChild(signal)
	if remote then
		remote:FireAllClients(...)
	end
end

function Net.except(skip: Player, signal: string, ...)
	assert(IS_SERVER, "Net.except is server-only")
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= skip then
			Net.to(player, signal, ...)
		end
	end
end

-- Client API --------------------------------------------------------------

function Net.fire(name: string, ...)
	assert(not IS_SERVER, "Net.fire is client-only")
	events[name]:FireServer(...)
end

function Net.listen(signal: string, handler: (...any) -> ())
	assert(not IS_SERVER, "Net.listen is client-only")
	return signals[signal].OnClientEvent:Connect(handler)
end

function Net.invoke(name: string, ...)
	assert(not IS_SERVER, "Net.invoke is client-only")
	return functions[name]:InvokeServer(...)
end

return Net
