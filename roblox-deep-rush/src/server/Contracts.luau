--!nonstrict
--[[
	Contracts.luau — the long arc.

	Roblox grades a new experience across day 1, days 2-7 AND days 8-28, and
	counts "play days per user" rather than hours. Before this module the
	longest arc in DEEP RUSH was a daily quest, which means the game had
	nothing to say to a player on day 12.

	Two ladders, both about days rather than hours:

	  WEEKLY CONTRACT  one currency, seven tiers, resets Monday. Points are
	                   capped per day, so the correct play is to come back
	                   tomorrow. That is not a monetisation lever — it is
	                   pacing that happens to match the platform's own
	                   60-minute daily playtime cap.

	  DESCENT LOG      one-time rewards for the number of DISTINCT days you
	                   have played, running out to 28. Back-loaded on purpose:
	                   the day-28 prize is meant to be seen on day 2.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Contracts)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Cosmetics = require(script.Parent.Cosmetics)
local Crew = require(script.Parent.Crew)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Contracts = {}

local CREW_TICK_SECONDS = 60
local CREW_MIN_DEPTH = 40 -- standing together at spawn is not co-play

local function today(): string
	local now = os.date("!*t")
	return string.format("%d-%03d", now.year, now.yday)
end

--- Roll the weekly ladder over, and the daily point budget with it.
local function ensureContract(player: Player)
	local profile = Data.get(player)
	if not profile then
		return false
	end

	local changed = false
	local week = Config.weekKey()
	if profile.contract.week ~= week then
		profile.contract = { week = week, points = 0, dayPoints = 0, day = today(), claimed = {} }
		changed = true
	end
	if profile.contract.day ~= today() then
		profile.contract.day = today()
		profile.contract.dayPoints = 0
		changed = true
	end

	if changed then
		Data.push(player, { contract = Data.replace(table.clone(profile.contract)) })
	end
	return changed
end

--- Count today against the Descent Log if it is a day we have not seen.
local function ensureDescent(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end

	local day = today()
	if profile.descent.lastDay == day then
		return
	end

	profile.descent.lastDay = day
	profile.descent.days += 1
	Data.push(player, { descent = Data.replace(table.clone(profile.descent)) })

	local upcoming = nil
	for _, milestone in ipairs(Config.DescentLog) do
		if profile.descent.days < milestone.days then
			upcoming = milestone
			break
		end
	end

	Feedback.toast(player, {
		title = `DAY {profile.descent.days} BELOW`,
		body = upcoming and `{upcoming.days - profile.descent.days} more days to "{upcoming.label}".`
			or "You have finished the Descent Log. Respect.",
		kind = "quest",
		duration = 5,
	})
end

--- The single entry point every other system uses to feed the ladder.
function Contracts.award(player: Player, points: number, reason: string?)
	local profile = Data.get(player)
	if not profile or points <= 0 then
		return
	end
	ensureContract(player)

	local room = Config.DailyPointCap - profile.contract.dayPoints
	if room <= 0 then
		return
	end

	local granted = math.min(math.floor(points), room)
	if granted <= 0 then
		return
	end

	local before = Config.tierAt(profile.contract.points)
	profile.contract.points += granted
	profile.contract.dayPoints += granted
	local after = Config.tierAt(profile.contract.points)

	Data.push(player, {
		contract = { points = profile.contract.points, dayPoints = profile.contract.dayPoints },
	})

	if after > before then
		Feedback.effect(player, "contract", { tier = after })
		Feedback.toast(player, {
			title = `CONTRACT TIER {after}`,
			body = "Open 📜 Contract to claim it.",
			kind = "quest",
			duration = 5,
		})
	end

	-- Fires exactly on the tick that fills the budget: `granted == room` only
	-- when this award consumed the last of it. Framed as finished, not as
	-- blocked — there is no lockout, only a ceiling on this one ladder.
	if granted == room then
		Feedback.toast(player, {
			title = "TODAY'S CONTRACT WORK IS DONE",
			body = "Everything else still pays. The ladder refills at midnight UTC.",
			kind = "cash",
			duration = 6,
		})
	end
end

local function grant(player: Player, reward)
	if not reward then
		return
	end
	if reward.cash then
		Economy.addCash(player, reward.cash)
	end
	if reward.luckMinutes then
		Economy.addBuff(player, "luck", 2, reward.luckMinutes * 60)
	end
	if reward.cosmetic then
		Cosmetics.unlock(player, reward.cosmetic)
	end
	if reward.drone then
		local profile = Data.get(player)
		if profile and not profile.drones.owned[reward.drone] then
			profile.drones.owned[reward.drone] = true
			Data.push(player, { drones = Data.replace(table.clone(profile.drones)) })
		end
	end
end

function Contracts.claimTier(player: Player, index: number)
	local profile = Data.get(player)
	if not profile then
		return
	end
	ensureContract(player)

	local tier = Config.Tiers[index]
	if not tier or profile.contract.points < tier.points then
		return
	end
	if profile.contract.claimed[tostring(index)] then
		return
	end

	profile.contract.claimed[tostring(index)] = true
	grant(player, tier.reward)
	Data.push(player, { contract = Data.replace(table.clone(profile.contract)) })

	Feedback.reveal(player, {
		title = "CONTRACT TIER " .. index,
		name = Config.nameForWeek(),
		tier = index >= #Config.Tiers and "Mythic" or "Epic",
		body = `+{Format.short(tier.reward.cash or 0)}`,
		kind = "contract",
	})
end

function Contracts.claimDescent(player: Player, index: number)
	local profile = Data.get(player)
	if not profile then
		return
	end

	local milestone = Config.DescentLog[index]
	if not milestone or profile.descent.days < milestone.days then
		return
	end
	if profile.descent.claimed[tostring(index)] then
		return
	end

	profile.descent.claimed[tostring(index)] = true
	grant(player, milestone.reward)
	Data.push(player, { descent = Data.replace(table.clone(profile.descent)) })

	Feedback.reveal(player, {
		title = milestone.label,
		name = `{milestone.days} DAYS BELOW`,
		tier = "Legendary",
		body = `+{Format.short(milestone.reward.cash or 0)}`,
		kind = "descent",
	})
end

--- Crew points are paid on a timer rather than at an event, because the
--- thing being rewarded is time spent digging together.
local function crewLoop()
	while true do
		task.wait(CREW_TICK_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			local session = Data.session(player)
			if session and (session.depth or 0) >= CREW_MIN_DEPTH and Crew.matesNear(player) > 0 then
				Contracts.award(player, Config.Points.perCrewMinute, "crew")
				require(script.Parent.Quests).record(player, "crew_minutes", 1)
			end
		end
	end
end

function Contracts.start()
	Net.on("ClaimContract", function(player, index)
		if type(index) == "number" then
			Contracts.claimTier(player, index)
		end
	end)

	Net.on("ClaimDescent", function(player, index)
		if type(index) == "number" then
			Contracts.claimDescent(player, index)
		end
	end)

	Data.loaded:connect(function(player)
		ensureContract(player)
		task.delay(5, ensureDescent, player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if Data.isReady(player) then
			ensureContract(player)
			ensureDescent(player)
		end
	end

	task.spawn(crewLoop)
end

return Contracts
