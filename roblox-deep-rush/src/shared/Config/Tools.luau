--!nonstrict
--[[
	Tools.luau — the pickaxe in your hand.

	The game shipped without one. Players held nothing, swung nothing, and the
	only sign that mining was happening was a progress bar. In a game whose
	entire verb is "mine", that is the first thing anyone notices missing.

	The pickaxe also does a second job: it is the only upgrade in the game you
	can SEE. Drill Power is otherwise an invisible number that makes a bar
	fill faster. Now it changes the thing in your hand, and other players can
	tell how far along you are by looking at you.
]]

local Tools = {}

--- Picked by Drill Power level. `from` is inclusive.
Tools.Tiers = {
	{
		from = 0,
		name = "Rusted Pick",
		haft = { 96, 68, 38 },
		head = { 138, 108, 78 },
		headSize = { 3.4, 0.5, 0.5 },
		neon = false,
	},
	{
		from = 5,
		name = "Steel Pick",
		haft = { 104, 74, 42 },
		head = { 188, 194, 204 },
		headSize = { 3.9, 0.6, 0.6 },
		neon = false,
	},
	{
		from = 15,
		name = "Reinforced Pick",
		haft = { 72, 76, 86 },
		head = { 150, 172, 198 },
		headSize = { 4.4, 0.7, 0.7 },
		neon = false,
	},
	{
		from = 26,
		name = "Gilded Pick",
		haft = { 78, 60, 34 },
		head = { 255, 205, 90 },
		headSize = { 4.8, 0.8, 0.8 },
		neon = false,
	},
	{
		from = 38,
		name = "Abyssal Drill",
		haft = { 34, 30, 44 },
		head = { 0, 255, 214 },
		headSize = { 5.2, 0.9, 0.9 },
		neon = true,
	},
}

function Tools.tierFor(drillLevel: number)
	local chosen = Tools.Tiers[1]
	for _, tier in ipairs(Tools.Tiers) do
		if (drillLevel or 0) >= tier.from then
			chosen = tier
		end
	end
	return chosen
end

--- Where the pickaxe sits relative to the hand, and how far it swings.
Tools.Grip = { 0, -1.1, -0.4 }
Tools.SwingAngle = 105 -- degrees the head travels on a chop
Tools.ReturnFraction = 0.45 -- share of the swing spent coming back

return Tools
