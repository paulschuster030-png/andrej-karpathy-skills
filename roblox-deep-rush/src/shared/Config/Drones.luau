--!nonstrict
--[[
	Drones.luau — the collection hook.

	Roblox players collect. Drones are the cheapest possible version of that:
	one equipped at a time, each with a readable bonus, most of them found
	rather than bought. Ownership is permanent through rebirth, which makes
	them the thing a returning player still recognises as theirs.
]]

local Drones = {}

Drones.List = {
	{
		id = "scrap",
		name = "Scrap Drone",
		rarity = "Common",
		desc = "Welded from shaft junk. Sells your haul for a little more.",
		bonus = { cash = 0.05 },
		cost = 5000,
		findDepth = nil,
	},
	{
		id = "scout",
		name = "Scout Drone",
		rarity = "Uncommon",
		desc = "Sniffs out the good seams.",
		bonus = { luck = 0.25 },
		cost = 22000,
		findDepth = nil,
	},
	{
		id = "magnet",
		name = "Magnet Drone",
		rarity = "Rare",
		desc = "Hoovers up dropped crates near you. Yours or not.",
		bonus = { magnet = 22 },
		cost = 90000,
		findDepth = nil,
	},
	{
		id = "coolant",
		name = "Coolant Drone",
		rarity = "Rare",
		desc = "Bleeds off heat, pressure and cold. Hazards hurt less.",
		bonus = { hazardResist = 0.30 },
		cost = 140000,
		findDepth = 450,
	},
	{
		id = "lung",
		name = "Lung Drone",
		rarity = "Epic",
		desc = "A spare set of lungs on a rotor.",
		bonus = { oxygen = 45 },
		cost = 400000,
		findDepth = 700,
	},
	{
		id = "hollowpup",
		name = "Hollow Pup",
		rarity = "Legendary",
		desc = "It followed you up. Nobody agrees on what it is.",
		bonus = { luck = 0.6, cash = 0.15 },
		cost = nil, -- find only
		findDepth = 1000,
	},
	{
		id = "void",
		name = "Void Drone",
		rarity = "Mythic",
		desc = "Runs on something that should not be a fuel.",
		bonus = { cash = 0.5, luck = 0.5, hazardResist = 0.2 },
		cost = nil,
		findDepth = 1400,
	},
	{
		id = "origin",
		name = "Origin Core",
		rarity = "Singularity",
		desc = "The first drone. It was already down there.",
		bonus = { cash = 1.0, luck = 1.0, oxygen = 60, magnet = 30, hazardResist = 0.4 },
		cost = nil,
		findDepth = 2000,
	},
}

Drones.ById = {}
for _, drone in ipairs(Drones.List) do
	Drones.ById[drone.id] = drone
end

--- Chance per mined node that a drone drops at this depth. Deliberately
--- tiny: a found drone should be a story, not a Tuesday.
function Drones.dropChance(depth: number, luck: number): number
	return math.min(0.00035 * (1 + (luck - 1) * 0.4) * (1 + depth / 1200), 0.004)
end

--- Which find-only drones can drop at `depth`, deepest (rarest) first.
function Drones.droppableAt(depth: number)
	local out = {}
	for _, drone in ipairs(Drones.List) do
		if drone.findDepth and depth >= drone.findDepth then
			table.insert(out, drone)
		end
	end
	table.sort(out, function(a, b)
		return a.findDepth > b.findDepth
	end)
	return out
end

--- Sum the equipped drone's bonuses into a flat table.
function Drones.bonusesOf(droneId: string?)
	local empty = { cash = 0, luck = 0, oxygen = 0, magnet = 0, hazardResist = 0 }
	local drone = droneId and Drones.ById[droneId]
	if not drone then
		return empty
	end
	for key, value in pairs(drone.bonus) do
		empty[key] = value
	end
	return empty
end

return Drones
