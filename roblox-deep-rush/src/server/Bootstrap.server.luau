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
local failures = {}

--- A sign you cannot miss, standing where the player arrives.
---
--- Every service start is wrapped in pcall so one broken system cannot take
--- the rest down. The cost of that is silence: the failure goes to warn(),
--- and a warn() is invisible unless you have the Output window open and know
--- to look. Somebody opening this place for the first time sees a world that
--- did not build and no reason why.
local function report(lines: { string })
	local board = Instance.new("Part")
	board.Name = "BootReport"
	board.Size = Vector3.new(48, 20, 1)
	board.CFrame = CFrame.new(0, 12, 60)
	board.Anchored = true
	board.CanCollide = false
	board.Color = Color3.fromRGB(18, 14, 16)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = workspace

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(960, 400)
	surface.LightInfluence = 0
	surface.Parent = board

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(18, 14, 16)
	frame.Parent = surface

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = frame

	for index, text in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -24, 0, index == 1 and 64 or 34)
		label.BackgroundTransparency = 1
		label.Font = index == 1 and Enum.Font.GothamBlack or Enum.Font.GothamMedium
		label.Text = text
		label.TextColor3 = index == 1 and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(235, 230, 235)
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = frame
	end
end

for _, name in ipairs(SERVICES) do
	local module = script.Parent:FindFirstChild(name)
	if not module then
		warn(`DeepRush: service "{name}" is missing`)
		table.insert(failures, `{name}: the module is not in ServerScriptService/Server`)
		continue
	end

	local ok, service = pcall(require, module)
	if not ok then
		warn(`DeepRush: service "{name}" failed to load: {service}`)
		table.insert(failures, `{name} failed to load — {service}`)
		continue
	end

	if type(service) == "table" and type(service.start) == "function" then
		local startOk, err = pcall(service.start)
		if not startOk then
			warn(`DeepRush: service "{name}" failed to start: {err}`)
			table.insert(failures, `{name} failed to start — {err}`)
		end
	end

	-- The moment the world exists, people may enter it. Waiting for all
	-- twenty-three would mean one slow or broken service downstream leaves
	-- every player with no character at all — a worse failure than the one
	-- holding them back was meant to prevent.
	if name == "World" then
		Players.CharacterAutoLoads = true
		for _, player in ipairs(Players:GetPlayers()) do
			if not player.Character then
				player:LoadCharacter()
			end
		end
	end
end

-- And a backstop, in case World never got that far: standing on the
-- placeholder pad reading an error beats never spawning at all.
if not Players.CharacterAutoLoads then
	Players.CharacterAutoLoads = true
	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character then
			player:LoadCharacter()
		end
	end
end

if #failures > 0 then
	local lines = { `DEEP RUSH — {#failures} SYSTEM(S) DID NOT START` }
	for _, failure in ipairs(failures) do
		table.insert(lines, "• " .. failure)
	end
	table.insert(lines, "")
	table.insert(lines, "The same text is in View > Output.")
	report(lines)
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
