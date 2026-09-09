--!nonstrict
--[[
	Mining.luau — the swing, the roll, and the moment the number pops.

	Server-authoritative by construction: the client asks to start mining a
	node id, the server decides how long that takes, checks every 100ms that
	the player is still in range and alive, and only then rolls the ore. A
	client that spams Mine gets rate-limited by Net; a client that lies about
	its position gets caught by the range check here and by AntiCheat.

	Value is stored PRE-multiplier in cargo. The cash multiplier is applied
	at the vault, so the deposit screen can show "x3.5" as a visible reward
	rather than silently inflating every rock.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Layers = require(Shared.Config.Layers)
local Ores = require(Shared.Config.Ores)
local Mutations = require(Shared.Config.Mutations)
local DroneConfig = require(Shared.Config.Drones)
local Rarity = require(Shared.Rarity)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Cargo = require(script.Parent.Cargo)
local Contracts = require(script.Parent.Contracts)
local ContractConfig = require(Shared.Config.Contracts)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)
local Quests = require(script.Parent.Quests)
local Rift = require(script.Parent.Rift)
local World = require(script.Parent.World)

local Mining = {}

local REVEAL_FROM_TIER = 4 -- Epic and up get the full-screen card
local ANNOUNCE_FROM_TIER = 6 -- Mythic and up wake the whole server
local RANGE_SLACK = 6 -- studs of forgiveness for latency

local rng = Random.new(os.time() + 4242)

local function rootOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function inRange(player: Player, node): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	return (root.Position - node.part.Position).Magnitude <= Config.MineReach + RANGE_SLACK
end

--- Drones are found, not farmed. This is the only place they drop.
local function rollDroneDrop(player: Player, depth: number, luck: number)
	local profile = Data.get(player)
	if not profile then
		return
	end

	if rng:NextNumber() > DroneConfig.dropChance(depth, luck) then
		return
	end

	local candidates = DroneConfig.droppableAt(depth)
	for _, drone in ipairs(candidates) do
		if not profile.drones.owned[drone.id] then
			profile.drones.owned[drone.id] = true
			if not profile.drones.equipped then
				profile.drones.equipped = drone.id
			end
			Data.push(player, { drones = Data.replace(table.clone(profile.drones)) })
			Feedback.reveal(player, {
				title = "DRONE FOUND",
				name = drone.name,
				tier = drone.rarity,
				body = drone.desc,
				kind = "drone",
			})
			Feedback.announce("🛠️ DRONE FOUND", `{player.DisplayName} pulled a {drone.name} out of {Format.depth(depth)}.`, { 120, 220, 255 })
			return
		end
	end
end

local function award(player: Player, node)
	local profile = Data.get(player)
	local session = Data.session(player)
	if not profile or not session then
		return
	end

	local depth = node.depth
	local riftActive = Rift.isActiveFor(player)
	local luck = math.min(Economy.luck(player) * Rift.luckMultiplier(player), Config.MaxLuck)

	local ore, probability = Rarity.rollOre(depth, luck, rng)
	if not ore then
		return
	end

	local mutation = Mutations.roll(luck, riftActive, rng)
	local tierIndex = Ores.TierIndex[ore.tier]
	local value = math.floor(ore.value * Layers.depthMultiplier(depth) * (mutation and mutation.multiplier or 1))

	local entry = {
		oreId = ore.id,
		tier = ore.tier,
		mutation = mutation and mutation.id or nil,
		value = value,
	}

	if not Cargo.add(player, entry) then
		Feedback.toast(player, {
			title = "CARGO FULL",
			body = "Ride a lift up and bank it.",
			kind = "error",
		})
		Feedback.effect(player, "full", {})
		return
	end

	World.consumeNode(node.id)

	-- Codex: first-time finds are their own small event.
	local isNew = (profile.codex[ore.id] or 0) == 0
	profile.codex[ore.id] = (profile.codex[ore.id] or 0) + 1
	profile.stats.minedTotal += 1

	local codexCount = 0
	for _ in pairs(profile.codex) do
		codexCount += 1
	end

	Data.push(player, {
		codex = { [ore.id] = profile.codex[ore.id] },
		stats = { minedTotal = profile.stats.minedTotal },
	})

	-- Quest metrics.
	Quests.record(player, "mine", 1)
	Quests.record(player, "codex", codexCount, "max")
	if tierIndex >= 3 then
		Quests.record(player, "mine_rare", 1)
	end
	if tierIndex >= 4 then
		Quests.record(player, "mine_epic", 1)
	end
	if riftActive then
		Quests.record(player, "rift_mine", 1)
		Contracts.award(player, ContractConfig.Points.perRiftOre)
	end

	if isNew then
		Contracts.award(player, ContractConfig.Points.newCodexEntry)
	elseif tierIndex >= 4 then
		Contracts.award(player, ContractConfig.Points.perEpicOre)
	elseif tierIndex >= 3 then
		Contracts.award(player, ContractConfig.Points.perRareOre)
	end

	-- Feedback, scaled to how rare the thing actually was.
	local displayName = mutation and `{mutation.name} {ore.name}` or ore.name
	Feedback.effect(player, "mined", {
		tier = ore.tier,
		value = value,
		name = displayName,
		mutation = entry.mutation,
		position = node.part.Position,
	})

	if tierIndex >= REVEAL_FROM_TIER or mutation or isNew then
		Feedback.reveal(player, {
			title = isNew and "NEW DISCOVERY" or "RARE PULL",
			name = displayName,
			tier = ore.tier,
			mutation = entry.mutation,
			value = value,
			odds = probability,
			kind = "ore",
		})
	end

	if tierIndex >= ANNOUNCE_FROM_TIER then
		local tier = Ores.tier(ore.tier)
		Feedback.announce(
			`💎 {string.upper(ore.tier)}`,
			`{player.DisplayName} pulled {displayName} worth {Format.short(value)} at {Format.depth(depth)}.`,
			tier.color
		)
	end

	rollDroneDrop(player, depth, luck)
end

--- Start (or restart) a swing. The client re-fires this to chain nodes.
function Mining.begin(player: Player, nodeId: string)
	if not isAlive(player) then
		return
	end
	local session = Data.session(player)
	local node = World.getNode(nodeId)
	if not session or not node or not inRange(player, node) then
		return
	end

	if Cargo.isFull(player) then
		Feedback.toast(player, { title = "CARGO FULL", body = "Bank it before you dig more.", kind = "error" })
		return
	end

	local duration = Economy.mineTime(player)
	session.mining = {
		nodeId = nodeId,
		endsAt = os.clock() + duration,
		duration = duration,
	}
	Feedback.effect(player, "swing", { duration = duration, nodeId = nodeId })
end

function Mining.stop(player: Player)
	local session = Data.session(player)
	if session then
		session.mining = nil
	end
end

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local session = Data.session(player)
		local active = session and session.mining
		if active then
			local node = World.getNode(active.nodeId)
			if not node or not inRange(player, node) or not isAlive(player) then
				session.mining = nil
			elseif os.clock() >= active.endsAt then
				session.mining = nil
				award(player, node)
			end
		end
	end
end

function Mining.start()
	Net.on("Mine", function(player, nodeId)
		if type(nodeId) == "string" then
			Mining.begin(player, nodeId)
		end
	end)

	--- Depth is reported by the client (it owns the character) but it is only
	--- ever used for display, rift eligibility and hazards — never for pay.
	--- Payout depth comes from the node's own recorded position.
	Net.on("ReportDepth", function(player)
		local session = Data.session(player)
		local root = rootOf(player)
		if not session or not root then
			return
		end

		local depth = World.depthOf(root.Position)
		session.depth = depth

		local profile = Data.get(player)
		if profile and depth > profile.stats.bestDepth then
			local gained = depth - profile.stats.bestDepth
			profile.stats.bestDepth = depth
			Data.push(player, { stats = { bestDepth = depth } })
			Quests.record(player, "depth_alltime", depth, "max")
			Contracts.award(player, gained * ContractConfig.Points.perDepthRecord)
		end
		Quests.record(player, "depth", depth, "max")
		Data.push(player, { depth = depth })
	end)

	task.spawn(function()
		while true do
			step()
			task.wait(0.1)
		end
	end)
end

return Mining
