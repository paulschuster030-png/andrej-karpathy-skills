--!nonstrict
--[[
	sim-spec.luau — does the game actually work.

	Every check here drives the real server modules through the real remotes:
	it joins a player, puts them next to a rock, fires Mine, and asserts the
	cargo changed. Nothing is mocked except Roblox itself.

	Run via tools/sim-check.py.
]]

local failures = 0
local checks = 0

local function check(name: string, condition: boolean, detail: string?)
	checks += 1
	if condition then
		print(string.format("  ok   %s", name))
	else
		failures += 1
		print(string.format("  FAIL %s%s", name, detail and ("  — " .. detail) or ""))
	end
end

local function advance(seconds: number)
	Stub.advance(seconds)
end

-- Remote plumbing ---------------------------------------------------------

local net = game:GetService("ReplicatedStorage"):FindFirstChild("DeepRushNet")

--- Call a RemoteFunction the way a client would.
local function invoke(functionName: string, player, ...)
	local functions = net and net:FindFirstChild("Functions")
	local remote = functions and functions:FindFirstChild(functionName)
	if not remote or not remote.OnServerInvoke then
		error("no such remote function: " .. functionName, 0)
	end
	return remote.OnServerInvoke(player, ...)
end

local function fire(eventName: string, player, ...)
	local events = net and net:FindFirstChild("Events")
	local remote = events and events:FindFirstChild(eventName)
	if not remote then
		error("no such remote: " .. eventName, 0)
	end
	remote.OnServerEvent:Fire(player, ...)
end

local function partsWithAttribute(attribute: string)
	local found = {}
	for _, part in ipairs(ENV.allParts) do
		if part.Parent ~= nil and part:GetAttribute(attribute) ~= nil then
			table.insert(found, part)
		end
	end
	return found
end

local function moveTo(player, position)
	player.Character.HumanoidRootPart.Position = position
end

print("\n== boot ==")

local SERVICES = {
	"Data", "World", "Crew", "Economy", "Cargo", "Cosmetics", "Contracts",
	"Tools", "Quests", "Rift", "Season", "Mining", "Surface", "Steal", "Hazards",
	"Upgrades", "Rebirth", "Drones", "Rewards", "Leaderboards", "Monetization",
	"Ads", "AntiCheat",
}

-- The place file ships a floor and a spawn in Workspace so Studio has
-- something to show before any code runs. Stand one up here so the spec can
-- prove the world takes it away again — it sits over the shaft mouth, and
-- leaving it would seal the hole the whole game drops through.
local placeholder = Instance.new("Folder")
placeholder.Name = "StudioPlaceholder"
placeholder.Parent = workspace

local bootOk, bootErr = pcall(function()
	for _, name in ipairs(SERVICES) do
		SERVER[name].start()
	end
end)
check("every service starts", bootOk, bootErr and tostring(bootErr))
check("the remote tree is published", net ~= nil)

advance(2)

print("\n== the world ==")

check("the shipped placeholder floor is cleared away", (function()
	return workspace:FindFirstChild("StudioPlaceholder") == nil
end)())

check("the surface built a vault", SERVER.World.vaultPosition ~= nil)
check("the surface built a spawn", SERVER.World.spawnPosition ~= nil)

