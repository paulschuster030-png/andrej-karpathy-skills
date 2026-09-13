--!nonstrict
--[[
	Crew.luau (client) — the co-play surface.

	Three things live here, all of them designed to work with the sound off
	and without anyone typing a word:

	  CREW BAR    who is with you, how much bonus you are earning right now,
	              and the one button that is currently relevant (drop a
	              beacon / join the one you are standing next to / leave).
	  PING WHEEL  four fixed signals. This is the entire coordination
	              vocabulary, which is the point: since the January 2026
	              age-check rollout, two players in different age brackets may
	              not be able to chat at all, and a game that needs typing to
	              be played together is a game that quietly excludes them.
	  INVITE      Roblox's own invite prompt, offered at the moments a player
	              actually wants a friend here rather than on a timer.
]]

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CrewConfig = require(Shared.Config.Crew)
local Net = require(Shared.Net)

local Ui = require(script.Parent.Ui)

local Crew = {}

local player = Players.LocalPlayer
local theme = Ui.THEME

local state = { members = {}, bonusNear = 0 }
local widgets = {}
local canInvite = false

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- World markers ------------------------------------------------------------

local function pingColor(kind: string): Color3
	for _, pingType in ipairs(CrewConfig.PingTypes) do
		if pingType.id == kind then
			return Color3.fromRGB(pingType.color[1], pingType.color[2], pingType.color[3])
		end
	end
	return theme.cyan
end

local function pingLabel(kind: string): string
	for _, pingType in ipairs(CrewConfig.PingTypes) do
		if pingType.id == kind then
			return pingType.icon .. " " .. pingType.label
		end
	end
	return "•"
end

--- Drop a marker in the world where a teammate pinged. Always on top, so it
--- is findable through rock — the whole value of a ping is that it works when
--- you cannot see each other.
local function showPing(payload)
	if typeof(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.4, 0.4, 0.4)
	anchor.Position = payload.position + Vector3.new(0, 4, 0)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 3.5)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 1000
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = pingLabel(payload.kind)
	label.TextColor3 = pingColor(payload.kind)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.25
	label.Parent = billboard

	local from = Instance.new("TextLabel")
	from.Size = UDim2.fromScale(1, 0.4)
	from.Position = UDim2.fromScale(0, 1)
	from.BackgroundTransparency = 1
	from.Font = Enum.Font.GothamMedium
	from.Text = payload.from or ""
	from.TextColor3 = theme.muted
	from.TextScaled = true
	from.TextStrokeTransparency = 0.4
	from.Parent = billboard

	TweenService:Create(anchor, TweenInfo.new(payload.lifetime or 8), {
		Position = anchor.Position + Vector3.new(0, 3, 0),
	}):Play()

	task.delay(payload.lifetime or 8, function()
		if anchor.Parent then
			anchor:Destroy()
		end
	end)
end

-- UI -----------------------------------------------------------------------

local function buildBar(parent)
	-- Bottom-left column, above the ping row and the menu grid.
	--
	-- It used to stack up the centre of the screen with the ping row and the
	-- cargo bar, which on anything shorter than a full-height window reached
	-- the middle — where you are looking at the rock you want to hit.
	local bar = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(340, 96),
		position = UDim2.new(0, 16, 1, -316),
		anchor = Vector2.new(0, 1),
		color = theme.panel,
		transparency = 0.15,
	})
	Ui.stroke(bar, theme.panelLight, 2)
	Ui.padding(bar, 8)
	widgets.bar = bar
	widgets.barStroke = bar:FindFirstChildOfClass("UIStroke")

	widgets.title = Ui.text({
		parent = bar,
		size = UDim2.new(1, 0, 0, 20),
		text = "SOLO",
		color = theme.muted,
		align = Enum.TextXAlignment.Left,
		scaled = false,
		textSize = 15,
	})

	widgets.roster = Ui.text({
		parent = bar,
		size = UDim2.new(1, 0, 0, 34),
		position = UDim2.fromOffset(0, 20),
		text = "Dig with someone for +cash and +luck.",
		color = theme.muted,
		align = Enum.TextXAlignment.Left,
		valign = Enum.TextYAlignment.Top,
		scaled = false,
		textSize = 13,
		wrap = true,
	})

	widgets.action = Ui.button({
		parent = bar,
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0, 0, 1, 0),
		anchor = Vector2.new(0, 1),
		text = "🤝 DROP BEACON",
		color = theme.panelLight,
		stroke = theme.cyan,
		scaled = false,
		onClick = function()
			-- One button, three meanings, decided by what is around you.
			if #state.members > 0 then
				Net.fire("CrewLeave")
			elseif widgets.beaconNear then
				Net.fire("CrewJoin")
			else
				Net.fire("CrewBeacon")
			end
		end,
	})
end

