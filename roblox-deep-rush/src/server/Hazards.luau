--!nonstrict
--[[
	Hazards.luau — oxygen, and standing in the wrong place.

	Two pressures, and they work differently on purpose:

	  OXYGEN  a soft timer that scales with the layer. It never kills you
	          outright at first, it chews health, which is your cue to run for
	          a lift. This is the cost of depth itself.

	  ZONES   damage for being somewhere specific. Every hazard is a visible
	          object placed by Server/World.luau — a gas cloud, a magma vent,
	          a frost field — and this module only asks "is the player inside
	          one, and is it armed right now".

	The zone rewrite replaced a per-second dice roll that hurt you from
	nowhere. The old version was technically fair (it telegraphed) and felt
	arbitrary, because danger had no location: you could not look at a room
	and know where not to stand. Now you can, and every hit traces back to
	something the player could see.

	World owns the zones and their timing; this owns the consequences. Neither
	requires the other, which is what keeps World out of the Economy cycle.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local HazardConfig = require(Shared.Config.Hazards)
local Layers = require(Shared.Config.Layers)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)
local World = require(script.Parent.World)

local Hazards = {}

local SURFACE_DEPTH = 15 -- above this, you are breathing normally
local SUFFOCATION_DPS = 6
local SCAN_RADIUS = 30 -- studs; bigger than the largest zone
local BURST_DEBOUNCE = 1.6 -- one pulsing zone cannot hit twice inside this

-- player -> { [zone] = timestamp } of the last burst that landed.
local lastBurst: { [Player]: { [Instance]: number } } = {}
-- player -> zone they are currently inside, for enter/leave messaging.
local inside: { [Player]: Instance? } = {}
-- players whose walkspeed we have modified, so we can hand it back.
local slowed: { [Player]: boolean } = {}

local function humanoidOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--- The armed zone the player is standing in, if any.
local function zoneAt(player: Player)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end

	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, SCAN_RADIUS)) do
		local kindId = part:GetAttribute("HazardZone")
		if kindId then
			local radius = part:GetAttribute("HazardRadius") or 12
			local height = part:GetAttribute("HazardHeight") or 12
			local offset = root.Position - part.Position
			local horizontal = Vector2.new(offset.X, offset.Z).Magnitude
			if horizontal <= radius and math.abs(offset.Y) <= height / 2 then
				return part, HazardConfig.Kinds[kindId]
			end
		end
	end

	return nil, nil
end

local function restoreSpeed(player: Player)
	if slowed[player] then
		slowed[player] = nil
		Economy.applyCharacter(player)
	end
end

local function applyZone(player: Player, zone: Instance?, kind, delta: number)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local previous = inside[player]
	inside[player] = zone

	if zone == nil then
		if previous then
			restoreSpeed(player)
		end
		return
	end

	-- Entering is announced once, with the hint that tells you the counter.
	if previous ~= zone then
		Feedback.effect(player, "hazardWarn", { kind = kind.name, text = kind.hint })
		Feedback.toast(player, {
			title = `{kind.icon} {kind.name}`,
			body = kind.hint,
			kind = "error",
			duration = 4,
		})
	end

	local resist = 1 - Economy.hazardResist(player)

	if kind.slow then
		slowed[player] = true
		humanoid.WalkSpeed = Economy.walkSpeed(player) * kind.slow
	end

	if not zone:GetAttribute("Armed") then
		return
	end

	if kind.mode == "persistent" then
		humanoid:TakeDamage(kind.dps * delta * resist)
		Feedback.effect(player, "hazardTick", { kind = kind.name })
		return
	end

	-- Pulsing: one burst is one hit, however long the window lasts.
	local record = lastBurst[player]
	if not record then
		record = {}
		lastBurst[player] = record
	end

	local now = os.clock()
	if now - (record[zone] or 0) < BURST_DEBOUNCE then
		return
	end
	record[zone] = now

	humanoid:TakeDamage(kind.burst * resist)
	Feedback.effect(player, "hazardHit", { kind = kind.name, text = kind.name, damage = kind.burst })
end

local function tick(delta: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local session = Data.session(player)
		local humanoid = humanoidOf(player)

		if not session or not humanoid or humanoid.Health <= 0 then
			inside[player] = nil
			continue
		end

		-- Measured here rather than read from session.depth, which another
		-- loop maintains at a different rate. Reading it meant a player who
		-- had just surfaced kept suffocating for a tick or two on a stale
		-- number — invisible in play, and the sort of ordering bug that only
		-- ever gets worse.
		local root = rootOf(player)
		local depth = root and World.depthOf(root.Position) or 0
		local layer = Layers.at(depth)
		local maxOxygen = Economy.maxOxygen(player)

		if depth <= SURFACE_DEPTH then
			session.oxygen = math.min(maxOxygen, (session.oxygen or maxOxygen) + Config.OxygenRegenRate * delta)
		else
			session.oxygen = (session.oxygen or maxOxygen) - layer.oxygenDrain * delta
			if session.oxygen <= 0 then
				session.oxygen = 0
				humanoid:TakeDamage(SUFFOCATION_DPS * delta * (1 - Economy.hazardResist(player)))
				Feedback.effect(player, "suffocating", {})
			end
		end

		-- The tick is fast so zones feel responsive; the oxygen bar does not
		-- need that rate, so it is replicated about once a second.
		session.oxygenPushed = (session.oxygenPushed or 0) + delta
		if session.oxygenPushed >= 1 then
			session.oxygenPushed = 0
			Data.push(player, { oxygen = session.oxygen, oxygenMax = maxOxygen })
		end

		local zone, kind = zoneAt(player)
		applyZone(player, zone, kind, delta)
	end
end

function Hazards.start()
	Players.PlayerRemoving:Connect(function(player)
		lastBurst[player] = nil
		inside[player] = nil
		slowed[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.HazardTickRate)
			local now = os.clock()
			local delta = now - last
			last = now
			tick(delta)
		end
	end)
end

return Hazards
