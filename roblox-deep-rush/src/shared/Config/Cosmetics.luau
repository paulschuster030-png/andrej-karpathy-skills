--!nonstrict
--[[
	Cosmetics.luau — the status layer.

	Added deliberately after the 2026 spending picture became clear: players
	now put more into cosmetics, status items and rarity-flex than into
	time-skips. DEEP RUSH sold only speed and convenience, which is the
	category that has been losing share.

	The rule that makes this work: a cosmetic must be visible TO OTHER
	PLAYERS. A skin only you can see is a screenshot; a skin the shaft can see
	is status. So all three kinds render on the character or above it.

	Most are earned. The purchasable ones are never the best-looking ones.
]]

local Cosmetics = {}

Cosmetics.List = {
	-- Helmet lamps: the light cone you drag through the dark.
	{ id = "lamp_white", kind = "lamp", name = "Standard Lamp", color = { 255, 244, 214 }, source = "default" },
	{ id = "lamp_amber", kind = "lamp", name = "Amber Lamp", color = { 255, 176, 60 }, source = "contract" },
	{ id = "lamp_cyan", kind = "lamp", name = "Ice Lamp", color = { 120, 230, 255 }, source = "descent" },
	{ id = "lamp_violet", kind = "lamp", name = "Ultraviolet Lamp", color = { 190, 110, 255 }, source = "shop", cost = 750000 },
	{ id = "lamp_blood", kind = "lamp", name = "Blood Lamp", color = { 255, 70, 70 }, source = "shop", cost = 3000000 },

	-- Trails: what people see when you fall past them.
	{ id = "trail_none", kind = "trail", name = "No Trail", color = { 255, 255, 255 }, source = "default" },
	{ id = "trail_ember", kind = "trail", name = "Ember Trail", color = { 255, 130, 50 }, source = "contract" },
	{ id = "trail_frost", kind = "trail", name = "Frost Trail", color = { 160, 225, 255 }, source = "shop", cost = 1500000 },
	{ id = "trail_void", kind = "trail", name = "Void Trail", color = { 150, 60, 255 }, source = "descent" },
	{ id = "trail_gold", kind = "trail", name = "Gold Trail", color = { 255, 205, 90 }, source = "milestone" },

	-- Titles: shown on the nameplate above your head, next to your rebirth.
	{ id = "title_none", kind = "title", name = "—", text = "", source = "default" },
	{ id = "title_contractor", kind = "title", name = "CONTRACTOR", text = "CONTRACTOR", color = { 255, 205, 90 }, source = "contract" },
	{ id = "title_bedrock", kind = "title", name = "BEDROCK CLUB", text = "BEDROCK CLUB", color = { 110, 230, 255 }, source = "descent" },
	{ id = "title_pirate", kind = "title", name = "SHAFT PIRATE", text = "SHAFT PIRATE", color = { 255, 88, 120 }, source = "milestone" },
	{ id = "title_codex", kind = "title", name = "CODEX COMPLETE", text = "CODEX COMPLETE", color = { 255, 255, 255 }, source = "milestone" },

	-- Season badges. Earned only inside a live window, never sold, never
	-- repeated. A player wearing one was demonstrably there that weekend, and
	-- that is the entire value.
	{ id = "season_1", kind = "title", name = "S1 · FIRST DESCENT", text = "S1 · FIRST DESCENT", color = { 255, 205, 90 }, source = "season" },
	{ id = "season_2", kind = "title", name = "S2 · COLD SEAM", text = "S2 · COLD SEAM", color = { 150, 220, 255 }, source = "season" },
	{ id = "season_3", kind = "title", name = "S3 · HOLLOW SEASON", text = "S3 · HOLLOW SEASON", color = { 190, 110, 255 }, source = "season" },
	{ id = "season_4", kind = "title", name = "S4 · PRESSURE SEASON", text = "S4 · PRESSURE SEASON", color = { 255, 88, 120 }, source = "season" },

	{ id = "trail_season_1", kind = "trail", name = "S1 Trail", color = { 255, 205, 90 }, source = "season" },
	{ id = "trail_season_2", kind = "trail", name = "S2 Trail", color = { 150, 220, 255 }, source = "season" },
	{ id = "trail_season_3", kind = "trail", name = "S3 Trail", color = { 190, 110, 255 }, source = "season" },
	{ id = "trail_season_4", kind = "trail", name = "S4 Trail", color = { 255, 88, 120 }, source = "season" },
}

Cosmetics.ById = {}
for _, cosmetic in ipairs(Cosmetics.List) do
	Cosmetics.ById[cosmetic.id] = cosmetic
end

Cosmetics.Defaults = { lamp = "lamp_white", trail = "trail_none", title = "title_none" }

function Cosmetics.ofKind(kind: string)
	local out = {}
	for _, cosmetic in ipairs(Cosmetics.List) do
		if cosmetic.kind == kind then
			table.insert(out, cosmetic)
		end
	end
	return out
end

function Cosmetics.color(id: string?): Color3
	local cosmetic = id and Cosmetics.ById[id]
	if not cosmetic or not cosmetic.color then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(cosmetic.color[1], cosmetic.color[2], cosmetic.color[3])
end

return Cosmetics
