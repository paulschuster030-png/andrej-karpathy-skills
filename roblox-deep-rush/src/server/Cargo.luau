--!nonstrict
--[[
	Cargo.luau — unbanked loot, and the greed that makes it interesting.

	Cargo is deliberately NOT saved. Everything you are carrying is at risk
	until you bank it, and that risk is the entire tension of the core loop.

	Greed is simply how full your hold is. We tried value-weighted formulas;
	fill ratio won because a player can read it off the bar without doing
	arithmetic, and "your bag is nearly full so you are a target" is a rule
	you can explain to a nine-year-old in one sentence.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)

local Cargo = {}

local function sync(player: Player)
	local session = Data.session(player)
	if not session then
		return
	end
	Data.push(player, {
		cargo = {
			count = #session.cargo.items,
			value = session.cargo.value,
			capacity = Economy.capacity(player),
			greed = Cargo.greed(player),
		},
	})
end

function Cargo.get(player: Player)
	local session = Data.session(player)
	return session and session.cargo or nil
end

function Cargo.isFull(player: Player): boolean
	local session = Data.session(player)
	if not session then
		return true
	end
	return #session.cargo.items >= Economy.capacity(player)
end

--- 0..1. Above Config.GreedMarkThreshold the player is stealable.
function Cargo.greed(player: Player): number
	local session = Data.session(player)
	if not session then
		return 0
	end
	local capacity = Economy.capacity(player)
	if capacity <= 0 then
		return 0
	end
	return math.clamp(#session.cargo.items / capacity, 0, 1)
end

function Cargo.isMarked(player: Player): boolean
	return Cargo.greed(player) >= Config.GreedMarkThreshold
end

--- entry = { oreId, tier, mutation, value }
function Cargo.add(player: Player, entry): boolean
	local session = Data.session(player)
	if not session or Cargo.isFull(player) then
		return false
	end

	table.insert(session.cargo.items, entry)
	session.cargo.value += entry.value
	sync(player)
	return true
end

--- Remove a fraction of the hold, newest first (you drop what is on top).
--- Returns the removed items and their value.
function Cargo.take(player: Player, fraction: number)
	local session = Data.session(player)
	if not session or #session.cargo.items == 0 then
		return {}, 0
	end

	local count = math.max(1, math.floor(#session.cargo.items * fraction))
	local taken, value = {}, 0
	for _ = 1, count do
		local entry = table.remove(session.cargo.items)
		if not entry then
			break
		end
		table.insert(taken, entry)
		value += entry.value
		session.cargo.value -= entry.value
	end

	session.cargo.value = math.max(0, session.cargo.value)
	sync(player)
	return taken, value
end

function Cargo.clear(player: Player)
	local session = Data.session(player)
	if not session then
		return {}, 0
	end
	local items = session.cargo.items
	local value = session.cargo.value
	session.cargo = { items = {}, value = 0 }
	sync(player)
	return items, value
end

--- Merge foreign items into this player's hold, dropping the overflow.
--- Returns how much value actually fit.
function Cargo.give(player: Player, items): number
	local gained = 0
	for _, entry in ipairs(items) do
		if not Cargo.add(player, entry) then
			break
		end
		gained += entry.value
	end
	return gained
end

function Cargo.resync(player: Player)
	sync(player)
end

function Cargo.start()
	-- Without this a player who has upgrades but has not mined yet sees the
	-- base capacity of 8 on their HUD until their first swing.
	Data.loaded:connect(function(player)
		sync(player)
	end)
end

return Cargo