local function buildPingWheel(parent)
	-- A horizontal row rather than a wheel: a radial menu needs a drag, and
	-- a drag is exactly what you cannot spare while falling.
	local wheel = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(340, 46),
		position = UDim2.new(0, 16, 1, -262),
		anchor = Vector2.new(0, 1),
		transparency = 1,
		radius = false,
	})

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = wheel

	for _, pingType in ipairs(CrewConfig.PingTypes) do
		Ui.button({
			parent = wheel,
			size = UDim2.fromOffset(54, 46),
			text = pingType.icon,
			color = theme.panel,
			stroke = Color3.fromRGB(pingType.color[1], pingType.color[2], pingType.color[3]),
			onClick = function()
				Net.fire("Ping", pingType.id)
			end,
		})
	end

	widgets.rescue = Ui.button({
		parent = wheel,
		size = UDim2.fromOffset(54, 46),
		text = "🫱",
		color = theme.green,
		textColor = Color3.fromRGB(10, 30, 20),
		visible = false,
		onClick = function()
			Net.fire("Rescue")
		end,
	})

	widgets.invite = Ui.button({
		parent = wheel,
		size = UDim2.fromOffset(54, 46),
		text = "➕",
		color = theme.panelLight,
		stroke = theme.accent,
		visible = false,
		onClick = function()
			local ok, err = pcall(function()
				SocialService:PromptGameInvite(player)
			end)
			if not ok then
				warn("DeepRush: invite prompt failed: " .. tostring(err))
			end
		end,
	})
end

local function render()
	local count = #state.members
	if count > 0 then
		widgets.title.Text = `CREW {count}/{CrewConfig.MaxSize}`
		widgets.title.TextColor3 = state.bonusNear > 0 and theme.green or theme.muted

		local names = {}
		for _, member in ipairs(state.members) do
			if member.userId ~= player.UserId then
				table.insert(names, `{member.name} · {member.depth}m`)
			end
		end
		widgets.roster.Text = table.concat(names, "\n")

		if state.bonusNear > 0 then
			local cash = math.floor(state.bonusNear * CrewConfig.CashPerMember * 100)
			local luck = state.bonusNear * CrewConfig.LuckPerMember
			widgets.title.Text ..= `  ·  +{cash}% cash, +{string.format("%.2f", luck)} luck`
		else
			widgets.title.Text ..= "  ·  too far apart"
		end

		widgets.action.Text = "LEAVE CREW"
		if widgets.barStroke then
			widgets.barStroke.Color = state.bonusNear > 0 and theme.green or theme.panelLight
		end
	elseif widgets.beaconNear then
		widgets.title.Text = "BEACON NEARBY"
		widgets.title.TextColor3 = theme.cyan
		widgets.roster.Text = "Someone is looking for a crew."
		widgets.action.Text = "🤝 JOIN CREW"
		if widgets.barStroke then
			widgets.barStroke.Color = theme.cyan
		end
	else
		widgets.title.Text = "SOLO"
		widgets.title.TextColor3 = theme.muted
		widgets.roster.Text = "Dig within 120 studs of a crewmate for +cash and +luck."
		widgets.action.Text = "🤝 DROP BEACON"
		if widgets.barStroke then
			widgets.barStroke.Color = theme.panelLight
		end
	end

	widgets.invite.Visible = canInvite and count < CrewConfig.MaxSize
end

--- Contextual scan: is there a beacon to join, or a crewmate's crate to hand
--- back? Both change which button is on screen.
local function scan()
	local root = rootPart()
	if not root then
		return
	end

	local beaconNear = false
	local crateNear = false
	local mates = {}
	for _, member in ipairs(state.members) do
		mates[member.userId] = true
	end

	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, CrewConfig.JoinRadius)) do
		local beaconOwner = part:GetAttribute("CrewBeacon")
		if beaconOwner and beaconOwner ~= player.UserId then
			beaconNear = true
		end
	end

	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, CrewConfig.RescueRadius)) do
		local crateOwner = part:GetAttribute("Owner")
		if crateOwner and mates[crateOwner] and crateOwner ~= player.UserId then
			crateNear = true
		end
	end

	local changed = beaconNear ~= widgets.beaconNear
	widgets.beaconNear = beaconNear
	widgets.rescue.Visible = crateNear
	if changed then
		render()
	end
end

function Crew.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeepRushCrew"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = player:WaitForChild("PlayerGui")

	buildBar(gui)
	buildPingWheel(gui)
	render()

	Net.listen("Crew", function(payload)
		if typeof(payload) == "table" then
			state = payload
			render()
		end
	end)

	Net.listen("Pings", showPing)

	-- Asked once: the answer does not change during a session, and the call
	-- yields.
	task.spawn(function()
		local ok, result = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		canInvite = ok and result == true
		render()
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(scan)
			if not ok then
				warn("DeepRush: crew scan failed: " .. tostring(err))
			end
		end
	end)
end

return Crew
