--!nonstrict
--[[
	Contracts.luau — the weekly ladder, and the 28-day log.

	These two exist because of one specific platform change: Roblox's
	discovery model now measures retention across day 1, days 2-7 AND days
	8-28, and counts "play days per user" rather than raw hours. A game can
	no longer win by holding one player for six hours; it wins by being worth
	opening on twenty-eight separate days.

	Nothing else in DEEP RUSH had an arc longer than a day.

	WEEKLY CONTRACT  one currency (Contract Points), seven tiers, resets
	                 Monday. A daily point cap means the best play is to come
	                 back tomorrow rather than to grind tonight — which is
	                 also exactly what the 60-minute daily playtime cap in the
	                 algorithm rewards.

	DESCENT LOG      one-time milestones for the number of DISTINCT days you
	                 have played. Deliberately spans 28 days, matching the
	                 window the platform grades a new experience on.
]]

local Contracts = {}

--- How Contract Points are earned.
---
--- Every source is an ACTION, never a cash amount. That is deliberate and it
--- was a real bug first: paying points per 1,000 banked looks fair until you
--- notice that payouts grow exponentially with depth and rebirths, so a
--- late-game player emptied the entire daily budget with one deposit while a
--- new player ground for an hour. Actions are scale-invariant — a deep trip
--- is worth the same on day 1 and after ten rebirths.
Contracts.Points = {
	perDeepBank = 14, -- one completed trip from below the deep-bank depth
	perRareOre = 4, -- Rare tier or better
	perEpicOre = 12,
	newCodexEntry = 60,
	perDepthRecord = 2, -- per metre of new personal record
	perCrewMinute = 12, -- mining within bond range of a crewmate
	perRiftOre = 3,
	perQuestClaimed = 25,
}

--- The cap is the point. Hitting it should read as "today is banked, see you
--- tomorrow" rather than as a punishment, so it sits above what a casual
--- session produces and below what a marathon does.
Contracts.DailyPointCap = 1500

-- Roughly one tier per day of play, with the last two needing a good week.
Contracts.Tiers = {
	{ points = 550, reward = { cash = 25000 } },
	{ points = 1400, reward = { cash = 70000, luckMinutes = 15 } },
	{ points = 2700, reward = { cash = 180000 } },
	{ points = 4100, reward = { cash = 400000, cosmetic = "lamp_amber" } },
	{ points = 5700, reward = { cash = 900000, luckMinutes = 30 } },
	{ points = 7500, reward = { cash = 2200000, cosmetic = "trail_ember" } },
	{ points = 9600, reward = { cash = 6000000, cosmetic = "title_contractor", drone = "coolant" } },
}

--- Rotating flavour so the same ladder does not feel identical every Monday.
Contracts.Names = {
	"Deepcore Contract",
	"Blacklight Contract",
	"Cold Seam Contract",
	"Pressure Contract",
	"Hollow Contract",
	"Ashfall Contract",
}

--- Distinct-day milestones. These are one-time and intentionally back-loaded:
--- the day-21 and day-28 prizes exist to be visible on day 2.
Contracts.DescentLog = {
	{ days = 2, reward = { cash = 15000 }, label = "Second Descent" },
	{ days = 3, reward = { cash = 40000, luckMinutes = 20 }, label = "Three Days Down" },
	{ days = 5, reward = { cash = 120000 }, label = "Regular" },
	{ days = 7, reward = { cash = 350000, cosmetic = "lamp_cyan" }, label = "One Week Below" },
	{ days = 10, reward = { cash = 900000 }, label = "Veteran Digger" },
	{ days = 14, reward = { cash = 2500000, drone = "lung" }, label = "Fortnight" },
	{ days = 21, reward = { cash = 9000000, cosmetic = "trail_void" }, label = "Deep Loyalty" },
	{ days = 28, reward = { cash = 30000000, cosmetic = "title_bedrock", drone = "hollowpup" }, label = "Bedrock Club" },
}

--- Monday-anchored ISO-ish week key. UTC so every player rotates at once.
function Contracts.weekKey(): string
	local now = os.time()
	local parts = os.date("!*t", now)
	-- os.date wday: 1 = Sunday. Convert to days since Monday.
	local sinceMonday = (parts.wday + 5) % 7
	local monday = now - sinceMonday * 86400
	local mondayParts = os.date("!*t", monday)
	return string.format("%d-%03d", mondayParts.year, mondayParts.yday)
end

function Contracts.nameForWeek(): string
	local key = Contracts.weekKey()
	local digits = 0
	for character in key:gmatch("%d") do
		digits += tonumber(character)
	end
	return Contracts.Names[(digits % #Contracts.Names) + 1]
end

function Contracts.totalPoints(): number
	return Contracts.Tiers[#Contracts.Tiers].points
end

--- Highest tier index fully earned at `points`.
function Contracts.tierAt(points: number): number
	local reached = 0
	for index, tier in ipairs(Contracts.Tiers) do
		if points >= tier.points then
			reached = index
		end
	end
	return reached
end

return Contracts
