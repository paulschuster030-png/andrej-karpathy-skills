--!nonstrict
--[[
	Rarity.luau — the weighted roll, and the honest odds display.

	Luck does not add a flat bonus; it bends the whole curve. Each tier's
	weight is multiplied by luck^(steps above Common * 0.6), so luck is worth
	dramatically more at the top of the table than the bottom. That is what
	makes a Luck Potion feel different from a Cash Potion.

	Where the roll happens changed once the ore became visible in the rock.
	A node decides what it is when it spawns, at luck 1 — the wall has no idea
	who is going to swing at it, and a shared node cannot roll on one player's
	luck. So luck moved to the swing, as a second chance:

	  1. the node is what you can see: gold vein, diamond, plain dirtstone
	  2. with probability 1 - 1/luck you also roll the luck-weighted table
	  3. you keep whichever is rarer — never worse than what you could see

	Two things fall out of that, and both are worth more than the old
	invisible curve. The world stops lying: a diamond in the wall is a
	diamond, and running for it is a real decision. And luck becomes an event
	you watch happen — LUCKY STRIKE, gold turning into something better —
	instead of a number that quietly bends a table you never see.

	`Rarity.odds` returns the honest result of all three steps, so the codex
	and the reveal card still print what actually happened.
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

--- Share of swings that get the second, luck-weighted roll. At luck 1 it is
--- zero and the node is simply what it looks like; it approaches 1 from
--- below, so the visible ore always keeps some weight.
function Rarity.luckShare(luck: number): number
	luck = math.max(luck or 1, 1)
	return 1 - 1 / luck
end

--- Tier probabilities for a single weighted roll at `luck`. Internal: this is
--- one of the three steps, not what a player experiences.
local function tierOdds(pool, luck: number)
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

Rarity.tierOdds = tierOdds

--- What a player actually pulls: the node's own tier, kept unless the luck
--- roll beats it.
---
--- max(node, lucky) lands on tier i when the node is i and the lucky roll did
--- not pass it, or the lucky roll is i and the node was below. Both terms are
--- exact, so the odds printed on a reveal card are the real ones and not an
--- approximation of them.
function Rarity.odds(pool, luck: number)
	luck = math.max(luck or 1, 0.1)
	local base = tierOdds(pool, 1)
	if luck <= 1 then
		return base
	end

	local lucky = tierOdds(pool, luck)
	local share = Rarity.luckShare(luck)

	local out = {}
	local belowNode = 0 -- P(node tier < i), walking the ladder upward
	local upToLucky = 0 -- P(lucky roll <= i)
	for _, tier in ipairs(Ores.Tiers) do
		local b = base[tier.id]
		if b then
			local l = lucky[tier.id] or 0
			upToLucky += l
			out[tier.id] = (1 - share) * b + share * (b * upToLucky + l * belowNode)
			belowNode += b
		end
	end
	return out
end

--- Roll what a node is when it spawns: no luck, because nobody owns it yet.
function Rarity.rollNodeOre(depth: number, rng: Random?)
	local pool = Ores.poolAt(depth)
	local tierId = Rarity.rollTier(pool, 1, rng)
	if not tierId then
		return nil
	end

	local options = pool[tierId]
	local random = rng or Random.new()
	return options[random:NextInteger(1, #options)]
end

--- The swing. Returns the ore you get, its real probability, and whether luck
--- is what got it for you.
function Rarity.resolve(nodeOre, depth: number, luck: number, rng: Random?)
	local pool = Ores.poolAt(depth)
	local odds = Rarity.odds(pool, luck)
	local result = nodeOre
	local upgraded = false

	luck = math.max(luck or 1, 0.1)
	local random = rng or Random.new()
	if luck > 1 and random:NextNumber() < Rarity.luckShare(luck) then
		local tierId = Rarity.rollTier(pool, luck, random)
		if tierId and Ores.TierIndex[tierId] > Ores.TierIndex[nodeOre.tier] then
			local options = pool[tierId]
			result = options[random:NextInteger(1, #options)]
			upgraded = true
		end
	end

	return result, odds[result.tier] or 0, upgraded
end

--- Roll an ore end to end, as if a node had spawned and been struck at once.
--- Nothing in the game does that any more; the balance harness does.
function Rarity.rollOre(depth: number, luck: number, rng: Random?)
	local nodeOre = Rarity.rollNodeOre(depth, rng)
	if not nodeOre then
		return nil
	end
	local ore, probability = Rarity.resolve(nodeOre, depth, luck, rng)
	return ore, probability
end

return Rarity
