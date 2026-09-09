--!nonstrict
--[[
	Quests.luau — the "Aufgaben" layer.

	Three tracks, each doing a different job:

	  ONBOARDING  a forced-win chain for the first 5 minutes. Roblox lives or
	              dies on D1 retention, and D1 is decided before minute three.
	              Every step is completable by accident while playing normally.
	  DAILY       three rolled from a pool of twelve, reset at UTC midnight,
	              one free reroll. The reason to come back tomorrow.
	  MILESTONE   permanent, chunky, and visible from level one so there is
	              always a next mountain.

	metric  = the counter QuestService increments (see Server/Quests.luau)
	mode    = "count" adds up, "max" records a personal best
]]

local Quests = {}

Quests.Onboarding = {
	{ id = "ob_mine", name = "First Blood", desc = "Break 5 rocks.", metric = "mine", mode = "count", target = 5, reward = { cash = 150 } },
	{ id = "ob_bank", name = "Cash It In", desc = "Bank your cargo at the surface vault.", metric = "bank_runs", mode = "count", target = 1, reward = { cash = 300 } },
	{ id = "ob_upgrade", name = "Sharper Drill", desc = "Buy any upgrade.", metric = "upgrade", mode = "count", target = 1, reward = { cash = 500 } },
	{ id = "ob_depth", name = "Down We Go", desc = "Reach 50m depth.", metric = "depth", mode = "max", target = 50, reward = { cash = 900 } },
	{ id = "ob_rare", name = "Something Shiny", desc = "Mine a Rare or better ore.", metric = "mine_rare", mode = "count", target = 1, reward = { cash = 1500, luckMinutes = 5 } },
	{ id = "ob_deep", name = "Real Money", desc = "Bank 5,000 in a single trip.", metric = "bank_single", mode = "max", target = 5000, reward = { cash = 4000, drone = "scrap" } },
}

Quests.DailyPool = {
	{ id = "d_mine50", name = "Shift Work", desc = "Mine 50 ores.", metric = "mine", mode = "count", target = 50, reward = { cash = 6000 } },
	{ id = "d_mine150", name = "Double Shift", desc = "Mine 150 ores.", metric = "mine", mode = "count", target = 150, reward = { cash = 18000 } },
	{ id = "d_bank", name = "Payday", desc = "Bank 50,000 total.", metric = "bank", mode = "count", target = 50000, reward = { cash = 12000 } },
	{ id = "d_bankbig", name = "Heavy Haul", desc = "Bank 25,000 in one trip.", metric = "bank_single", mode = "max", target = 25000, reward = { cash = 15000 } },
	{ id = "d_depth300", name = "Pressure Test", desc = "Reach 300m.", metric = "depth", mode = "max", target = 300, reward = { cash = 9000 } },
	{ id = "d_depth700", name = "Cold Feet", desc = "Reach 700m.", metric = "depth", mode = "max", target = 700, reward = { cash = 30000 } },
	{ id = "d_rare", name = "Collector", desc = "Mine 10 Rare or better ores.", metric = "mine_rare", mode = "count", target = 10, reward = { cash = 14000 } },
	{ id = "d_epic", name = "Trophy Hunt", desc = "Mine 3 Epic or better ores.", metric = "mine_epic", mode = "count", target = 3, reward = { cash = 22000, luckMinutes = 10 } },
	{ id = "d_rift", name = "Surge Rider", desc = "Mine 15 ores during a Rift Surge.", metric = "rift_mine", mode = "count", target = 15, reward = { cash = 26000 } },
	{ id = "d_steal", name = "Finders Keepers", desc = "Take 2 crates or snatches from other miners.", metric = "steal", mode = "count", target = 2, reward = { cash = 16000 } },
	{ id = "d_upgrade", name = "Reinvest", desc = "Buy 5 upgrades.", metric = "upgrade", mode = "count", target = 5, reward = { cash = 11000 } },
	{ id = "d_survive", name = "Clean Run", desc = "Bank 5 trips without dying in between.", metric = "clean_banks", mode = "max", target = 5, reward = { cash = 20000, luckMinutes = 15 } },
	{ id = "d_crew", name = "Buddy System", desc = "Mine 10 minutes next to a crewmate.", metric = "crew_minutes", mode = "count", target = 10, reward = { cash = 24000 } },
	{ id = "d_rescue", name = "Good Samaritan", desc = "Return a crewmate's dropped cargo.", metric = "rescue", mode = "count", target = 1, reward = { cash = 18000 } },
}

Quests.DailyCount = 3
Quests.DailyRerolls = 1

Quests.Milestones = {
	{ id = "m_depth1000", name = "Into the Hollow", desc = "Reach 1,000m.", metric = "depth_alltime", mode = "max", target = 1000, reward = { cash = 120000 } },
	{ id = "m_depth2000", name = "Event Horizon", desc = "Reach 2,000m.", metric = "depth_alltime", mode = "max", target = 2000, reward = { cash = 2000000 } },
	{ id = "m_bank1m", name = "Millionaire", desc = "Bank 1,000,000 lifetime.", metric = "bank_alltime", mode = "count", target = 1000000, reward = { cash = 150000 } },
	{ id = "m_bank100m", name = "Shaft Baron", desc = "Bank 100,000,000 lifetime.", metric = "bank_alltime", mode = "count", target = 100000000, reward = { cash = 12000000 } },
	{ id = "m_codex15", name = "Half the Book", desc = "Find 15 different ores.", metric = "codex", mode = "max", target = 15, reward = { cash = 250000 } },
	{ id = "m_codex30", name = "Complete Codex", desc = "Find all 30 ores.", metric = "codex", mode = "max", target = 30, reward = { cash = 25000000, drone = "void", cosmetic = "title_codex" } },
	{ id = "m_rebirth5", name = "Five Lives", desc = "Rebirth 5 times.", metric = "rebirths", mode = "max", target = 5, reward = { cash = 1500000 } },
	{ id = "m_steal50", name = "Shaft Pirate", desc = "Take 50 crates or snatches.", metric = "steal_alltime", mode = "count", target = 50, reward = { cash = 800000, cosmetic = "title_pirate" } },
	{ id = "m_crew", name = "Never Alone", desc = "Mine 300 minutes alongside crewmates.", metric = "crew_minutes_alltime", mode = "count", target = 300, reward = { cash = 4000000, cosmetic = "trail_gold" } },
}

Quests.All = {}
for _, list in ipairs({ Quests.Onboarding, Quests.DailyPool, Quests.Milestones }) do
	for _, quest in ipairs(list) do
		Quests.All[quest.id] = quest
	end
end

return Quests
