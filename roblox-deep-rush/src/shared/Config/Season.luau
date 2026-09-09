--!nonstrict
--[[
	Season.luau — the thing that makes a player think "I need that".

	Copied in structure, not in substance, from what demonstrably works on the
	platform right now: the biggest game on Roblox runs live weekend events
	whose rewards you simply do not get if you were not there. That is the
	whole mechanism. Scarcity plus a deadline plus something everyone can see
	you have.

	Three rules kept this from becoming the uglier version of itself:

	  NOTHING IS SOLD HERE. The season badge cannot be bought, at any price.
	  The moment scarcity is purchasable it stops being scarcity and starts
	  being a store.

	  THE PRICE IS ATTENDANCE, NOT MONEY. You show up in the window and mine.
	  A player with no Robux and two spare hours gets exactly what a paying
	  player gets.

	  IT IS ACHIEVABLE IN ONE SITTING. The badge threshold is set so a normal
	  session inside the window earns it. A deadline you cannot meet is not
	  urgency, it is just exclusion.

	We deliberately did NOT copy the rest of that game's toolkit — paid luck
	multipliers on a spinner, and loss mechanics tuned to make children cry
	for the clip. Those work too. They are not going in.
]]

local Season = {}

-- Seasons roll over on this cadence. The epoch is fixed so every server and
-- every player agrees which season it is without storing anything.
Season.Epoch = 1767225600 -- 2026-01-01T00:00:00Z
Season.LengthDays = 14

-- The live window: Saturday and Sunday, UTC. os.date("!*t").wday is
-- 1 = Sunday ... 7 = Saturday.
Season.WindowDays = { [7] = true, [1] = true }

--- The exclusive ore. It exists ONLY inside the window and is filtered out of
--- the normal tables everywhere else, so it cannot be farmed off-schedule.
Season.Ore = {
	id = "seasoncore",
	name = "Season Core",
	tier = "Abyssal",
	value = 260000,
	minDepth = 120, -- reachable without rebirths: the event is for everyone
}

--- Chance per swing inside the window, at depth. Generous on purpose: this is
--- attendance being rewarded, not another lottery.
Season.OreChance = 0.05

--- How many Season Cores earn the badge.
---
--- Tuned to about twenty-five minutes of real mining, travel and banking
--- included. The first pass sat at four minutes, which made the badge
--- something you picked up in passing — and a scarce thing nobody had to work
--- for is not scarce, it is just free. tools/balance-spec.luau fails if this
--- drifts back under eight modelled minutes.
Season.BadgeRequirement = 40

--- Cosmetics granted per season, cycled. Each is permanent and can never be
--- earned again once its season has passed.
Season.Badges = {
	{ title = "season_1", trail = "trail_season_1", label = "FIRST DESCENT" },
	{ title = "season_2", trail = "trail_season_2", label = "COLD SEAM" },
	{ title = "season_3", trail = "trail_season_3", label = "HOLLOW SEASON" },
	{ title = "season_4", trail = "trail_season_4", label = "PRESSURE SEASON" },
}

function Season.number(now: number?): number
	local elapsed = (now or os.time()) - Season.Epoch
	return math.max(1, math.floor(elapsed / (Season.LengthDays * 86400)) + 1)
end

function Season.badge(seasonNumber: number)
	local index = ((seasonNumber - 1) % #Season.Badges) + 1
	return Season.Badges[index]
end

--- Is the live window open right now?
function Season.isOpen(now: number?): boolean
	local parts = os.date("!*t", now or os.time())
	return Season.WindowDays[parts.wday] == true
end

--- Seconds until the window closes (when open) or opens (when shut).
function Season.secondsUntilChange(now: number?): number
	local current = now or os.time()
	local parts = os.date("!*t", current)
	local secondsToday = parts.hour * 3600 + parts.min * 60 + parts.sec
	local secondsLeftToday = 86400 - secondsToday

	if Season.isOpen(current) then
		-- Walk forward through the days that are still open.
		local remaining = secondsLeftToday
		local day = parts.wday
		for _ = 1, 6 do
			day = (day % 7) + 1
			if not Season.WindowDays[day] then
				break
			end
			remaining += 86400
		end
		return remaining
	end

	local remaining = secondsLeftToday
	local day = parts.wday
	for _ = 1, 7 do
		day = (day % 7) + 1
		if Season.WindowDays[day] then
			break
		end
		remaining += 86400
	end
	return remaining
end

return Season
