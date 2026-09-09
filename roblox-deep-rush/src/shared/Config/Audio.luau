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

	**The files are already made.** `audio/` in this repo contains nine
	purpose-built pieces — four ambience loops, three positional loops and two
	one-shots — every loop seamless by construction (see tools/make-audio.py).
	Upload them once, paste the ids below, done. `audio/README.md` walks
	through it.
]]

local Audio = {}

Audio.Custom = {
	-- Paste the asset id (just the number) after uploading audio/*.ogg.
	ambienceSurface = "", -- audio/ambience-surface.ogg
	ambienceShallow = "", -- audio/ambience-shallow.ogg
	ambienceDeep = "", -- audio/ambience-deep.ogg
	ambienceAbyss = "", -- audio/ambience-abyss.ogg

	-- Positional. These attach to the objects themselves, so you hear a gas
	-- pocket before you can see it and the volume tells you how close it is.
	zoneGas = "", -- audio/zone-gas.ogg — gas, frost, the Hollow
	zoneVent = "", -- audio/zone-vent.ogg — vents, pressure, collapse
	liftMotor = "", -- audio/lift-motor.ogg

	-- One-shots.
	pickHit = "", -- audio/pick-hit.ogg
	rareReveal = "", -- audio/rare-reveal.ogg

	music = "", -- optional loop; left empty on purpose, see below
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
Audio.Builtin = {
	rumble = "rbxasset://sounds/bass.wav",
	wind = "rbxasset://sounds/swoosh.wav",
	hit = "rbxasset://sounds/snap.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/clickfast.wav",
	impact = "rbxasset://sounds/impact_water.mp3",
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

--- Music is deliberately off by default. A loop a player hears for the
--- fortieth time is worse than no loop, and this game already has a rhythm
--- (swing, reveal, rift siren). Add one only if you have a track that earns
--- its place.
Audio.MusicVolume = 0.18

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
