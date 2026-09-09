--!nonstrict
--[[
	Ores.luau — the rarity ladder and the 30 things you can pull out of the ground.

	Two-step roll (see Shared/Rarity.luau):
	  1. pick a TIER from the weights below, filtered to what this depth allows
	  2. pick uniformly among the ores of that tier that are legal at this depth

	Filtering by depth is what makes descending feel like progress: the same
	swing at 1500m simply cannot produce Dirtstone, and Singularity ore does
	not exist above 2000m no matter how much luck you stack.
]]

local Ores = {}

-- Tier weights are relative. Base total is ~1353, so a Singularity roll is
-- roughly 1 in 540,000 in a layer where every tier is legal — and far better
-- inside the deepest strata, where the common tiers are filtered out.
Ores.Tiers = {
	{ id = "Common", weight = 1000, color = { 178, 182, 190 }, glow = 0.0, shake = 0 },
	{ id = "Uncommon", weight = 260, color = { 96, 220, 118 }, glow = 0.15, shake = 0 },
	{ id = "Rare", weight = 70, color = { 74, 148, 255 }, glow = 0.35, shake = 0.2 },
	{ id = "Epic", weight = 18, color = { 176, 92, 255 }, glow = 0.55, shake = 0.4 },
	{ id = "Legendary", weight = 4.5, color = { 255, 190, 62 }, glow = 0.8, shake = 0.7 },
	{ id = "Mythic", weight = 0.9, color = { 255, 68, 122 }, glow = 1.0, shake = 1.0 },
	{ id = "Abyssal", weight = 0.12, color = { 0, 255, 214 }, glow = 1.0, shake = 1.4 },
	{ id = "Singularity", weight = 0.0025, color = { 255, 255, 255 }, glow = 1.0, shake = 2.0 },
}

Ores.TierIndex = {}
for i, tier in ipairs(Ores.Tiers) do
	Ores.TierIndex[tier.id] = i
end

