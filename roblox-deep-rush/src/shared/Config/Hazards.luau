--!nonstrict
--[[
	Hazards.luau — danger you can see coming.

	The first version rolled a die every second and, on a hit, told the player
	"the ceiling is cracking" one second before hurting them. It was fair on
	paper — there was a telegraph — but it felt arbitrary, because the danger
	had no PLACE. You could not look at the room and know where not to stand.

	Now every hazard is an object in the world. A gas pocket is a green cloud
	on a shelf. A magma vent is a glowing crack that flares before it fires.
	You route around them, or you time them, and if you get hit it is because
	you misread something visible rather than because a number came up.

	Two behaviours cover all of it:

	  PERSISTENT  hurts continuously while you are inside. Gas, ice, the
	              Hollow. The counterplay is not being there.
	  PULSING     cycles telegraph -> burst -> rest, forever, on a visible
	              rhythm. Vents, pressure, collapse. The counterplay is timing,
	              which means a hazard can also be a gate you learn to pass.
]]

local Hazards = {}

Hazards.Kinds = {
	gas = {
		mode = "persistent",
		name = "GAS POCKET",
		icon = "☣",
		dps = 7,
		radius = 15,
		height = 13,
		color = { 120, 225, 95 },
		transparency = 0.72,
		particleRate = 26,
		particleSpeed = 2.5,
		hint = "Green means hold your breath and go around.",
	},

	freeze = {
		mode = "persistent",
		name = "FROST FIELD",
		icon = "❄",
		dps = 9,
		radius = 16,
		height = 10,
		color = { 165, 225, 255 },
		transparency = 0.66,
		particleRate = 20,
		particleSpeed = 1.2,
		slow = 0.45, -- multiplies walkspeed while you stand in it
		hint = "It slows you down before it hurts you.",
	},

	hollow = {
		mode = "persistent",
		name = "THE HOLLOW",
		icon = "◉",
		dps = 13,
		radius = 19,
		height = 22,
		color = { 120, 60, 190 },
		transparency = 0.6,
		particleRate = 34,
		particleSpeed = 3.5,
		hint = "Whatever this is, it does not move. You do.",
	},

	cavein = {
		mode = "pulsing",
		name = "LOOSE CEILING",
		icon = "⚠",
		burst = 26,
		radius = 14,
		height = 16,
		telegraph = 1.5,
		active = 0.8,
		rest = 4.5,
		color = { 190, 150, 110 },
		transparency = 0.85,
		particleRate = 16,
		particleSpeed = 6,
		debris = true, -- drops real rocks during the burst
		hint = "Dust falls first. That is your cue.",
	},

	heat = {
		mode = "pulsing",
		name = "MAGMA VENT",
		icon = "🔥",
		burst = 34,
		radius = 12,
		height = 26,
		telegraph = 1.6,
		active = 1.1,
		rest = 4,
		color = { 255, 120, 40 },
		transparency = 0.8,
		particleRate = 30,
		particleSpeed = 14,
		hint = "It glows before it fires. Count it out and walk through.",
	},

	pressure = {
		mode = "pulsing",
		name = "PRESSURE WELL",
		icon = "◈",
		burst = 42,
		radius = 17,
		height = 20,
		telegraph = 1.3,
		active = 1.0,
		rest = 3.2,
		color = { 90, 120, 255 },
		transparency = 0.78,
		particleRate = 22,
		particleSpeed = 8,
		hint = "The air folds inward, then it snaps.",
	},

	collapse = {
		mode = "pulsing",
		name = "COLLAPSE ZONE",
		icon = "☠",
		burst = 58,
		radius = 20,
		height = 26,
		telegraph = 1.1,
		active = 1.2,
		rest = 2.8,
		color = { 200, 60, 90 },
		transparency = 0.75,
		particleRate = 40,
		particleSpeed = 10,
		debris = true,
		hint = "Down here the rock does not warn you twice.",
	},
}

--- How many zones a chunk of this layer gets. Shallow layers stay clean so a
--- new player learns the core loop before learning to dodge anything.
function Hazards.densityFor(layer): number
	if not layer.hazard then
		return 0
	end
	if layer.minDepth < 100 then
		return 1
	end
	if layer.minDepth < 700 then
		return 2
	end
	return 3
end

function Hazards.kindOf(layer)
	local hazard = layer.hazard
	return hazard and Hazards.Kinds[hazard.kind] or nil
end

function Hazards.color(kindId: string): Color3
	local kind = Hazards.Kinds[kindId]
	if not kind then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(kind.color[1], kind.color[2], kind.color[3])
end

return Hazards
