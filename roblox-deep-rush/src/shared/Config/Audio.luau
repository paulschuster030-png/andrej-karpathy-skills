--!nonstrict
--[[
	Audio.luau — every sound in one place.

	Two tiers, and the split matters:

	  BUILTIN  `rbxasset://` sounds that ship inside the Roblox client. They
	           always work, in every place, with no upload and no asset id.
	           The game is fully scored with these, so it is never silent.

	  CUSTOM   your own uploaded asset ids. Empty by default. Anything you
	           fill in here overrides the built-in for that slot.

	Why no ids are pre-filled: a made-up catalogue id either fails to load or
	plays something unrelated, and there is no way to tell which without
	testing it in a live place. Guessing them would have quietly shipped you
	broken audio that looks configured. The built-ins are worse-sounding and
	honest.

	**The files are already made.** `audio/` in this repo contains ten
	purpose-built pieces — four ambience loops, three positional loops, two
	one-shots and the score — every loop seamless by construction (see tools/make-audio.py).
	Upload them once, paste the ids below, done. `audio/README.md` walks
	through it.
]]

local Audio = {}

Audio.Custom = {
	-- Paste the asset id (just the number) after uploading audio/*.ogg.
	ambienceSurface = "105633144930885", -- audio/ambience-surface.ogg
	ambienceShallow = "99103211447000", -- audio/ambience-shallow.ogg
	ambienceDeep = "80872828094349", -- audio/ambience-deep.ogg
	ambienceAbyss = "78013053184850", -- audio/ambience-abyss.ogg

	-- Positional. These attach to the objects themselves, so you hear a gas
	-- pocket before you can see it and the volume tells you how close it is.
	zoneGas = "", -- audio/zone-gas.ogg — gas, frost, the Hollow
	zoneVent = "", -- audio/zone-vent.ogg — vents, pressure, collapse
	liftMotor = "", -- audio/lift-motor.ogg

	-- One-shots.
	pickHit = "", -- audio/pick-hit.ogg
	rareReveal = "86205815247689", -- audio/rare-reveal.ogg

	music = "115263008266354", -- audio/music.ogg
}

--- The nine files in `audio/`, in upload order. This is what the boot notice
--- checks: fill every slot here and the game runs entirely on your own audio.
--- `music` is not in the list because it is meant to stay empty (see below).
Audio.Uploads = {
	{ slot = "ambienceSurface", file = "audio/ambience-surface.ogg" },
	{ slot = "ambienceShallow", file = "audio/ambience-shallow.ogg" },
	{ slot = "ambienceDeep", file = "audio/ambience-deep.ogg" },
	{ slot = "ambienceAbyss", file = "audio/ambience-abyss.ogg" },
	{ slot = "zoneGas", file = "audio/zone-gas.ogg" },
	{ slot = "zoneVent", file = "audio/zone-vent.ogg" },
	{ slot = "liftMotor", file = "audio/lift-motor.ogg" },
	{ slot = "pickHit", file = "audio/pick-hit.ogg" },
	{ slot = "rareReveal", file = "audio/rare-reveal.ogg" },
	{ slot = "music", file = "audio/music.ogg" },
}

--- Slots still waiting on an asset id, in upload order.
function Audio.missing()
	local out = {}
	for _, entry in ipairs(Audio.Uploads) do
		local id = Audio.Custom[entry.slot]
		if not id or id == "" then
			table.insert(out, entry)
		end
	end
	return out
end

--- Which positional loop each hazard kind uses. Persistent kinds get the
--- hiss, pulsing kinds get the rumble.
Audio.ZoneLoops = {
	gas = "zoneGas",
	freeze = "zoneGas",
	hollow = "zoneGas",
	cavein = "zoneVent",
	heat = "zoneVent",
	pressure = "zoneVent",
	collapse = "zoneVent",
}

--- Built-ins. Pitched and looped rather than used as one-shots, which is how
--- a handful of short clips becomes an ambience bed.
---
--- Not every path under rbxasset://sounds/ is one a game may play. Some are
--- there for the engine and answer a request with "Asset is not approved for
--- the requester", which is a warning rather than an error — so the sound is
--- simply silent and the only sign is a line in the Output nobody reads.
--- swoosh.wav shipped that way: the tension layer never made a sound in a
--- real place and nothing here could tell.
---
--- Every path below has been seen loading in a live session. Adding one means
--- testing it in Studio first; tools/api-check.py holds the list.
Audio.Builtin = {
	rumble = "rbxasset://sounds/bass.wav",
	wind = "rbxasset://sounds/bass.wav",
	hit = "rbxasset://sounds/snap.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/clickfast.wav",
}

--- The ambience bed, layered by depth. Each layer fades in over its own band,
--- so descending is a continuous change in what you are hearing rather than
--- four abrupt swaps.
Audio.Ambience = {
	{ id = "surface", custom = "ambienceSurface", from = 0, to = 120, volume = 0.30, pitch = 1.0 },
	{ id = "shallow", custom = "ambienceShallow", from = 60, to = 700, volume = 0.38, pitch = 0.62 },
	{ id = "deep", custom = "ambienceDeep", from = 500, to = 1600, volume = 0.46, pitch = 0.34 },
	{ id = "abyss", custom = "ambienceAbyss", from = 1300, to = 3000, volume = 0.55, pitch = 0.2 },
}

--- The score.
---
--- There was no music here for a long time, on the grounds that a loop heard
--- for the fortieth time is worse than none. That was half right: the answer
--- is not "no music", it is "no melody and no hurry". audio/music.ogg is
--- three and a half minutes of open fifths with long gaps, in the same key as
--- everything else, and it gets out of the way on its own:
---
---   · it fades as you descend, so the abyss keeps its silence
---   · it swells for a rift and a rank up, which are the moments worth scoring
---   · a player can switch it off, and the game remembers
Audio.MusicVolume = 0.16
Audio.MusicDeepFade = 0.35 -- share of the volume left at maximum depth
Audio.MusicEventVolume = 0.30 -- during a rift or a rank up
Audio.MusicEventSeconds = 12

Audio.MaxDepthForRumble = 3000

function Audio.source(slot: string): string
	local custom = Audio.Custom[slot]
	if custom and custom ~= "" then
		if tonumber(custom) then
			return "rbxassetid://" .. custom
		end
		return custom
	end
	return ""
end

return Audio
