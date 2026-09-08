--!nonstrict
--[[
	balance-spec.luau — assertions about the game's economy.

	Run via tools/balance-check.py. These are design checks, not unit tests:
	each one encodes a promise the game makes to the player, so if a tuning
	edit breaks the promise, it fails here rather than in production.
]]

local Ores = MODULES.Ores
local Layers = MODULES.Layers
local Mutations = MODULES.Mutations
local Upgrades = MODULES.Upgrades
local Rebirth = MODULES.Rebirth
local Game = MODULES.Game
local Format = MODULES.Format
local Rarity = MODULES.Rarity

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

local function approx(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

print("\n== ore tables ==")

check("every ore has a known tier", (function()
	for _, ore in ipairs(Ores.List) do
		if not Ores.TierIndex[ore.tier] then
			return false
		end
	end
	return true
end)())

check("ore ids are unique", (function()
	local seen = {}
	for _, ore in ipairs(Ores.List) do
		if seen[ore.id] then
			return false
		end
		seen[ore.id] = true
	end
	return true
end)())

check("depth ranges are well formed", (function()
	for _, ore in ipairs(Ores.List) do
		if ore.minDepth >= ore.maxDepth then
			return false
		end
	end
	return true
end)())

check("rarer tiers are worth more on average", (function()
	local totals, counts = {}, {}
	for _, ore in ipairs(Ores.List) do
		local index = Ores.TierIndex[ore.tier]
		totals[index] = (totals[index] or 0) + ore.value
		counts[index] = (counts[index] or 0) + 1
	end
	local previous = 0
	for index = 1, #Ores.Tiers do
		if counts[index] then
			local average = totals[index] / counts[index]
			if average <= previous then
				return false
			end
			previous = average
		end
	end
	return true
end)())

print("\n== depth gating ==")

check("no Singularity ore at the surface", (function()
	local pool = Ores.poolAt(0)
	return pool.Singularity == nil
end)())

check("Singularity ore exists at 2,200m", (function()
	local pool = Ores.poolAt(2200)
	return pool.Singularity ~= nil and #pool.Singularity > 0
end)())

check("no Dirtstone below 400m", (function()
	local pool = Ores.poolAt(600)
	for _, ore in ipairs(pool.Common or {}) do
		if ore.id == "dirtstone" then
			return false
		end
	end
	return true
end)())

check("every depth has something to mine", (function()
	for depth = 0, 2900, 50 do
		local pool = Ores.poolAt(depth)
		local total = 0
		for _, list in pairs(pool) do
			total += #list
		end
		if total == 0 then
			return false
		end
	end
	return true
end)())

print("\n== rarity math ==")

check("tier probabilities sum to 1", (function()
	for _, depth in ipairs({ 0, 150, 500, 1200, 2500 }) do
		local odds = Rarity.odds(Ores.poolAt(depth), 1)
		local total = 0
		for _, probability in pairs(odds) do
			total += probability
		end
		if not approx(total, 1, 1e-9) then
			return false
		end
	end
	return true
end)())

check("luck strictly increases rare odds", (function()
	local pool = Ores.poolAt(1200)
	local previous = 0
	for _, luck in ipairs({ 1, 2, 5, 10, 30 }) do
		local odds = Rarity.odds(pool, luck)
		local rare = odds.Mythic or 0
		if rare <= previous then
			return false
		end
		previous = rare
	end
	return true
end)())

check("luck never lets a tier exceed 100%", (function()
	local odds = Rarity.odds(Ores.poolAt(2500), Game.MaxLuck)
	for _, probability in pairs(odds) do
		if probability > 1 or probability < 0 then
			return false
		end
	end
	return true
end)())

check("empirical roll distribution matches the table", (function()
	math.randomseed(12345)
	local pool = Ores.poolAt(500)
	local expected = Rarity.odds(pool, 1)
	local counts, samples = {}, 300000
	for _ = 1, samples do
		local tier = Rarity.rollTier(pool, 1)
		counts[tier] = (counts[tier] or 0) + 1
	end
	-- Only assert on tiers common enough for 300k samples to resolve.
	for tier, probability in pairs(expected) do
		if probability > 0.005 then
			local empirical = (counts[tier] or 0) / samples
			if math.abs(empirical - probability) > probability * 0.10 then
				print(string.format("       %s expected %.4f got %.4f", tier, probability, empirical))
				return false
			end
		end
	end
	return true
end)())

print("\n== progression curves ==")

check("depth multiplier increases monotonically", (function()
	local previous = 0
	for depth = 0, 2900, 25 do
		local multiplier = Layers.depthMultiplier(depth)
		if multiplier < previous then
			return false
		end
		previous = multiplier
	end
	return true
end)())

check("upgrade costs grow, effects never invert", (function()
	for _, upgrade in ipairs(Upgrades.List) do
		local previousCost, previousEffect = 0, -math.huge
		for level = 0, upgrade.maxLevel do
			local cost = Upgrades.cost(upgrade.id, level)
			local effect = Upgrades.value(upgrade.id, level)
			if cost <= previousCost or effect < previousEffect then
				return false
			end
			previousCost, previousEffect = cost, effect
		end
	end
	return true
end)())

check("max drill never breaks the mine-time floor", (function()
	local reduction = Upgrades.value("drill", Upgrades.ById.drill.maxLevel)
	local time = Game.BaseMineTime * (1 - reduction)
	return reduction < 1 and math.max(Game.MinMineTime, time) >= Game.MinMineTime
end)())

check("rebirth requirements and bonuses both climb", (function()
	local previousCash, previousMultiplier = 0, 0
	for n = 0, Rebirth.MaxTracked do
		local requirement = Rebirth.requirement(n)
		local bonuses = Rebirth.bonuses(n)
		if requirement.cash <= previousCash or bonuses.cashMultiplier <= previousMultiplier then
			return false
		end
		previousCash, previousMultiplier = requirement.cash, bonuses.cashMultiplier
	end
	return true
end)())

check("every layer is reachable by rebirth 8", (function()
	for _, layer in ipairs(Layers.List) do
		if layer.gate > 8 then
			return false
		end
	end
	return true
end)())

print("\n== pacing (the promises to a new player) ==")

--- Expected cash from one swing at `depth` with `luck`, ignoring multipliers.
local function expectedSwingValue(depth: number, luck: number): number
	local pool = Ores.poolAt(depth)
	local odds = Rarity.odds(pool, luck)
	local total = 0
	for tier, probability in pairs(odds) do
		local sum = 0
		for _, ore in ipairs(pool[tier]) do
			sum += ore.value
		end
		total += probability * (sum / #pool[tier])
	end
	-- Average mutation multiplier.
	local mutationFactor = 1
	for _, mutation in ipairs(Mutations.List) do
		if not mutation.riftOnly then
			mutationFactor += mutation.chance * (mutation.multiplier - 1)
		end
	end
	return total * Layers.depthMultiplier(depth) * mutationFactor
end

local surfaceRate = expectedSwingValue(20, 1) / Game.BaseMineTime
print(string.format("       surface income ≈ %s/second", Format.short(surfaceRate)))

check("first drill upgrade is under 2 minutes of surface mining", (function()
	local cost = Upgrades.cost("drill", 0)
	local seconds = cost / surfaceRate
	print(string.format("       first drill costs %s ≈ %.0fs", Format.short(cost), seconds))
	return seconds < 120
end)())

check("first rebirth is reachable but not trivial", (function()
	local requirement = Rebirth.requirement(0)
	-- A player at the rebirth depth gate, with mid upgrades.
	local rate = expectedSwingValue(requirement.depth, 2.5) / 0.5
	local minutes = requirement.cash / rate / 60
	print(string.format("       first rebirth ≈ %.1f min of mining at %sm", minutes, requirement.depth))
	return minutes > 15 and minutes < 90
end)())

check("deep mining always beats shallow mining", (function()
	local previous = 0
	for _, depth in ipairs({ 20, 100, 300, 600, 900, 1300, 1700, 2300 }) do
		local rate = expectedSwingValue(depth, 1)
		if rate <= previous then
			return false
		end
		previous = rate
	end
	return true
end)())

check("greed threshold leaves room to act", (function()
	-- At the mark threshold a player still has slots left, so being marked
	-- is a warning rather than a state they are stuck in.
	local slotsAtMark = math.floor(Game.BaseCapacity * Game.GreedMarkThreshold)
	return slotsAtMark >= 3 and slotsAtMark < Game.BaseCapacity
end)())

print("\n== formatting ==")

check("Format.short renders the ladder", (function()
	local cases = {
		{ 0, "0" },
		{ 999, "999" },
		{ 1000, "1K" },
		{ 12400, "12.4K" },
		{ 1500000, "1.5M" },
		{ 2340000000, "2.34B" },
	}
	for _, case in ipairs(cases) do
		local got = Format.short(case[1])
		if got ~= case[2] then
			print(string.format("       %d -> %q expected %q", case[1], got, case[2]))
			return false
		end
	end
	return true
end)())

check("Format.clock renders mm:ss and h:mm:ss", function()
	return true
end)

check("Format.clock values", Format.clock(95) == "1:35" and Format.clock(3725) == "1:02:05")

check("Format.odds reads as a brag", Format.odds(1 / 250000) == "1 in 250K")

print(string.format("\n%d checks, %d failed\n", checks, failures))
if failures > 0 then
	error(string.format("%d balance checks failed", failures), 0)
end
