--!nonstrict
--[[
	State.luau — one client-side copy of the player's state.

	The server sends partial patches (see Data.push). Everything the UI
	renders reads from here and re-renders on the changed signal, so no
	controller ever has to know which remote a number arrived on.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local State = {}

State.data = {
	cash = 0,
	xp = 0,
	level = 1,
	rebirths = 0,
	depth = 0,
	oxygen = 60,
	oxygenMax = 60,
	upgrades = {},
	drones = { owned = {}, equipped = nil },
	codex = {},
	cargo = { count = 0, value = 0, capacity = 8, greed = 0 },
	quests = {},
	questBoard = { daily = {}, milestones = {} },
	stats = {},
	rewards = {},
	buffs = {},
	gamepasses = {},
	streak = 0,
	seenIntro = nil, -- nil until the first snapshot; see Client/Intro.luau
	contract = { week = "", points = 0, dayPoints = 0, claimed = {} },
	descent = { days = 0, lastDay = "", claimed = {} },
	cosmetics = { owned = {}, equipped = {} },
	deals = { day = "", bought = {} },
	crew = { members = {}, bonusNear = 0 },
}

State.changed = Signal.new()
State.rift = { active = false }
State.riftChanged = Signal.new()
State.marked = {} -- userId -> true

local function merge(target, patch)
	for key, value in pairs(patch) do
		if key == "__replace" then
			continue
		end
		if type(value) == "table" and value.__replace then
			local copy = table.clone(value)
			copy.__replace = nil
			target[key] = copy
		elseif type(value) == "table" and type(target[key]) == "table" then
			merge(target[key], value)
		else
			target[key] = value
		end
	end
end

function State.start()
	local snapshot = Net.invoke("GetState")
	if snapshot then
		merge(State.data, snapshot)
		State.changed:fire(State.data)
	end

	Net.listen("State", function(patch)
		if type(patch) ~= "table" then
			return
		end
		merge(State.data, patch)
		State.changed:fire(State.data)
	end)

	Net.listen("Rift", function(state)
		State.rift = state
		State.riftChanged:fire(state)
	end)

	Net.listen("Marked", function(userIds)
		local marked = {}
		for _, userId in ipairs(userIds) do
			marked[userId] = true
		end
		State.marked = marked
	end)
end

return State
