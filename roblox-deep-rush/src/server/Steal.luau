--!nonstrict
--[[
	Steal.luau — the social hook, and the part most likely to be abused.

	Two ways to take someone else's loot:
	  CRATES   when a miner dies, most of their unbanked cargo drops as a
	           crate. Theirs alone for a few seconds, then anyone's.
	  SNATCH   a short-range pull that only works on a MARKED player — one
	           whose hold is past the greed threshold.

	The design constraint we refuse to break: greed must be the only thing
	that makes you stealable. A cautious player can never be griefed, a
	brand-new player is immune outright, and a rich player who banks often is
	never a target. That turns theft from harassment into a bet the victim
	knowingly took.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local CrewConfig = require(Shared.Config.Crew)
local DroneConfig = require(Shared.Config.Drones)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Cargo = require(script.Parent.Cargo)
local Crew = require(script.Parent.Crew)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local World = require(script.Parent.World)
local Feedback = require(script.Parent.Feedback)
local Quests = require(script.Parent.Quests)

local Steal = {}

local function rootOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--- New players cannot steal and cannot be stolen from. Both halves matter:
--- the first stops alt-account farming, the second stops the experience
--- every new player would otherwise have in their first two minutes.
function Steal.isProtected(player: Player): boolean
	local profile = Data.get(player)
	local session = Data.session(player)
	if not profile or not session then
		return true
	end

	local played = profile.stats.playtime + (os.clock() - session.joinedAt)
	if played < Config.NewPlayerGraceSeconds and profile.stats.bestDepth < Config.NewPlayerGraceDepth then
		return true
	end
	return false
end

local function nearestMarkedTarget(thief: Player)
	local root = rootOf(thief)
	if not root then
		return nil
	end

	local best, bestDistance = nil, Config.SnatchRange
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= thief and not Steal.isProtected(other) and Cargo.isMarked(other) then
			local otherRoot = rootOf(other)
			if otherRoot then
				local distance = (otherRoot.Position - root.Position).Magnitude
				if distance <= bestDistance then
					best, bestDistance = other, distance
				end
			end
		end
	end
	return best
end

function Steal.snatch(thief: Player)
	local session = Data.session(thief)
	if not session then
		return
	end

	if Steal.isProtected(thief) then
		Feedback.toast(thief, {
			title = "NOT YET",
			body = `Reach {Config.NewPlayerGraceDepth}m first. Until then nobody can rob you either.`,
			kind = "error",
		})
		return
	end

	local remaining = Config.SnatchCooldown - (os.time() - (session.lastSnatch or 0))
	if remaining > 0 then
		Feedback.toast(thief, { title = "SNATCH COOLING", body = `{math.ceil(remaining)}s left.`, kind = "error" })
		return
	end

	local victim = nearestMarkedTarget(thief)
	if not victim then
		Feedback.toast(thief, {
			title = "NO MARKED MINER",
			body = "Only greedy holds glow. Get closer to one.",
			kind = "error",
		})
		return
	end

	session.lastSnatch = os.time()

	-- Safe Pocket shrinks what can be taken, it never blocks the snatch —
	-- a fully immune target would make the marked glow a lie.
	local share = Config.GreedStealShare * (1 - Economy.protectedShare(victim))
	local items, value = Cargo.take(victim, share)
	if #items == 0 then
		return
	end

	local gained = Cargo.give(thief, items)

	local profile = Data.get(thief)
	if profile then
		profile.stats.steals += 1
		Data.push(thief, { stats = { steals = profile.stats.steals } })
	end
	Quests.record(thief, "steal", 1)
	Quests.record(thief, "steal_alltime", 1)

	Feedback.effect(thief, "snatch", { amount = gained, victim = victim.DisplayName })
	Feedback.toast(thief, {
		title = "SNATCHED " .. Format.short(gained),
		body = `Off {victim.DisplayName}. Bank it before someone does it to you.`,
		kind = "steal",
	})
	Feedback.effect(victim, "robbed", { amount = value, thief = thief.DisplayName })
	Feedback.toast(victim, {
		title = "-" .. Format.short(value),
		body = `{thief.DisplayName} snatched your cargo. Bank earlier next time.`,
		kind = "error",
	})
end

--- `maxDistance` exists for the Magnet Drone, whose reach is larger than a
--- player's arm. Requests coming from the client always use the default.
function Steal.grabCrate(player: Player, crateId: string, maxDistance: number?)
	local crate = World.getCrate(crateId)
	local root = rootOf(player)
	if not crate or not root then
		return
	end

	if (crate.part.Position - root.Position).Magnitude > (maxDistance or 14) then
		return
	end

	local isOwner = player.UserId == crate.owner
	if not isOwner and os.time() < crate.openAt then
		Feedback.toast(player, { title = "STILL THEIRS", body = "Wait for the crate to unlock.", kind = "error" })
		return
	end

	local gained = Cargo.give(player, crate.items)
	World.removeCrate(crateId)

	if not isOwner then
		local profile = Data.get(player)
		if profile then
			profile.stats.steals += 1
			Data.push(player, { stats = { steals = profile.stats.steals } })
		end
		Quests.record(player, "steal", 1)
		Quests.record(player, "steal_alltime", 1)
	end

	Feedback.effect(player, "crate", { amount = gained })
	Feedback.toast(player, {
		title = "+" .. Format.short(gained) .. " CARGO",
		body = isOwner and "Recovered your own crate." or "Someone else's bad day.",
		kind = "steal",
	})
end

--- Death: split the hold into kept / dropped / burned.
local function onDeath(player: Player)
	local profile = Data.get(player)
	local session = Data.session(player)
	if not profile or not session then
		return
	end

	local root = rootOf(player)
	local position = root and root.Position or Vector3.new(0, 10, 0)

	local items, value = Cargo.clear(player)
	profile.stats.deaths += 1
	session.cleanBanks = 0
	session.runDepth = 0
	Data.push(player, { stats = { deaths = profile.stats.deaths } })
	Quests.record(player, "clean_banks", 0, "set")

	if #items == 0 then
		return
	end

	-- Safe Pocket keeps a slice in hand through the respawn.
	local keepCount = math.floor(#items * Economy.protectedShare(player))
	local kept = {}
	for _ = 1, keepCount do
		local entry = table.remove(items)
		if not entry then
			break
		end
		table.insert(kept, entry)
	end

	local dropCount = math.floor(#items * (1 - Config.DeathCargoLoss))
	local dropped, droppedValue = {}, 0
	for _ = 1, dropCount do
		local entry = table.remove(items)
		if not entry then
			break
		end
		table.insert(dropped, entry)
		droppedValue += entry.value
	end

	session.pendingRestore = kept
	-- Whatever is still in `items` at this point burned on the way down.

	local crateId = nil
	if #dropped > 0 then
		crateId = World.spawnCrate(position + Vector3.new(0, 3, 0), player.UserId, dropped, droppedValue)
		Feedback.toast(player, {
			title = "CARGO DROPPED",
			body = `{Format.short(droppedValue)} is lying where you died. It unlocks to everyone in {Config.CrateFreeForAllDelay}s.`,
			kind = "error",
			duration = 6,
		})
	end

	-- Everything that left the hold, remembered for the Cargo Insurance
	-- product. The crate id rides along so a restore also removes the crate —
	-- otherwise a player could loot their own crate AND buy the recovery.
	local lost = {}
	for _, entry in ipairs(dropped) do
		table.insert(lost, entry)
	end
	for _, entry in ipairs(items) do
		table.insert(lost, entry)
	end
	session.lastLoss = { items = lost, crateId = crateId, at = os.time() }
end

--- The opposite of a snatch: give a crewmate's dropped crate back to them
--- and take a finder's fee in cash. In a game built on theft, one clearly
--- cooperative action is what makes a crew read as a crew.
function Steal.rescue(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end

	for _, crate in ipairs(World.cratesNear(root.Position, CrewConfig.RescueRadius)) do
		local owner = Players:GetPlayerByUserId(crate.owner)
		if owner and owner ~= player and Crew.isMate(player, owner) then
			local returned = Cargo.give(owner, crate.items)
			World.removeCrate(crate.id)

			local fee = math.floor(crate.value * CrewConfig.RescueReward)
			Economy.addCash(player, fee)
			Quests.record(player, "rescue", 1)

			Feedback.effect(player, "crate", { amount = fee })
			Feedback.toast(player, {
				title = "CARGO RETURNED",
				body = `Gave {owner.DisplayName} their haul back. Finder's fee: {Format.short(fee)}.`,
				kind = "quest",
			})
			Feedback.toast(owner, {
				title = "+" .. Format.short(returned) .. " RECOVERED",
				body = `{player.DisplayName} brought your cargo back.`,
				kind = "cash",
			})
			return
		end
	end

	Feedback.toast(player, {
		title = "NOTHING TO RETURN",
		body = "Stand next to a crewmate's dropped crate.",
		kind = "error",
	})
end

--- Magnet Drone: hoover nearby crates without touching them.
local function magnetSweep()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Data.get(player)
		local root = rootOf(player)
		if profile and root then
			local radius = DroneConfig.bonusesOf(profile.drones.equipped).magnet
			if radius > 0 then
				for _, crate in ipairs(World.cratesNear(root.Position, radius)) do
					if player.UserId == crate.owner or os.time() >= crate.openAt then
						Steal.grabCrate(player, crate.id, radius)
					end
				end
			end
		end
	end
end

function Steal.start()
	Net.on("Snatch", function(player)
		Steal.snatch(player)
	end)

	Net.on("Rescue", function(player)
		Steal.rescue(player)
	end)

	Net.on("GrabCrate", function(player, crateId)
		if type(crateId) == "string" then
			Steal.grabCrate(player, crateId)
		end
	end)

	local function hookCharacter(player: Player, character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			onDeath(player)
		end)

		-- Hand back whatever Safe Pocket saved.
		local session = Data.session(player)
		if session and session.pendingRestore then
			for _, entry in ipairs(session.pendingRestore) do
				Cargo.add(player, entry)
			end
			session.pendingRestore = nil
		end
	end

	local function hookPlayer(player: Player)
		if player.Character then
			task.spawn(hookCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			hookCharacter(player, character)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end
	Players.PlayerAdded:Connect(hookPlayer)

	-- Broadcast who is marked so clients can render the glow and the radar.
	task.spawn(function()
		while true do
			task.wait(1)
			local marked = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if not Steal.isProtected(player) and Cargo.isMarked(player) then
					table.insert(marked, player.UserId)
				end
			end
			Net.all("Marked", marked)
			magnetSweep()
		end
	end)
end

return Steal
