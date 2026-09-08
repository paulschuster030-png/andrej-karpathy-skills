--!nonstrict
--[[
	Layers.luau — the strata you dig through.

	A layer is a promise and a threat: better ore, worse conditions. The
	`gate` field is what turns rebirth into a door rather than a number —
	you physically cannot survive the Singularity until you have earned it.
]]

local Layers = {}

Layers.List = {
	{
		id = "topsoil",
		name = "Topsoil",
		minDepth = 0,
		maxDepth = 40,
		rock = { 106, 84, 62 },
		fog = 220,
		ambient = { 70, 70, 78 },
		oxygenDrain = 0, -- surface air, no timer pressure while learning
		hazard = nil,
		valueMultiplier = 1.0,
		gate = 0,
		blurb = "Loose dirt. Nothing here bites.",
	},
	{
		id = "limestone",
		name = "Limestone Shelf",
		minDepth = 40,
		maxDepth = 120,
		rock = { 150, 146, 132 },
		fog = 190,
		ambient = { 58, 58, 66 },
		oxygenDrain = 0.4,
		hazard = { kind = "cavein", chance = 0.05, damage = 12 },
		valueMultiplier = 1.15,
		gate = 0,
		blurb = "Old seabed. The ceiling is not as solid as it looks.",
	},
	{
		id = "ironvein",
		name = "Iron Vein",
		minDepth = 120,
		maxDepth = 260,
		rock = { 122, 98, 88 },
		fog = 150,
		ambient = { 48, 44, 52 },
		oxygenDrain = 0.8,
		hazard = { kind = "cavein", chance = 0.09, damage = 18 },
		valueMultiplier = 1.4,
		gate = 0,
		blurb = "Where the money starts. Bring a bigger backpack.",
	},
	{
		id = "crystal",
		name = "Crystal Caves",
		minDepth = 260,
		maxDepth = 450,
		rock = { 92, 104, 148 },
		fog = 120,
		ambient = { 40, 44, 70 },
		oxygenDrain = 1.2,
		hazard = { kind = "gas", chance = 0.12, damage = 14 },
		valueMultiplier = 1.9,
		gate = 0,
		blurb = "Beautiful. Also full of pockets that are not air.",
	},
	{
		id = "magma",
		name = "Magma Shelf",
		minDepth = 450,
		maxDepth = 700,
		rock = { 78, 40, 34 },
		fog = 95,
		ambient = { 62, 30, 24 },
		oxygenDrain = 1.8,
		hazard = { kind = "heat", chance = 0.16, damage = 20 },
		valueMultiplier = 2.6,
		gate = 1,
		blurb = "The rock is warm. Then it is not rock.",
	},
	{
		id = "frozen",
		name = "Frozen Deep",
		minDepth = 700,
		maxDepth = 1000,
		rock = { 150, 186, 208 },
		fog = 80,
		ambient = { 40, 58, 74 },
		oxygenDrain = 2.4,
		hazard = { kind = "freeze", chance = 0.18, damage = 22 },
		valueMultiplier = 3.6,
		gate = 2,
		blurb = "Water that stopped moving a very long time ago.",
	},
	{
		id = "hollow",
		name = "The Hollow",
		minDepth = 1000,
		maxDepth = 1400,
		rock = { 44, 40, 48 },
		fog = 55,
		ambient = { 20, 18, 24 },
		oxygenDrain = 3.2,
		hazard = { kind = "hollow", chance = 0.22, damage = 30 },
		valueMultiplier = 5.2,
		gate = 3,
		blurb = "Something down here learned what a pickaxe sounds like.",
	},
	{
		id = "abyss",
		name = "Abyss Core",
		minDepth = 1400,
		maxDepth = 2000,
		rock = { 26, 24, 38 },
		fog = 40,
		ambient = { 14, 12, 24 },
		oxygenDrain = 4.2,
		hazard = { kind = "pressure", chance = 0.26, damage = 38 },
		valueMultiplier = 7.5,
		gate = 5,
		blurb = "Pressure that folds steel. Ore that funds a rebirth in one trip.",
	},
	{
		id = "singularity",
		name = "The Singularity",
		minDepth = 2000,
		maxDepth = 3000,
		rock = { 12, 10, 16 },
		fog = 26,
		ambient = { 8, 6, 14 },
		oxygenDrain = 5.5,
		hazard = { kind = "collapse", chance = 0.32, damage = 55 },
		valueMultiplier = 12.0,
		gate = 8,
		blurb = "Down is no longer a direction here.",
	},
}

Layers.ById = {}
for i, layer in ipairs(Layers.List) do
	layer.index = i
	Layers.ById[layer.id] = layer
end

--- The layer a given depth (in meters) falls into. Clamped at both ends.
function Layers.at(depth: number)
	for _, layer in ipairs(Layers.List) do
		if depth < layer.maxDepth then
			return layer
		end
	end
	return Layers.List[#Layers.List]
end

--- Depth alone does not pay; the layer's multiplier plus a smooth per-meter
--- curve does. Smooth matters: a cliff at a layer edge teaches players to
--- park exactly one meter past it.
function Layers.depthMultiplier(depth: number): number
	local layer = Layers.at(depth)
	return layer.valueMultiplier * (1 + depth / 900)
end

--- Which layers a player with `rebirths` may survive in.
function Layers.unlocked(rebirths: number)
	local out = {}
	for _, layer in ipairs(Layers.List) do
		if rebirths >= layer.gate then
			table.insert(out, layer)
		end
	end
	return out
end

function Layers.maxSafeDepth(rebirths: number): number
	local deepest = Layers.List[1]
	for _, layer in ipairs(Layers.List) do
		if rebirths >= layer.gate then
			deepest = layer
		end
	end
	return deepest.maxDepth
end

return Layers
