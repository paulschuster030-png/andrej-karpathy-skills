--!nonstrict
--[[
	Crew.luau — the co-play layer.

	Why this exists: Roblox's Recommended For You algorithm names "7 day
	intentional co-play days per user" as one of six ranking signals. Before
	this module, DEEP RUSH scored exactly zero on it — nothing in the game was
	better with another person in it.

	Two constraints shaped the design:

	  NO TEXT. Since the January 2026 age-check rollout, a large share of
	  players cannot freely chat with each other. So the entire coordination
	  vocabulary is four pings and a proximity bonus. Nobody has to type
	  anything, and nothing breaks when two crewmates are in age brackets that
	  cannot talk.

	  NO LOBBY. The bonus is paid for standing near each other in the shaft,
	  not for being on a roster. A crew you never dig with is worth nothing,
	  which keeps the signal honest rather than farmable.

	This module deliberately depends on almost nothing (Data, World, Net,
	Feedback) because Economy asks it for the bonus, and Economy is required
	by half the server.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CrewConfig = require(Shared.Config.Crew)
local Net = require(Shared.Net)

local Data = require(script.Parent.Data)
local Feedback = require(script.Parent.Feedback)
local World = require(script.Parent.World)

local Crew = {}

local crews: { [string]: any } = {} -- id -> { id, members: {Player} }
local memberOf: { [Player]: string } = {}
local beacons: { [Player]: any } = {} -- owner -> { part, expiresAt }
local lastPing: { [Player]: number } = {}

local nextCrewId = 0

local function rootOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- Membership --------------------------------------------------------------

function Crew.of(player: Player)
	local id = memberOf[player]
	return id and crews[id] or nil
end

function Crew.size(player: Player): number
	local crew = Crew.of(player)
	return crew and #crew.members or 1
end

function Crew.isMate(a: Player, b: Player): boolean
	local crew = Crew.of(a)
	return crew ~= nil and crew == Crew.of(b)
end

--- Crew members other than `player` currently inside the bond radius. This is
--- the number the bonus is actually paid on — being on the roster from
--- across the map earns nothing.
function Crew.matesNear(player: Player): number
	local crew = Crew.of(player)
	local root = rootOf(player)
	if not crew or not root then
		return 0
	end

	local count = 0
	for _, member in ipairs(crew.members) do
		if member ~= player then
			local memberRoot = rootOf(member)
			if memberRoot and (memberRoot.Position - root.Position).Magnitude <= CrewConfig.BondRadius then
				count += 1
			end
		end
	end
	return count
end

--- Asked for by Economy on every luck and cash calculation.
function Crew.bonus(player: Player)
	local near = Crew.matesNear(player)
	if near <= 0 then
		return { cash = 0, luck = 0, near = 0 }
	end
	return {
		cash = near * CrewConfig.CashPerMember,
		luck = near * CrewConfig.LuckPerMember,
		near = near,
	}
end

local function syncCrew(crew)
	local roster = {}
	for _, member in ipairs(crew.members) do
		local session = Data.session(member)
		table.insert(roster, {
			userId = member.UserId,
			name = member.DisplayName,
			depth = session and math.floor(session.depth or 0) or 0,
		})
	end

	for _, member in ipairs(crew.members) do
		Net.to(member, "Crew", { members = roster, bonusNear = Crew.matesNear(member) })
	end
end

local function syncSolo(player: Player)
	Net.to(player, "Crew", { members = {}, bonusNear = 0 })
end

function Crew.leave(player: Player, quiet: boolean?)
	local crew = Crew.of(player)
	if not crew then
		return
	end

	memberOf[player] = nil
	local index = table.find(crew.members, player)
	if index then
		table.remove(crew.members, index)
	end

	if not quiet then
		syncSolo(player)
		for _, member in ipairs(crew.members) do
			Feedback.toast(member, {
				title = "CREW LEFT",
				body = `{player.DisplayName} surfaced.`,
				kind = "quest",
			})
		end
	end

	if #crew.members <= 1 then
		-- A crew of one is just a player. Dissolve it so the bonus and the
		-- UI both read honestly.
		for _, member in ipairs(crew.members) do
			memberOf[member] = nil
			syncSolo(member)
		end
		crews[crew.id] = nil
	else
		syncCrew(crew)
	end
end

local function joinCrew(player: Player, owner: Player)
	if player == owner then
		return
	end

	local crew = Crew.of(owner)
	if not crew then
		nextCrewId += 1
		crew = { id = "crew" .. nextCrewId, members = { owner } }
		crews[crew.id] = crew
		memberOf[owner] = crew.id
	end

	if #crew.members >= CrewConfig.MaxSize then
		Feedback.toast(player, { title = "CREW FULL", body = `Crews cap at {CrewConfig.MaxSize}.`, kind = "error" })
		return
	end

	Crew.leave(player, true)
	table.insert(crew.members, player)
	memberOf[player] = crew.id

	for _, member in ipairs(crew.members) do
		Feedback.toast(member, {
			title = "CREW " .. #crew.members .. "/" .. CrewConfig.MaxSize,
			body = `{player.DisplayName} joined. Stay close for the bonus.`,
			kind = "quest",
		})
	end
	Feedback.effect(player, "crewJoin", {})
	syncCrew(crew)
end

-- Beacons -----------------------------------------------------------------

local function clearBeacon(owner: Player)
	local beacon = beacons[owner]
	if beacon then
		if beacon.part.Parent then
			beacon.part:Destroy()
		end
		beacons[owner] = nil
	end
end

function Crew.dropBeacon(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end

	clearBeacon(player)

	local part = Instance.new("Part")
	part.Name = "CrewBeacon"
	part.Size = Vector3.new(3, 14, 3)
	part.CFrame = CFrame.new(root.Position + Vector3.new(0, 5, 0))
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(110, 230, 255)
	part.Transparency = 0.25
	part:SetAttribute("CrewBeacon", player.UserId)
	part.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 40
	light.Brightness = 3
	light.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 4)
	billboard.StudsOffset = Vector3.new(0, 9, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 300
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = `🤝 JOIN {string.upper(player.DisplayName)}`
	label.TextColor3 = Color3.fromRGB(150, 240, 255)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard

	beacons[player] = { part = part, expiresAt = os.time() + CrewConfig.BeaconLifetime }

	Feedback.toast(player, {
		title = "BEACON DROPPED",
		body = `Anyone within {CrewConfig.JoinRadius} studs can join for {CrewConfig.BeaconLifetime}s.`,
		kind = "quest",
	})
end

--- Join the nearest live beacon. No menus, no invites to accept: you walk to
--- the light and press one button.
function Crew.joinNearest(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end

	local best, bestDistance = nil, CrewConfig.JoinRadius
	for owner, beacon in pairs(beacons) do
		if owner ~= player and beacon.part.Parent then
			local distance = (beacon.part.Position - root.Position).Magnitude
			if distance <= bestDistance then
				best, bestDistance = owner, distance
			end
		end
	end

	if not best then
		Feedback.toast(player, {
			title = "NO BEACON NEARBY",
			body = "Drop your own so others can find you.",
			kind = "error",
		})
		return
	end

	joinCrew(player, best)
end

-- Pings -------------------------------------------------------------------

--- The whole coordination vocabulary. The POSITION comes from the server's
--- view of the character, never from the client, so a ping cannot be used to
--- draw arbitrary marks anywhere in the world.
function Crew.ping(player: Player, kind: string)
	local valid = false
	for _, pingType in ipairs(CrewConfig.PingTypes) do
		if pingType.id == kind then
			valid = true
			break
		end
	end
	if not valid then
		return
	end

	local now = os.clock()
	if now - (lastPing[player] or 0) < CrewConfig.PingCooldown then
		return
	end
	lastPing[player] = now

	local root = rootOf(player)
	if not root then
		return
	end

	local payload = {
		kind = kind,
		position = root.Position,
		from = player.DisplayName,
		lifetime = CrewConfig.PingLifetime,
	}

	local crew = Crew.of(player)
	if crew then
		for _, member in ipairs(crew.members) do
			Net.to(member, "Pings", payload)
		end
		return
	end

	-- Solo players still get to signal: anyone close by sees it. This is how
	-- a crew usually starts in the first place.
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = rootOf(other)
		if otherRoot and (otherRoot.Position - root.Position).Magnitude <= 200 then
			Net.to(other, "Pings", payload)
		end
	end
end

-- Lifecycle ---------------------------------------------------------------

function Crew.start()
	Net.on("CrewBeacon", function(player)
		Crew.dropBeacon(player)
	end)

	Net.on("CrewJoin", function(player)
		Crew.joinNearest(player)
	end)

	Net.on("CrewLeave", function(player)
		Crew.leave(player)
	end)

	Net.on("Ping", function(player, kind)
		if type(kind) == "string" then
			Crew.ping(player, kind)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		Crew.leave(player, true)
		clearBeacon(player)
		lastPing[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(2)

			for owner, beacon in pairs(beacons) do
				if os.time() >= beacon.expiresAt or not beacon.part.Parent then
					clearBeacon(owner)
				end
			end

			for _, crew in pairs(crews) do
				syncCrew(crew)
			end
		end
	end)
end

return Crew