-- value is the base payout at depth 0; the depth multiplier does the rest.
-- minDepth/maxDepth are in meters and gate which strata can produce the ore.
Ores.List = {
	-- Topsoil / Limestone ---------------------------------------------------
	{ id = "dirtstone", name = "Dirtstone", tier = "Common", value = 10, minDepth = 0, maxDepth = 260 },
	{ id = "coal", name = "Coal Lump", tier = "Common", value = 14, minDepth = 0, maxDepth = 450 },
	{ id = "clay", name = "Clay Nodule", tier = "Common", value = 18, minDepth = 0, maxDepth = 260 },
	{ id = "copper", name = "Copper Seam", tier = "Uncommon", value = 42, minDepth = 0, maxDepth = 450 },
	{ id = "fossil", name = "Fossil Shell", tier = "Uncommon", value = 60, minDepth = 40, maxDepth = 700 },
	{ id = "iron", name = "Iron Chunk", tier = "Uncommon", value = 78, minDepth = 40, maxDepth = 700 },
	{ id = "quartz", name = "Quartz Cluster", tier = "Rare", value = 190, minDepth = 40, maxDepth = 700 },
	{ id = "silver", name = "Silver Vein", tier = "Rare", value = 240, minDepth = 40, maxDepth = 1000 },

	-- Iron Vein / Crystal Caves --------------------------------------------
	{ id = "gold", name = "Gold Vein", tier = "Rare", value = 320, minDepth = 120, maxDepth = 1400 },
	{ id = "cobalt", name = "Cobalt Spire", tier = "Epic", value = 760, minDepth = 120, maxDepth = 1400 },
	{ id = "meteorite", name = "Meteorite Shard", tier = "Epic", value = 950, minDepth = 120, maxDepth = 2000 },
	{ id = "relic", name = "Buried Relic", tier = "Legendary", value = 2600, minDepth = 120, maxDepth = 2000 },
	{ id = "amethyst", name = "Amethyst Bloom", tier = "Epic", value = 1100, minDepth = 260, maxDepth = 1400 },
	{ id = "emerald", name = "Emerald Heart", tier = "Legendary", value = 3200, minDepth = 260, maxDepth = 2000 },
	{ id = "diamond", name = "Raw Diamond", tier = "Legendary", value = 4400, minDepth = 260, maxDepth = 2000 },
	{ id = "prism", name = "Prism Core", tier = "Mythic", value = 14000, minDepth = 260, maxDepth = 2000 },

	-- Magma Shelf / Frozen Deep --------------------------------------------
	{ id = "obsidian", name = "Obsidian Slab", tier = "Rare", value = 520, minDepth = 450, maxDepth = 2000 },
	{ id = "magmasteel", name = "Magmasteel", tier = "Epic", value = 1600, minDepth = 450, maxDepth = 2000 },
	{ id = "ruby", name = "Ruby Heart", tier = "Legendary", value = 6200, minDepth = 450, maxDepth = 2000 },
	{ id = "ember", name = "Ember Core", tier = "Mythic", value = 21000, minDepth = 450, maxDepth = 2000 },
	{ id = "cryonite", name = "Cryonite", tier = "Epic", value = 2400, minDepth = 700, maxDepth = 2000 },
	{ id = "glacier", name = "Glacier Pearl", tier = "Legendary", value = 8800, minDepth = 700, maxDepth = 2000 },
	{ id = "frostcore", name = "Frostbound Core", tier = "Mythic", value = 31000, minDepth = 700, maxDepth = 2000 },

	-- The Hollow ------------------------------------------------------------
	{ id = "hollowbone", name = "Hollow Bone", tier = "Legendary", value = 12000, minDepth = 1000, maxDepth = 3000 },
	{ id = "whisper", name = "Whisper Shard", tier = "Mythic", value = 46000, minDepth = 1000, maxDepth = 3000 },
	{ id = "nullstone", name = "Nullstone", tier = "Abyssal", value = 210000, minDepth = 1000, maxDepth = 3000 },

	-- Abyss Core ------------------------------------------------------------
	{ id = "abyssite", name = "Abyssite", tier = "Mythic", value = 68000, minDepth = 1400, maxDepth = 3000 },
	{ id = "voidglass", name = "Voidglass", tier = "Abyssal", value = 340000, minDepth = 1400, maxDepth = 3000 },
	{ id = "leviathan", name = "Leviathan Scale", tier = "Abyssal", value = 520000, minDepth = 1400, maxDepth = 3000 },

	-- The Singularity -------------------------------------------------------
	{ id = "fragment", name = "Singularity Fragment", tier = "Singularity", value = 4200000, minDepth = 2000, maxDepth = 3000 },
	{ id = "origin", name = "Origin Shard", tier = "Singularity", value = 9000000, minDepth = 2200, maxDepth = 3000 },

	-- Event-only. `seasonOnly` keeps it out of Ores.poolAt entirely, so it
	-- cannot be rolled outside a live window no matter how much luck is
	-- stacked. Server/Season.luau injects it directly.
	{ id = "seasoncore", name = "Season Core", tier = "Abyssal", value = 260000, minDepth = 120, maxDepth = 3000, seasonOnly = true },
}

Ores.ById = {}
for _, ore in ipairs(Ores.List) do
	Ores.ById[ore.id] = ore
end

-- Cache the depth->pool lookup: Mining calls this on every swing.
local poolCache = {}

--- Every ore legal at `depth`, grouped by tier id.
function Ores.poolAt(depth: number)
	local bucket = math.floor(depth / 20) * 20
	local cached = poolCache[bucket]
	if cached then
		return cached
	end

	local byTier = {}
	for _, ore in ipairs(Ores.List) do
		if not ore.seasonOnly and bucket >= ore.minDepth and bucket <= ore.maxDepth then
			local list = byTier[ore.tier]
			if not list then
				list = {}
				byTier[ore.tier] = list
			end
			table.insert(list, ore)
		end
	end

	poolCache[bucket] = byTier
	return byTier
end

function Ores.color(tierId: string): Color3
	local tier = Ores.Tiers[Ores.TierIndex[tierId] or 1]
	return Color3.fromRGB(tier.color[1], tier.color[2], tier.color[3])
end

function Ores.tier(tierId: string)
	return Ores.Tiers[Ores.TierIndex[tierId] or 1]
end

return Ores
