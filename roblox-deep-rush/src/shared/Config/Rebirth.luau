--!nonstrict
--[[
	Rebirth.luau — the reset that is a reward.

	Rebirth wipes cash and upgrades, keeps identity (codex, drones, records,
	cosmetics), and hands back permanent multipliers plus a deeper layer to
	survive in. The requirement is a two-key lock — cash AND depth — so you
	cannot rebirth purely by farming the safe layers.
]]

local Rebirth = {}

Rebirth.MaxTracked = 25

Rebirth.Titles = {
	[0] = "Surface Rat",
	[1] = "Shaft Hand",
	[2] = "Deep Digger",
	[3] = "Vein Hunter",
	[5] = "Hollow Walker",
	[8] = "Abyss Diver",
	[12] = "Pressure Saint",
	[16] = "Voidwright",
	[20] = "Singularity Born",
	[25] = "The Bottom",
}

--- Cash + depth needed to perform rebirth number `n + 1`.
---
--- The cash figure is anchored to the UPGRADE ladder, not picked by feel: a
--- mid drill/backpack costs six figures, so a five-figure rebirth would fire
--- before a player had bought anything worth keeping and the reset would read
--- as a punishment. At 800k the first rebirth lands after a real session, and
--- tools/balance-spec.luau fails if that drifts outside 15-90 minutes.
function Rebirth.requirement(n: number)
	return {
		cash = math.floor(800000 * (3.15 ^ n)),
		depth = math.min(150 + n * 130, 2400),
	}
end

--- Permanent, stacking bonuses granted by having `n` rebirths.
function Rebirth.bonuses(n: number)
	return {
		cashMultiplier = 1 + n * 0.25,
		luck = n * 0.18,
		capacity = n * 3,
		oxygen = n * 8,
	}
end

--- The highest title earned at `n` rebirths.
function Rebirth.title(n: number): string
	local best, bestAt = "Surface Rat", -1
	for at, title in pairs(Rebirth.Titles) do
		if n >= at and at > bestAt then
			best, bestAt = title, at
		end
	end
	return best
end

return Rebirth
