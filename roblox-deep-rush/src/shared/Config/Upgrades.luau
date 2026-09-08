--!nonstrict
--[[
	Upgrades.luau — the cash sink.

	Costs grow geometrically, payouts grow linearly. That gap is the engine
	of the meta loop: every upgrade line eventually stalls, and the only way
	past the stall is to rebirth. Growth rates differ per line so players
	have a real choice about what to buy next instead of one dominant order.
]]

local Upgrades = {}

Upgrades.List = {
	{
		id = "drill",
		name = "Drill Power",
		desc = "Break rock faster. Every level shaves time off each swing.",
		icon = "⛏️",
		maxLevel = 50,
		baseCost = 120,
		growth = 1.26,
		-- fraction of the base mine time removed, asymptotic so it never hits 0
		effect = function(level: number): number
			return 1 - (0.955 ^ level)
		end,
		format = function(level: number): string
			return string.format("-%d%% swing time", math.floor((1 - 0.955 ^ level) * 100))
		end,
	},
	{
		id = "backpack",
		name = "Cargo Hold",
		desc = "Carry more before you are forced to surface.",
		icon = "🎒",
		maxLevel = 50,
		baseCost = 200,
		growth = 1.30,
		effect = function(level: number): number
			return level * 2
		end,
		format = function(level: number): string
			return string.format("+%d slots", level * 2)
		end,
	},
	{
		id = "boots",
		name = "Grip Boots",
		desc = "Move faster. Getting back up is half the run.",
		icon = "👟",
		maxLevel = 25,
		baseCost = 340,
		growth = 1.34,
		effect = function(level: number): number
			return level * 0.9
		end,
		format = function(level: number): string
			return string.format("+%.1f walkspeed", level * 0.9)
		end,
	},
	{
		id = "oxygen",
		name = "Air Tank",
		desc = "Stay down longer before the deep starts taking bites.",
		icon = "🫁",
		maxLevel = 30,
		baseCost = 420,
		growth = 1.31,
		effect = function(level: number): number
			return level * 7
		end,
		format = function(level: number): string
			return string.format("+%ds of air", level * 7)
		end,
	},
	{
		id = "lamp",
		name = "Headlamp",
		desc = "See further, and spot rich nodes before anyone else does.",
		icon = "🔦",
		maxLevel = 20,
		baseCost = 500,
		growth = 1.33,
		effect = function(level: number): number
			return level * 4
		end,
		format = function(level: number): string
			return string.format("+%d stud sight", level * 4)
		end,
	},
	{
		id = "pocket",
		name = "Safe Pocket",
		desc = "Part of your cargo survives a death or a snatch.",
		icon = "🔒",
		maxLevel = 10,
		baseCost = 2500,
		growth = 1.55,
		effect = function(level: number): number
			return math.min(level * 0.05, 0.5)
		end,
		format = function(level: number): string
			return string.format("%d%% protected", math.min(level * 5, 50))
		end,
	},
	{
		id = "charm",
		name = "Luck Charm",
		desc = "Shifts every roll toward the rare end of the table.",
		icon = "🍀",
		maxLevel = 25,
		baseCost = 1500,
		growth = 1.42,
		effect = function(level: number): number
			return level * 0.12
		end,
		format = function(level: number): string
			return string.format("+%.2f luck", level * 0.12)
		end,
	},
}

Upgrades.ById = {}
for i, upgrade in ipairs(Upgrades.List) do
	upgrade.order = i
	Upgrades.ById[upgrade.id] = upgrade
end

--- Cost of moving from `level` to `level + 1`.
function Upgrades.cost(id: string, level: number): number
	local upgrade = Upgrades.ById[id]
	if not upgrade then
		return math.huge
	end
	return math.floor(upgrade.baseCost * (upgrade.growth ^ level))
end

function Upgrades.value(id: string, level: number): number
	local upgrade = Upgrades.ById[id]
	if not upgrade then
		return 0
	end
	return upgrade.effect(level or 0)
end

function Upgrades.isMaxed(id: string, level: number): boolean
	local upgrade = Upgrades.ById[id]
	return upgrade ~= nil and (level or 0) >= upgrade.maxLevel
end

return Upgrades
