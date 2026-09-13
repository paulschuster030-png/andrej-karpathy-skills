--!nonstrict
--[[
	Bootstrap.server.luau — start order is the dependency order.

	Data goes first because it publishes the remote tree and owns profiles;
	everything else assumes a profile can exist. World goes early because
	Surface and Steal need the vault and the crate container to be there.
]]

local SERVICES = {
	"Data",
	"World",
	"Crew",
	"Economy",
	"Cargo",
	"Cosmetics",
	"Tools",
	"Contracts",
	"Quests",
	"Rift",
	"Season",
	"Mining",
	"Surface",
	"Steal",
	"Hazards",
	"Upgrades",
	"Rebirth",
	"Drones",
	"Rewards",
	"Leaderboards",
	"Monetization",
	"Ads",
	"AntiCheat",
}

local Players = game:GetService("Players")

-- Nobody arrives before there is somewhere to arrive.
--
-- This world is generated at runtime, and Data.start touches DataStores,
-- which yields. In Studio the local player joins at the same instant the
-- server boots, so without this the character spawns into an empty Workspace
-- and falls — and since the shaft needs FallenPartsDestroyHeight down at
-- -9,400, it falls for about ten seconds before anything resets it. The
-- symptom is a player in the sky with nothing around them, which is
-- indistinguishable from a broken download.
Players.CharacterAutoLoads = false

local started = os.clock()

for _, name in ipairs(SERVICES) do
	local module = script.Parent:FindFirstChild(name)
	if not module then
		warn(`DeepRush: service "{name}" is missing`)
		continue
	end

	local ok, service = pcall(require, module)
	if not ok then
		warn(`DeepRush: service "{name}" failed to load: {service}`)
		continue
	end

	if type(service) == "table" and type(service.start) == "function" then
		local startOk, err = pcall(service.start)
		if not startOk then
			warn(`DeepRush: service "{name}" failed to start: {err}`)
		end
	end
end

-- The world exists now, so people may enter it.
Players.CharacterAutoLoads = true
for _, player in ipairs(Players:GetPlayers()) do
	if not player.Character then
		player:LoadCharacter()
	end
end

print(string.format("[DEEP RUSH] %d services up in %.2fs", #SERVICES, os.clock() - started))

-- The audio notice. Roblox will only play sound that lives on its own
-- servers, so the nine files in `audio/` have to be uploaded from your own
-- account — no place file can carry them and nobody can upload them for you.
-- Until then the game runs on the built-in client sounds, which work but are
-- much thinner. This says so once, plainly, instead of leaving you to wonder
-- why it sounds flat.
local missingAudio = require(game:GetService("ReplicatedStorage").Shared.Config.Audio).missing()
if #missingAudio > 0 then
	local lines = {
		`[DEEP RUSH] audio: {#missingAudio} of 9 sounds are still on the built-in fallback.`,
		"  Upload these in Studio (Home > Asset Manager > Audio > right-click > Add Audio),",
		"  then paste each id into Shared/Config/Audio -> Audio.Custom:",
	}
	for _, entry in ipairs(missingAudio) do
		table.insert(lines, `    {entry.slot} = "" -- {entry.file}`)
	end
	print(table.concat(lines, "\n"))
end
