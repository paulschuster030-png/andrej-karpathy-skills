--!nonstrict
--[[
	Leaderboards.luau — global boards, rendered on a wall at the surface.

	OrderedDataStore is the only Roblox store that can answer "top 10", and
	it only holds integers, so each board is its own store. Writes are
	throttled to record-beating events; unconditional writes on every bank
	would blow the DataStore budget on a busy server.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Ranks = require(Shared.Config.Ranks)

local Data = require(script.Parent.Data)

local Leaderboards = {}

-- Same story as Data: GetOrderedDataStore throws in Studio without API
-- access, at module scope, and takes the whole service down with it. Without
-- them the global boards are empty; the live server board does not use them
-- at all and works either way.
local function openBoard(name: string)
	if not Config.UseDataStores then
		return nil
	end
	local ok, opened = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	return ok and opened or nil
end

local depthStore = openBoard("DeepRushDepth_v1")
local cashStore = openBoard("DeepRushBanked_v1")

local cache = { depth = {}, banked = {}, fetchedAt = 0 }
local lastWrite: { [number]: { depth: number, banked: number } } = {}

--- What each player has banked since joining THIS server.
---
--- The global boards are all-time and they move once a week; on a Tuesday
--- evening nobody on the server is on them and nobody ever will be. This one
--- resets when the server does, so the person standing next to you is on it,
--- and beating them is a thing you can do in the next twenty minutes. That is
--- the board players actually race.
local live: { [number]: number } = {}

local function nameFor(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	if player then
		return player.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return ok and name or ("User " .. userId)
end

local function readBoard(store)
	if not store then
		return {}
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok then
		return {}
	end

	local rows = {}
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(rows, {
			rank = rank,
			userId = tonumber(entry.key) or 0,
			name = nameFor(tonumber(entry.key) or 0),
			value = entry.value,
		})
	end
	return rows
end

local function refresh()
	cache.depth = readBoard(depthStore)
	cache.banked = readBoard(cashStore)
	cache.fetchedAt = os.time()
end

--- Called after a successful deposit. Only writes when the player actually
--- beat their own recorded value.
function Leaderboards.submit(player: Player, payout: number)
	live[player.UserId] = (live[player.UserId] or 0) + math.max(payout or 0, 0)

	local profile = Data.get(player)
	-- Guarded on the stores themselves, not on the config flag: the flag can
	-- be true while the stores never opened.
	if not profile or not depthStore or not cashStore then
		return
	end

	local previous = lastWrite[player.UserId] or { depth = 0, banked = 0 }
	local depth = math.floor(profile.stats.bestDepth)
	local banked = math.floor(math.min(profile.stats.bankedTotal, 9e15))

	if depth > previous.depth then
		previous.depth = depth
		pcall(function()
			depthStore:SetAsync(tostring(player.UserId), depth)
		end)
	end

	-- Banked total only re-writes once it has moved by a visible margin.
	if banked > previous.banked * 1.05 + 1000 then
		previous.banked = banked
		pcall(function()
			cashStore:SetAsync(tostring(player.UserId), banked)
		end)
	end

	lastWrite[player.UserId] = previous
end

local function buildWall(name: string, cframe: CFrame, heading: string, headingColor: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = name
	anchor.Size = Vector3.new(40, 24, 2)
	anchor.CFrame = cframe
	anchor.Anchored = true
	anchor.Color = Color3.fromRGB(24, 24, 30)
	anchor.Material = Enum.Material.Metal
	anchor.Parent = workspace:FindFirstChild("DeepRushWorld") or workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(800, 480)
	gui.LightInfluence = 0
	gui.Parent = anchor

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 70)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = heading
	title.TextColor3 = headingColor
	title.TextScaled = true
	title.Parent = frame

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.Position = UDim2.new(0, 20, 0, 80)
	list.Size = UDim2.new(1, -40, 1, -100)
	list.BackgroundTransparency = 1
	list.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	return list
end

local function liveRows()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Data.get(player)
		table.insert(rows, {
			userId = player.UserId,
			name = player.DisplayName,
			value = live[player.UserId] or 0,
			rank = 0,
			badge = Ranks.label(profile and profile.stats.bankedTotal or 0),
			rankId = Ranks.at(profile and profile.stats.bankedTotal or 0).id,
		})
	end
	table.sort(rows, function(a, b)
		if a.value == b.value then
			return a.name < b.name
		end
		return a.value > b.value
	end)
	for index, row in ipairs(rows) do
		row.rank = index
	end
	return rows
end

local function renderLive(list: Frame)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	for index, row in ipairs(liveRows()) do
		if index > 10 then
			break
		end
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 34)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = string.format("%d.  %s %s  —  %s", row.rank, row.badge, row.name, Format.short(row.value))
		label.TextColor3 = index == 1 and Color3.fromRGB(255, 210, 90) or Ranks.color(row.rankId)
		label.TextScaled = true
		label.Parent = list
	end
end

local function renderBoard(list: Frame)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if #cache.depth == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.GothamMedium
		empty.Text = "No records yet. Be the first."
		empty.TextColor3 = Color3.fromRGB(140, 140, 160)
		empty.TextScaled = true
		empty.Parent = list
		return
	end

	for _, row in ipairs(cache.depth) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 34)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = string.format("%d.  %s  —  %s", row.rank, row.name, Format.depth(row.value))
		label.TextColor3 = row.rank == 1 and Color3.fromRGB(255, 210, 90) or Color3.fromRGB(225, 225, 235)
		label.TextScaled = true
		label.Parent = list
	end
end

--- The in-game player list. Players read this constantly and it costs us
--- almost nothing, so both headline numbers go there.
local function setupLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Value = "0"
	cash.Parent = stats

	local depth = Instance.new("StringValue")
	depth.Name = "Depth"
	depth.Value = "0m"
	depth.Parent = stats

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Value = Ranks.label(0)
	rank.Parent = stats

	stats.Parent = player

	task.spawn(function()
		while player.Parent do
			local profile = Data.get(player)
			local session = Data.session(player)
			if profile then
				cash.Value = Format.short(profile.cash)
				depth.Value = Format.depth(session and session.depth or 0)
				rank.Value = Ranks.label(profile.stats.bankedTotal or 0)
			end
			task.wait(3)
		end
	end)
end

function Leaderboards.start()
	for _, player in ipairs(Players:GetPlayers()) do
		setupLeaderstats(player)
	end
	Players.PlayerAdded:Connect(setupLeaderstats)

	Net.handle("GetBoards", function()
		return { depth = cache.depth, banked = cache.banked, server = liveRows() }
	end)

	task.spawn(function()
		-- The world builds first; give it a beat before parenting to it.
		task.wait(2)
		local global = buildWall(
			"LeaderboardWall",
			CFrame.new(-52, 12, 76) * CFrame.Angles(0, math.rad(-35), 0),
			"DEEPEST DIVES",
			Color3.fromRGB(120, 220, 255)
		)
		local server = buildWall(
			"LiveBoardWall",
			CFrame.new(52, 12, 76) * CFrame.Angles(0, math.rad(35), 0),
			"THIS SERVER · TODAY",
			Color3.fromRGB(255, 205, 90)
		)

		-- The live board refreshes far faster than the global one, and costs
		-- nothing to: it reads players who are already in memory, while the
		-- global board is a DataStore call on a budget.
		local sinceGlobal = math.huge
		while true do
			if sinceGlobal >= Config.LeaderboardRefresh then
				refresh()
				renderBoard(global)
				sinceGlobal = 0
			end
			renderLive(server)
			task.wait(3)
			sinceGlobal += 3
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWrite[player.UserId] = nil
		live[player.UserId] = nil
	end)
end

return Leaderboards
