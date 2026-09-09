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
	"Quests", "Rift", "Season", "Mining", "Surface", "Steal", "Hazards",
	"Upgrades", "Rebirth", "Drones", "Rewards", "Leaderboards", "Monetization",
	"Ads", "AntiCheat",
}

local bootOk, bootErr = pcall(function()
	for _, name in ipairs(SERVICES) do
		SERVER[name].start()
	end
end)
check("every service starts", bootOk, bootErr and tostring(bootErr))
check("the remote tree is published", net ~= nil)

advance(2)

print("\n== the world ==")

check("the surface built a vault", SERVER.World.vaultPosition ~= nil)
check("the surface built a spawn", SERVER.World.spawnPosition ~= nil)

local nodes = partsWithAttribute("NodeId")
check("ore nodes exist", #nodes > 0, `found {#nodes}`)

check("ore nodes are solid", (function()
	-- The bug a player spots in the first ten seconds: walking through rock.
	for _, node in ipairs(nodes) do
		if node.CanCollide ~= true then
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

	local humanoid = alice.Character:FindFirstChildOfClass("Humanoid")
	humanoid.Health = 100
	moveTo(alice, best.Position)
	advance(4)
	local hurt = humanoid.Health

	moveTo(alice, best.Position + ENV.Vector3.new(0, 0, 900))
	advance(4)
	local afterLeaving = humanoid.Health

	print(string.format("       %s: 100 -> %.0f inside -> %.0f after leaving",
		tostring(best:GetAttribute("HazardZone")), hurt, afterLeaving))
	return hurt < 100 and afterLeaving == hurt
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