local nodes = partsWithAttribute("NodeId")
check("ore nodes exist", #nodes > 0, `found {#nodes}`)

check("the world sits above Roblox's delete floor", (function()
	-- Default FallenPartsDestroyHeight is -500 and the shaft bottoms out at
	-- -9,000. Left at the default, the lower two thirds of the world and
	-- everyone in it would be deleted on arrival.
	local floor = workspace.FallenPartsDestroyHeight
	local bedrock = SERVER.World.yForDepth(3000)
	print(string.format("       destroy height %.0f, bedrock %.0f", floor, bedrock))
	return floor < bedrock
end)())

check("ore nodes are solid", (function()
	-- The bug a player spots in the first ten seconds: walking through rock.
	for _, node in ipairs(nodes) do
		if node.CanCollide ~= true then
			return false
		end
	end
	return true
end)())

check("every node says what is in it", (function()
	-- The whole point of pre-rolling the ore at spawn: a player can read the
	-- wall. A node without an Ore attribute is a node the HUD, the highlight
	-- and the reticle will all shrug at.
	local seen = {}
	for _, node in ipairs(nodes) do
		local ore = node:GetAttribute("Ore")
		if not ore or not MODULES.Ores.ById[ore] then
			return false
		end
		seen[ore] = (seen[ore] or 0) + 1
	end
	local kinds = 0
	for _ in pairs(seen) do
		kinds += 1
	end
	print(string.format("       %d nodes across %d different ores", #nodes, kinds))
	return kinds > 1
end)())

check("the rock is lit by what is in it", (function()
	-- A gold seam and a coal lump must not glow the same colour, or none of
	-- the above is visible from more than two studs away.
	for _, node in ipairs(nodes) do
		local light = node:FindFirstChild("Glow")
		if not light then
			return false
		end
		local vein = MODULES.Ores.appearance(node:GetAttribute("Ore")).color
		local want = ENV.Color3.fromRGB(vein[1], vein[2], vein[3])
		if math.abs(light.Color.R - want.R) > 0.02 or math.abs(light.Color.B - want.B) > 0.02 then
			return false
		end
	end
	return true
end)())

check("hazard zones are walk-into, not walk-around", (function()
	local zones = partsWithAttribute("HazardZone")
	for _, zone in ipairs(zones) do
		if zone.CanCollide ~= false then
			return false
		end
	end
	return true
end)())

print("\n== a player ==")

local alice = ENV.players:_join("Alice", 101, SERVER.World.spawnPosition)
advance(2)

local profile = SERVER.Data.get(alice)
check("the profile loads on join", profile ~= nil)
check("a new profile starts at zero", profile ~= nil and profile.cash == 0)
check("a session exists", SERVER.Data.session(alice) ~= nil)

print("\n== mining ==")

local target = nodes[1]
moveTo(alice, target.Position)

local cargoBefore = #SERVER.Data.session(alice).cargo.items
fire("Mine", alice, target:GetAttribute("NodeId"))
advance(3)
local cargoAfter = #SERVER.Data.session(alice).cargo.items

check("mining a node adds cargo", cargoAfter > cargoBefore,
	`{cargoBefore} -> {cargoAfter}`)

check("a mined-out node stops blocking", target.CanCollide == false,
	"an invisible solid rock is worse than a visible one")

check("the node comes back solid", (function()
	-- NodeRespawn is 9 seconds; virtual time makes that instant.
	advance(11)
	return target.CanCollide == true and target.Transparency == 0
end)())

check("you never get less than the wall promised", (function()
	-- Luck is a second roll that can only beat the node. If this ever fails,
	-- the visible ore has become a lie and every route decision with it.
	local session = SERVER.Data.session(alice)
	local worst = nil
	for _ = 1, 40 do
		local node = nil
		for _, candidate in ipairs(nodes) do
			if SERVER.World.getNode(candidate:GetAttribute("NodeId")) then
				node = candidate
				break
			end
		end
		if not node then
			break
		end

		local promised = MODULES.Ores.TierIndex[MODULES.Ores.ById[node:GetAttribute("Ore")].tier]
		moveTo(alice, node.Position)
		local before = #session.cargo.items
		fire("Mine", alice, node:GetAttribute("NodeId"))
		advance(3)
		local item = session.cargo.items[#session.cargo.items]
		if #session.cargo.items > before and item then
			local got = MODULES.Ores.TierIndex[item.tier]
			if got < promised then
				return false
			end
			worst = math.min(worst or 99, got - promised)
		end
		SERVER.Cargo.clear(alice)
	end
	print(string.format("       40 swings, smallest gap between promise and payout: %s", tostring(worst)))
	return worst ~= nil
end)())

check("mining out of range does nothing", (function()
	moveTo(alice, ENV.Vector3.new(9000, 9000, 9000))
	local before = #SERVER.Data.session(alice).cargo.items
	fire("Mine", alice, target:GetAttribute("NodeId"))
	advance(3)
	return #SERVER.Data.session(alice).cargo.items == before
end)())

print("\n== banking ==")

check("banking away from the vault pays nothing", (function()
	moveTo(alice, ENV.Vector3.new(9000, 9000, 9000))
	local before = SERVER.Data.get(alice).cash
	fire("Bank", alice)
	advance(1)
	return SERVER.Data.get(alice).cash == before
end)())

check("banking at the vault pays and empties the hold", (function()
	-- Fill the hold first: the previous checks may have emptied it.
	moveTo(alice, target.Position)
	for _ = 1, 3 do
		fire("Mine", alice, target:GetAttribute("NodeId"))
		advance(3)
		advance(11) -- let the node respawn so the next swing has something
	end

	local session = SERVER.Data.session(alice)
	local carried = #session.cargo.items
	if carried == 0 then
		print("       nothing was mined, so this proves nothing")
		return false
	end

	moveTo(alice, SERVER.World.vaultPosition)
	local before = SERVER.Data.get(alice).cash
	fire("Bank", alice)
	advance(1)

	local after = SERVER.Data.get(alice).cash
	print(string.format("       banked %d items for %d cash", carried, after - before))
	return after > before and #SERVER.Data.session(alice).cargo.items == 0
end)())

print("\n== rank ==")

check("a new player starts on the bottom rung", (function()
	local rank = MODULES.Ranks.at(0)
	print(string.format("       0 banked = %s", rank.name))
	return rank.id == "dust" and MODULES.Ranks.progress(0) < 1
end)())

check("the ladder only ever goes up", (function()
	-- Each rung must cost more than the one below it, or a player can rank
	-- down by earning, which is the worst bug a progression system can have.
	local previous = -1
	for _, rank in ipairs(MODULES.Ranks.List) do
		if rank.at <= previous then
			return false
		end
		previous = rank.at
	end
	return true
end)())

check("banking past a threshold promotes you", (function()
	local profile = SERVER.Data.get(alice)
	local wasRank = MODULES.Ranks.at(profile.stats.bankedTotal).id

	-- Park the lifetime total just under Copper, then bank a real deposit
	-- through the real remote and watch the rank move.
	profile.stats.bankedTotal = MODULES.Ranks.List[2].at - 1
	moveTo(alice, target.Position)
	for _ = 1, 3 do
		fire("Mine", alice, target:GetAttribute("NodeId"))
		advance(3)
		advance(11)
	end
	moveTo(alice, SERVER.World.vaultPosition)
	fire("Bank", alice)
	advance(1)

	local nowRank = MODULES.Ranks.at(SERVER.Data.get(alice).stats.bankedTotal)
	print(string.format("       %s -> %s", wasRank, nowRank.id))
	return nowRank.id == "copper"
end)())

check("the rank is on the player list and over their head", (function()
	local stats = alice:FindFirstChild("leaderstats")
	local entry = stats and stats:FindFirstChild("Rank")
	if not entry then
		return false
	end

	local head = alice.Character and alice.Character:FindFirstChild("Head")
	local plate = head and head:FindFirstChild("DeepRushPlate")
	print(string.format("       player list says %s", tostring(entry.Value)))
	return plate ~= nil and string.find(string.upper(tostring(entry.Value)), "COPPER") ~= nil
end)())

check("the live server board lists whoever is in the shaft", (function()
	local boards = invoke("GetBoards", alice)
	local rows = boards and boards.server or {}
	if #rows == 0 then
		return false
	end
	print(string.format("       %d on the board, top is %s with %d", #rows, rows[1].name, rows[1].value))
	return rows[1].name == "Alice" and rows[1].value > 0
end)())

print("\n== the lift ==")

check("a lift pad exists once you are deep enough", (function()
	-- Lifts sit on every second chunk, and chunks only build near a player.
	moveTo(alice, ENV.Vector3.new(0, -330, 0))
	advance(3)
	return #partsWithAttribute("LiftPad") > 0
end)())

check("the lift refuses to run when you are not on a pad", (function()
	moveTo(alice, ENV.Vector3.new(0, -330, 0))
	local session = SERVER.Data.session(alice)
	session.lifting = false
	fire("UseLift", alice)
	advance(6)
	return session.lifting ~= true
		and alice.Character.HumanoidRootPart.Position.Y < -100
end)())

check("the lift returns you to the surface", (function()
	local pads = partsWithAttribute("LiftPad")
	if #pads == 0 then
		return false
	end

	moveTo(alice, pads[1].Position)
	fire("UseLift", alice)
	advance(6) -- the channel is 4s without the Express pass

	local landed = alice.Character.HumanoidRootPart.Position
	local spawn = SERVER.World.spawnPosition
	local distance = (landed - spawn).Magnitude
	print(string.format("       landed %.1f studs from the spawn", distance))
	return distance < 12
end)())

check("the bottom of the shaft is not a trap", (function()
	-- This was a real softlock. Bedrock sits at 3,000m and the nearest lift
	-- pad used to be BELOW the floor, with the next two 172 and 536 studs
	-- overhead. A Roblox character jumps about seven.
	local bottom = ENV.Vector3.new(0, SERVER.World.yForDepth(3000) + 8, 0)
	moveTo(alice, bottom)
	advance(4)

	local best = math.huge
	local climb = nil
	for _, pad in ipairs(partsWithAttribute("LiftPad")) do
		local distance = (pad.Position - bottom).Magnitude
		if distance < best then
			best = distance
			climb = pad.Position.Y - bottom.Y
		end
	end

	print(string.format("       nearest pad %.0f studs away, %+.0f vertical", best, climb or 0))
	-- Reachable means: close, and not above jump height.
	return best < 40 and climb ~= nil and climb <= 7
end)())

check("emergency ascent works from the very bottom", (function()
	local bottom = ENV.Vector3.new(0, SERVER.World.yForDepth(3000) + 8, 0)
	moveTo(alice, bottom)
	SERVER.Data.session(alice).lifting = false
	advance(1) -- let the server measure the depth itself

	fire("EmergencyAscent", alice)
	advance(15)

	local landed = alice.Character.HumanoidRootPart.Position
	local distance = (landed - SERVER.World.spawnPosition).Magnitude
	print(string.format("       landed %.1f studs from the spawn", distance))
	return distance < 12
end)())

check("emergency ascent cancels when you walk away", (function()
	local here = ENV.Vector3.new(0, -900, 0)
	moveTo(alice, here)
	SERVER.Data.session(alice).lifting = false
	advance(1)

	fire("EmergencyAscent", alice)
	advance(2)
	moveTo(alice, here + ENV.Vector3.new(0, 0, 400)) -- well past the drift limit
	advance(15)

	-- Still underground: the ascent must have aborted.
	return alice.Character.HumanoidRootPart.Position.Y < -400
end)())

check("falling out of the world puts you back on the surface", (function()
	-- Raising FallenPartsDestroyHeight to clear a 3,000m shaft means a player
	-- who ends up under the geometry falls for ten seconds instead of dying
	-- and respawning in one. Bedrock should make that impossible; this is the
	-- net under it, and a net nobody tests is a decoration.
	local below = SERVER.World.yForDepth(3000) - 600
	moveTo(alice, ENV.Vector3.new(0, below, 0))
	advance(3)

	local back = alice.Character.HumanoidRootPart.Position
	local distance = (back - SERVER.World.spawnPosition).Magnitude
	print(string.format("       dropped to y=%.0f, back %.1f studs from spawn", below, distance))
	return distance < 10
end)())

check("every depth has a lift within falling distance", (function()
	for _, depth in ipairs({ 60, 300, 800, 1400, 2000, 2600 }) do
		local at = ENV.Vector3.new(0, -depth * 3, 0)
		moveTo(alice, at)
		advance(3)

		local best = math.huge
		for _, pad in ipairs(partsWithAttribute("LiftPad")) do
			best = math.min(best, (pad.Position - at).Magnitude)
		end
		if best > 260 then
			print(string.format("       %dm: nearest lift %.0f studs away", depth, best))
			return false
		end
	end
	return true
end)())

print("\n== upgrades ==")

check("an upgrade costs cash and changes the stat it advertises", (function()
	local player = alice
	local before = SERVER.Economy.mineTime(player)
	SERVER.Economy.addCash(player, 100000)
	local cash = SERVER.Data.get(player).cash

	fire("BuyUpgrade", player, "drill")
	advance(1)

	local level = SERVER.Data.get(player).upgrades.drill or 0
	local after = SERVER.Economy.mineTime(player)
	print(string.format("       drill %d, swing %.3fs -> %.3fs", level, before, after))
	return level == 1 and after < before and SERVER.Data.get(player).cash < cash
end)())

check("an upgrade you cannot afford is refused", (function()
	local player = alice
	SERVER.Data.get(player).cash = 0
	local level = SERVER.Data.get(player).upgrades.backpack or 0
	fire("BuyUpgrade", player, "backpack")
	advance(1)
	return (SERVER.Data.get(player).upgrades.backpack or 0) == level
end)())

print("\n== the pickaxe ==")

check("a player is holding one", (function()
	-- The game shipped without any tool at all: players swung nothing.
	advance(2)
	SERVER.Tools.equip(alice)
	local pick = alice.Character:FindFirstChild("Pickaxe")
	if not pick then
		return false
	end
	local hand = alice.Character:FindFirstChild("RightHand")
	return hand ~= nil and hand:FindFirstChild("PickaxeMotor") ~= nil
end)())

check("it is attached to the hand, not floating", (function()
	local hand = alice.Character:FindFirstChild("RightHand")
	local motor = hand and hand:FindFirstChild("PickaxeMotor")
	local pick = alice.Character:FindFirstChild("Pickaxe")
	return motor ~= nil and motor.Part0 == hand and motor.Part1 == pick
end)())

check("it visibly upgrades with Drill Power", (function()
	-- The only upgrade in the game with a form you can see.
	local ToolConfig = MODULES.Tools
	local low = ToolConfig.tierFor(0).name
	local high = ToolConfig.tierFor(50).name

	SERVER.Data.get(alice).upgrades.drill = 40
	SERVER.Tools.equip(alice)
	local pick = alice.Character:FindFirstChild("Pickaxe")
	local head = pick and pick:FindFirstChild("Head")

	SERVER.Data.get(alice).upgrades.drill = 0
	print(string.format("       level 0 = %s, level 50 = %s", low, high))
	return low ~= high and head ~= nil
end)())

check("swinging it does not throw", (function()
	local ok = pcall(function()
		SERVER.Tools.swing(alice, 0.6)
	end)
	advance(1)
	return ok
end)())

print("\n== crew ==")

check("standing together pays a bonus, standing apart does not", (function()
	local here = ENV.Vector3.new(0, -330, 0)
	moveTo(alice, here)
	local bob = ENV.players:_join("Bob", 202, here)
	advance(2)

	fire("CrewBeacon", alice)
	advance(1)
	fire("CrewJoin", bob)
	advance(1)

	local together = SERVER.Crew.bonus(bob).cash
	moveTo(bob, ENV.Vector3.new(0, -330, 4000))
	local apart = SERVER.Crew.bonus(bob).cash

	print(string.format("       crew bonus near %.2f, far %.2f", together, apart))
	return together > 0 and apart == 0
end)())

print("\n== hazards ==")

check("a hazard zone hurts you, and only while you are in it", (function()
	-- Go deep enough for a persistent zone and let the chunk stream in.
	moveTo(alice, ENV.Vector3.new(0, -3300, 0))
	advance(4)

	-- Nearest armed zone, not the first one in the list. The first pass here
	-- grabbed a pulsing cave-in three thousand studs up in a chunk that had
	-- not been torn down yet, stood the player at its centre, and concluded
	-- the hazard system was broken. It was not; the test was.
	local root = alice.Character.HumanoidRootPart
	local best, bestDistance = nil, math.huge
	for _, zone in ipairs(partsWithAttribute("HazardZone")) do
		if zone:GetAttribute("Armed") == true then
			local distance = (zone.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = zone, distance
			end
		end
	end

	if not best then
		print("       no armed zone streamed in; inconclusive")
		return false
	end

	-- Compare rates, not absolutes. At this depth the player is also losing
	-- air, so "health stopped changing after leaving" was never going to be
	-- true — the zone has to be dramatically worse than the background.
	local humanoid = alice.Character:FindFirstChildOfClass("Humanoid")

	humanoid.Health = 100
	moveTo(alice, best.Position)
	advance(4)
	local insideLoss = 100 - humanoid.Health

	humanoid.Health = 100
	moveTo(alice, best.Position + ENV.Vector3.new(0, 0, 900))
	advance(4)
	local outsideLoss = 100 - humanoid.Health

	print(string.format("       %s: %.0f damage inside vs %.0f outside over the same 4s",
		tostring(best:GetAttribute("HazardZone")), insideLoss, outsideLoss))
	return insideLoss > 10 and insideLoss > outsideLoss * 2
end)())

check("the surface is safe", (function()
	-- Whatever else is true, a player standing on the spawn pad must not be
	-- losing health. This is the check that catches a hazard leaking into
	-- chunk zero.
	local humanoid = alice.Character:FindFirstChildOfClass("Humanoid")
	moveTo(alice, SERVER.World.spawnPosition)
	humanoid.Health = 100
	advance(6)
	return humanoid.Health == 100
end)())

print("\n== nothing broke quietly ==")

check("no handler warned during the run", #WARNINGS == 0, (function()
	local out = {}
	for index = 1, math.min(#WARNINGS, 6) do
		table.insert(out, WARNINGS[index])
	end
	return table.concat(out, " | ")
end)())

print(string.format("\n%d checks, %d failed\n", checks, failures))
if failures > 0 then
	error(string.format("%d simulation checks failed", failures), 0)
end
