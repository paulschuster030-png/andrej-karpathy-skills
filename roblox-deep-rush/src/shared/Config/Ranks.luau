--!nonstrict
--[[
	Ranks.luau — where you stand, as one word.

	Cash is the number you spend and it goes up and down. Depth resets every
	run. Rebirth wipes upgrades. None of those answer "how good am I", which
	is the question a player asks after their third session and the one that
	makes them open the game on day four.

	Rank answers it from lifetime banked cash: the only figure in the game
	that never goes down, not on death, not on a steal, not on a rebirth.
	Ten steps, roughly 5-6x apart, so every one is a real event — a ladder
	with twenty rungs is a progress bar, and nobody screenshots a progress
	bar.

	It is status only. No rank grants cash, luck, speed or capacity, and that
	is deliberate: the moment a rank pays, falling behind stops being a thing
	you want to fix and starts being a thing you resent.
]]

local Ranks = {}

Ranks.List = {
	{ id = "dust", name = "Dust", icon = "◆", at = 0, color = { 150, 150, 172 } },
	{ id = "copper", name = "Copper", icon = "◆", at = 5000, color = { 214, 120, 60 } },
	{ id = "iron", name = "Iron", icon = "◆", at = 25000, color = { 176, 182, 192 } },
	{ id = "silver", name = "Silver", icon = "◈", at = 120000, color = { 228, 234, 242 } },
	{ id = "gold", name = "Gold", icon = "◈", at = 600000, color = { 255, 199, 54 } },
	{ id = "emerald", name = "Emerald", icon = "❖", at = 3000000, color = { 42, 222, 132 } },
	{ id = "diamond", name = "Diamond", icon = "❖", at = 15000000, color = { 156, 238, 255 } },
	{ id = "obsidian", name = "Obsidian", icon = "✦", at = 80000000, color = { 176, 92, 255 } },
	{ id = "abyssal", name = "Abyssal", icon = "✦", at = 450000000, color = { 0, 255, 214 } },
	{ id = "singularity", name = "Singularity", icon = "✹", at = 3000000000, color = { 255, 255, 255 } },
}

Ranks.Index = {}
for i, rank in ipairs(Ranks.List) do
	Ranks.Index[rank.id] = i
end

--- The rank a lifetime total earns, and its position on the ladder.
function Ranks.at(banked: number)
	local chosen, index = Ranks.List[1], 1
	for i, rank in ipairs(Ranks.List) do
		if (banked or 0) >= rank.at then
			chosen, index = rank, i
		end
	end
	return chosen, index
end

--- The next rank up, or nil at the top.
function Ranks.next(banked: number)
	local _, index = Ranks.at(banked)
	return Ranks.List[index + 1]
end

--- 0..1 through the current rank. Sits at 1 for a player at the top, which
--- is the one place a full bar means "done" rather than "about to tick over".
function Ranks.progress(banked: number): number
	local current, index = Ranks.at(banked)
	local upcoming = Ranks.List[index + 1]
	if not upcoming then
		return 1
	end
	local span = upcoming.at - current.at
	if span <= 0 then
		return 1
	end
	return math.clamp(((banked or 0) - current.at) / span, 0, 1)
end

function Ranks.color(rankId: string)
	local rank = Ranks.List[Ranks.Index[rankId] or 1]
	return Color3.fromRGB(rank.color[1], rank.color[2], rank.color[3])
end

--- "◈ GOLD", the form used on the HUD, the nameplate and the boards.
function Ranks.label(banked: number): string
	local rank = Ranks.at(banked)
	return `{rank.icon} {string.upper(rank.name)}`
end

return Ranks
