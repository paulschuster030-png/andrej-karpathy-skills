--!nonstrict
--[[
	Rarity.luau — the weighted roll, and the honest odds display.

	Luck does not add a flat bonus; it bends the whole curve. Each tier's
	weight is multiplied by luck^(steps above Common * 0.6), so luck is worth
	dramatically more at the top of the table than the bottom. That is what
	makes a Luck Potion feel different from a Cash Potion.
]]

local Ores = require(script.Parent.Config.Ores)

local Rarity = {}

Rarity.LuckExponent = 0.6

local function effectiveWeight(tier, tierIndex: number, luck: number): number
	if tierIndex <= 1 then
		return tier.weight
	end
	return tier.weight * (luck ^ ((tierIndex - 1) * Rarity.LuckExponent))
end

--- Roll one of the tiers present in `pool` (a tierId -> ores map from
--- Ores.poolAt). Returns the tier id, or nil if the pool is empty.
function Rarity.rollTier(pool, luck: number, rng: Random?): string?
	luck = math.max(luck or 1, 0.1)
	local random = rng or Random.new()

	local total = 0
	local candidates = {}
	for index, tier in ipairs(Ores.Tiers) do
		if pool[tier.id] and #pool[tier.id] > 0 then
			local weight = effectiveWeight(tier, index, luck)
			total += weight
			table.insert(candidates, { id = tier.id, weight = weight })
		end
	end

	if total <= 0 then
		return nil
	end

	-- Walk from the rarest end so floating point error lands on Common,
	-- the tier nobody notices losing a millionth of a percent.
	local roll = random:NextNumber() * total
	for i = #candidates, 1, -1 do
		roll -= candidates[i].weight
		if roll <= 0 then
			return candidates[i].id
		end
	end
	return candidates[1].id
end

--- Probability of each tier in `pool` at `luck`. Used by the codex UI and
--- by the reveal card, which prints the real odds of what you just pulled.
function Rarity.odds(pool, luck: number)
	luck = math.max(luck or 1, 0.1)

	local total = 0
	local weights = {}
	for index, tier in ipairs(Ores.Tiers) do
		if pool[tier.id] and #pool[tier.id] > 0 then
			local weight = effectiveWeight(tier, index, luck)
			weights[tier.id] = weight
			total += weight
		end
	end

	local out = {}
	for id, weight in pairs(weights) do
		out[id] = weight / total
	end
	return out
end

--- Roll a full ore: tier, then a uniform pick inside the tier.
function Rarity.rollOre(depth: number, luck: number, rng: Random?)
	local pool = Ores.poolAt(depth)
	local tierId = Rarity.rollTier(pool, luck, rng)
	if not tierId then
		return nil
	end

	local options = pool[tierId]
	local random = rng or Random.new()
	local ore = options[random:NextInteger(1, #options)]

	local odds = Rarity.odds(pool, luck)
	return ore, odds[tierId] or 0
end

return Rarity
