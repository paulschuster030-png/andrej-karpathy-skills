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

local Data = require(script.Parent.Data)

local Leaderboards = {}

local depthStore = Config.UseDataStores and DataStoreService:GetOrderedDataStore("DeepRushDepth_v1") or nil
local cashStore = Config.UseDataStores and DataStoreService:GetOrderedDataStore("DeepRushBanked_v1") or nil

local cache = { depth = {}, banked = {}, fetchedAt = 0 }
local lastWrite: { [number]: { depth: number, banked: number } } = {}

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
function Leaderboards.submit(player: Player, _payout: number)
	local profile = Data.get(player)
	if not profile or not Config.UseDataStores then
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

local function buildBoard()
	local anchor = Instance.new("Part")
	anchor.Name = "LeaderboardWall"
	anchor.Size = Vector3.new(40, 24, 2)
	anchor.CFrame = CFrame.new(-52, 12, 76) * CFrame.Angles(0, math.rad(-35), 0)
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
	title.Text = "DEEPEST DIVES"
	title.TextColor3 = Color3.fromRGB(120, 220, 255)
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

	stats.Parent = player

	task.spawn(function()
		while player.Parent do
			local profile = Data.get(player)
			local session = Data.session(player)
			if profile then
				cash.Value = Format.short(profile.cash)
				depth.Value = Format.depth(session and session.depth or 0)
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
		return { depth = cache.depth, banked = cache.banked }
	end)

	task.spawn(function()
		-- The world builds first; give it a beat before parenting to it.
		task.wait(2)
		local list = buildBoard()
		while true do
			refresh()
			renderBoard(list)
			task.wait(Config.LeaderboardRefresh)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWrite[player.UserId] = nil
	end)
end

return Leaderboards
