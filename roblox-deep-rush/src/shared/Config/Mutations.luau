--!nonstrict
--[[
	Mutations.luau — the second multiplier on every ore.

	Rarity alone tops out. Mutations stack on top of it, which is what
	produces the absurd shareable number: a Mythic Ember Core is nice, a
	GOLDEN RIFT-TOUCHED Ember Core is a screenshot. Cheap to add, and it
	multiplies the size of the "best pull ever" space by 40x.
]]

local Mutations = {}

-- chance is per-roll at luck 1. luckScale says how much luck helps: 0 means
-- luck cannot buy it (keeps Golden feeling like a gift, not a purchase).
Mutations.List = {
	{ id = "glowing", name = "Glowing", multiplier = 2, chance = 0.080, luckScale = 0.6, color = { 130, 255, 160 } },
	{ id = "frozen", name = "Frozen", multiplier = 3, chance = 0.030, luckScale = 0.6, color = { 150, 220, 255 } },
	{ id = "cursed", name = "Cursed", multiplier = 5, chance = 0.010, luckScale = 0.5, color = { 190, 60, 220 } },
	{ id = "golden", name = "Golden", multiplier = 8, chance = 0.0025, luckScale = 0.0, color = { 255, 205, 70 } },
	{ id = "rift", name = "Rift-Touched", multiplier = 15, chance = 0.050, luckScale = 0.2, riftOnly = true, color = { 255, 90, 200 } },
}

Mutations.ById = {}
for _, mutation in ipairs(Mutations.List) do
	Mutations.ById[mutation.id] = mutation
end

--- Roll a mutation, rarest first so a Golden never gets shadowed by a Glowing.
--- Returns nil for a plain ore (the common case, by design).
function Mutations.roll(luck: number, riftActive: boolean, rng: Random?)
	local random = rng or Random.new()
	for i = #Mutations.List, 1, -1 do
		local mutation = Mutations.List[i]
		if not mutation.riftOnly or riftActive then
			local chance = mutation.chance * (1 + (luck - 1) * mutation.luckScale)
			if random:NextNumber() < math.min(chance, 0.75) then
				return mutation
			end
		end
	end
	return nil
end

function Mutations.color(id: string?): Color3?
	local mutation = id and Mutations.ById[id]
	if not mutation then
		return nil
	end
	return Color3.fromRGB(mutation.color[1], mutation.color[2], mutation.color[3])
end

return Mutations
