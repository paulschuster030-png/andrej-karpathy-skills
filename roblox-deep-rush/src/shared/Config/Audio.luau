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

	**The single biggest upgrade you can make to how this game feels** is
	uploading three ambience loops and pasting them below. Audio ▸ Create in
	the Creator Dashboard; the Roblox library also has thousands of free
	loops you can take the ids from.
]]

local Audio = {}

Audio.Custom = {
	ambienceSurface = "", -- open air, wind, distant machinery
	ambienceShallow = "", -- dripping water, close rock
	ambienceDeep = "", -- low drone, pressure
	ambienceAbyss = "", -- something wrong
	music = "", -- optional loop; left empty on purpose, see below
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
