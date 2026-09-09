--!nonstrict
--[[
	Game.luau — global tuning knobs.

	Every number here was picked to serve one of three loops:
	  MICRO  (3-8s)   swing -> ore reveal -> number pops
	  CORE   (60-90s) descend -> fill cargo -> decide (bank or push deeper)
	  META   (days)   upgrades -> rebirth -> codex completion

	Change these first when the game feels slow or too generous.
]]

return {
	Name = "DEEP RUSH",

	-- MICRO loop ------------------------------------------------------------
	BaseMineTime = 1.15, -- seconds to break a node at drill level 0
	MinMineTime = 0.18, -- floor, so max drill still feels like work
	MineReach = 22, -- studs; generous because mobile aim is imprecise
	NodeRespawn = 9, -- seconds until a broken node returns

	-- CORE loop -------------------------------------------------------------
	BaseCapacity = 8, -- ore slots before the backpack is full
	StudsPerMeter = 3, -- world scale: 3 studs of descent = 1 "meter" of depth
	SurfaceY = 0, -- y=0 is depth 0
	BankRadius = 26, -- studs around the vault that count as "at the surface"
	DeathCargoLoss = 0.30, -- 30% burns, 70% drops as a lootable crate
	CrateLifetime = 25, -- seconds a dropped crate stays stealable
	CrateFreeForAllDelay = 6, -- owner-only window before it opens to everyone

	-- Greed: the self-balancing PvP dial -------------------------------------
	-- greed = cargo value / value you could have banked already.
	-- Cross the threshold and you glow, you show up on radar, you are stealable.
	GreedMarkThreshold = 0.60,
	GreedStealShare = 0.15, -- fraction of cargo a successful snatch takes
	SnatchCooldown = 45,
	SnatchRange = 18,
	NewPlayerGraceSeconds = 600, -- 10 minutes of total immunity
	NewPlayerGraceDepth = 100, -- ...or until they have been this deep

	-- Progression -----------------------------------------------------------
	XpPerCashUnit = 0.02,
	LevelCurve = 1.18, -- xp needed = 120 * curve^level
	BaseXpToLevel = 120,
	MaxLuck = 30, -- hard cap so stacked buffs cannot break the tier table
	BankStreakStep = 0.04, -- +4% per consecutive deep bank
	BankStreakMax = 0.40,
	DeepBankDepth = 150, -- a bank only counts for streak if you went this deep

	-- Live ops --------------------------------------------------------------
	RiftInterval = 720, -- a Rift Surge every 12 minutes
	RiftJitter = 120,
	RiftDuration = 90,
	RiftLuckMultiplier = 5,
	FirstRiftDelay = 180, -- first one lands early so new players see it

	-- Hazards ---------------------------------------------------------------
	BaseOxygen = 60,
	OxygenRegenRate = 18, -- per second at the surface
	-- Fast enough that walking out of a gas cloud feels like it stopped the
	-- moment you left. Oxygen is only replicated about once a second, though;
	-- see Server/Hazards.luau.
	HazardTickRate = 0.35,

	-- Services --------------------------------------------------------------
	AutosaveInterval = 120,
	StateSyncRate = 0.25, -- max client state pushes per player per second
	PlaytimeRewardInterval = 600, -- a chest every 10 minutes of play
	LeaderboardRefresh = 90,

	-- Set false while testing in Studio without a published place.
	UseDataStores = true,
	Debug = false,
}
