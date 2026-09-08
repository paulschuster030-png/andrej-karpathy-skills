--!nonstrict
--[[
	Panels.luau — every full-screen menu, behind one tab switcher.

	Content is rebuilt on open rather than kept live. A mining game's menus
	are read for a few seconds at a time, and rebuilding 30 rows costs far
	less than keeping six panels subscribed to every state patch.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DroneConfig = require(Shared.Config.Drones)
local Format = require(Shared.Format)
local Layers = require(Shared.Config.Layers)
local Net = require(Shared.Net)
local Ores = require(Shared.Config.Ores)
local ProductConfig = require(Shared.Config.Products)
local RebirthConfig = require(Shared.Config.Rebirth)
local UpgradeConfig = require(Shared.Config.Upgrades)

local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Panels = {}

local player = Players.LocalPlayer
local theme = Ui.THEME

local gui: ScreenGui
local window: Frame
local titleLabel: TextLabel
local content: ScrollingFrame
local currentTab: string? = nil

local TAB_TITLES = {
	shop = "UPGRADES",
	tasks = "TASKS",
	codex = "ORE CODEX",
	drones = "DRONES",
	boards = "LEADERBOARDS",
	rebirth = "REBIRTH",
}

local function clear()
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

--- One standard row: icon, title, subtitle, action button.
local function row(props)
	local holder = Ui.frame({
		parent = content,
		size = UDim2.new(1, -8, 0, props.height or 76),
		color = theme.panel,
	})
	Ui.stroke(holder, props.accent or theme.panelLight, 2)
	Ui.padding(holder, 10)

	if props.icon then
		Ui.text({
			parent = holder,
			size = UDim2.fromOffset(44, 44),
			text = props.icon,
			scaled = true,
		})
	end

	Ui.text({
		parent = holder,
		size = UDim2.new(1, -220, 0, 24),
		position = UDim2.fromOffset(props.icon and 52 or 0, 0),
		text = props.title or "",
		color = props.titleColor or theme.text,
		align = Enum.TextXAlignment.Left,
		scaled = false,
		textSize = 18,
	})

	Ui.text({
		parent = holder,
		size = UDim2.new(1, -220, 0, 34),
		position = UDim2.fromOffset(props.icon and 52 or 0, 24),
		text = props.body or "",
		color = theme.muted,
		align = Enum.TextXAlignment.Left,
		valign = Enum.TextYAlignment.Top,
		scaled = false,
		textSize = 14,
		wrap = true,
	})

	if props.progress then
		local _, fill = Ui.bar({
			parent = holder,
			size = UDim2.new(1, -200, 0, 8),
			position = UDim2.new(0, props.icon and 52 or 0, 1, -10),
			anchor = Vector2.new(0, 1),
			color = props.accent or theme.cyan,
			radius = 4,
		})
		fill.Size = UDim2.fromScale(math.clamp(props.progress, 0, 1), 1)
	end

	if props.action then
		Ui.button({
			parent = holder,
			size = UDim2.fromOffset(150, 46),
			position = UDim2.new(1, 0, 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			text = props.action,
			color = props.actionColor or theme.cyan,
			textColor = props.actionTextColor or Color3.fromRGB(10, 20, 26),
			scaled = false,
			onClick = props.onAction,
		})
	end

	return holder
end

local function header(text: string)
	Ui.text({
		parent = content,
		size = UDim2.new(1, -8, 0, 34),
		text = text,
		color = theme.muted,
		align = Enum.TextXAlignment.Left,
		scaled = false,
		textSize = 15,
	})
end

-- Tabs ---------------------------------------------------------------------

local function renderShop()
	header("SPEND CASH — everything here is permanent")

	for _, upgrade in ipairs(UpgradeConfig.List) do
		local level = State.data.upgrades[upgrade.id] or 0
		local maxed = level >= upgrade.maxLevel
		local cost = UpgradeConfig.cost(upgrade.id, level)
		local affordable = State.data.cash >= cost

		row({
			icon = upgrade.icon,
			title = `{upgrade.name}  ·  Lv {level}/{upgrade.maxLevel}`,
			body = `{upgrade.desc}\nNow: {upgrade.format(level)}`,
			progress = level / upgrade.maxLevel,
			accent = maxed and theme.green or theme.panelLight,
			action = maxed and "MAXED" or Format.short(cost),
			actionColor = maxed and theme.panelLight or (affordable and theme.gold or theme.panelLight),
			actionTextColor = affordable and Color3.fromRGB(30, 24, 10) or theme.muted,
			onAction = function()
				if not maxed then
					Net.fire("BuyUpgrade", upgrade.id)
				end
			end,
		})
	end

	local passes = ProductConfig.configuredGamepasses()
	if #passes > 0 then
		header("PASSES — permanent, account-wide")
		for _, pass in ipairs(passes) do
			local owned = State.data.gamepasses[pass.id] == true
			row({
				icon = pass.icon,
				title = pass.name,
				body = pass.desc,
				accent = owned and theme.green or theme.accent,
				action = owned and "OWNED" or "GET",
				actionColor = owned and theme.green or theme.accent,
				actionTextColor = Color3.fromRGB(255, 255, 255),
				onAction = function()
					if not owned then
						MarketplaceService:PromptGamePassPurchase(player, pass.assetId)
					end
				end,
			})
		end
	end
end

local function renderTasks()
	local board = State.data.questBoard or {}

	if board.onboarding then
		header(`GETTING STARTED — {board.onboarding.index}/{board.onboarding.total}`)
		local quest = board.onboarding
		local done = quest.progress >= quest.target
		row({
			icon = "🎯",
			title = quest.name,
			body = `{quest.desc}\n{Format.short(quest.progress)} / {Format.short(quest.target)}  ·  reward {Format.short(quest.reward.cash or 0)}`,
			progress = quest.progress / quest.target,
			accent = done and theme.green or theme.cyan,
			action = done and "CLAIM" or "IN PROGRESS",
			actionColor = done and theme.green or theme.panelLight,
			actionTextColor = done and Color3.fromRGB(10, 30, 20) or theme.muted,
			onAction = function()
				if done then
					Net.fire("ClaimQuest", quest.id)
					task.delay(0.35, function()
						if currentTab == "tasks" then
							Panels.open("tasks")
						end
					end)
				end
			end,
		})
	end

	header(`DAILY — resets at midnight UTC  ·  {board.rerolls or 0} reroll left`)
	for _, quest in ipairs(board.daily or {}) do
		local done = quest.progress >= quest.target
		row({
			icon = quest.claimed and "✅" or "📋",
			title = quest.name,
			body = `{quest.desc}\n{Format.short(quest.progress)} / {Format.short(quest.target)}  ·  reward {Format.short(quest.reward.cash or 0)}`,
			progress = quest.progress / quest.target,
			accent = quest.claimed and theme.panelLight or (done and theme.green or theme.panelLight),
			action = quest.claimed and "DONE" or (done and "CLAIM" or "…"),
			actionColor = (done and not quest.claimed) and theme.green or theme.panelLight,
			actionTextColor = (done and not quest.claimed) and Color3.fromRGB(10, 30, 20) or theme.muted,
			onAction = function()
				if done and not quest.claimed then
					Net.fire("ClaimQuest", quest.id)
					task.delay(0.35, function()
						if currentTab == "tasks" then
							Panels.open("tasks")
						end
					end)
				end
			end,
		})
	end

	if (board.rerolls or 0) > 0 then
		row({
			icon = "🎲",
			title = "Reroll dailies",
			body = "Swap all three for a fresh set. One per day.",
			action = "REROLL",
			actionColor = theme.accent,
			actionTextColor = Color3.fromRGB(255, 255, 255),
			onAction = function()
				Net.fire("RerollDaily")
				task.delay(0.35, function()
					if currentTab == "tasks" then
						Panels.open("tasks")
					end
				end)
			end,
		})
	end

	header("MILESTONES")
	for _, quest in ipairs(board.milestones or {}) do
		local done = quest.progress >= quest.target
		row({
			icon = "🏔️",
			title = quest.name,
			body = `{quest.desc}\n{Format.short(quest.progress)} / {Format.short(quest.target)}  ·  reward {Format.short(quest.reward.cash or 0)}`,
			progress = quest.progress / quest.target,
			accent = done and theme.gold or theme.panelLight,
			action = done and "CLAIM" or "LOCKED",
			actionColor = done and theme.gold or theme.panelLight,
			actionTextColor = done and Color3.fromRGB(30, 24, 10) or theme.muted,
			onAction = function()
				if done then
					Net.fire("ClaimQuest", quest.id)
					task.delay(0.35, function()
						if currentTab == "tasks" then
							Panels.open("tasks")
						end
					end)
				end
			end,
		})
	end
end

local function renderCodex()
	local found = 0
	for _ in pairs(State.data.codex or {}) do
		found += 1
	end
	header(`{found} / {#Ores.List} ORES FOUND — deeper layers hold rarer rock`)

	for _, ore in ipairs(Ores.List) do
		local count = (State.data.codex or {})[ore.id] or 0
		local discovered = count > 0
		row({
			height = 64,
			icon = discovered and "💎" or "❔",
			title = discovered and `{ore.name}  ·  {ore.tier}` or "???",
			titleColor = discovered and Ores.color(ore.tier) or theme.muted,
			body = discovered
				and `Found {count}x  ·  base value {Format.short(ore.value)}  ·  {Format.depth(ore.minDepth)}+`
				or `Somewhere below {Format.depth(ore.minDepth)}`,
			accent = discovered and Ores.color(ore.tier) or theme.panelLight,
		})
	end
end

local function renderDrones()
	header("ONE EQUIPPED AT A TIME — ownership survives rebirth")

	for _, drone in ipairs(DroneConfig.List) do
		local owned = (State.data.drones.owned or {})[drone.id] == true
		local equipped = State.data.drones.equipped == drone.id

		local bonuses = {}
		for stat, value in pairs(drone.bonus) do
			table.insert(bonuses, `{stat} +{value}`)
		end

		local action, actionColor
		if equipped then
			action, actionColor = "EQUIPPED", theme.green
		elseif owned then
			action, actionColor = "EQUIP", theme.cyan
		elseif drone.cost then
			action, actionColor = Format.short(drone.cost), theme.gold
		else
			action, actionColor = "FIND IT", theme.panelLight
		end

		row({
			icon = "🛠️",
			title = `{drone.name}  ·  {drone.rarity}`,
			titleColor = Ores.color(drone.rarity),
			body = `{drone.desc}\n{table.concat(bonuses, "  ·  ")}`,
			accent = equipped and theme.green or (owned and theme.cyan or theme.panelLight),
			action = action,
			actionColor = actionColor,
			actionTextColor = Color3.fromRGB(15, 20, 25),
			onAction = function()
				if owned then
					Net.fire("EquipDrone", drone.id)
				elseif drone.cost then
					Net.fire("BuyDrone", drone.id)
				end
				task.delay(0.35, function()
					if currentTab == "drones" then
						Panels.open("drones")
					end
				end)
			end,
		})
	end
end

local function renderBoards()
	header("GLOBAL — updates every 90 seconds")

	local boards = Net.invoke("GetBoards") or { depth = {}, banked = {} }

	if #(boards.depth or {}) == 0 then
		row({ icon = "🕳️", title = "No records yet", body = "Be the first name on this wall." })
	end

	for _, entry in ipairs(boards.depth or {}) do
		row({
			height = 58,
			icon = entry.rank == 1 and "🥇" or (entry.rank == 2 and "🥈" or (entry.rank == 3 and "🥉" or "▫️")),
			title = `#{entry.rank}  {entry.name}`,
			body = "Deepest dive: " .. Format.depth(entry.value),
			accent = entry.rank == 1 and theme.gold or theme.panelLight,
		})
	end

	header("RICHEST MINERS")
	for _, entry in ipairs(boards.banked or {}) do
		row({
			height = 58,
			icon = "💰",
			title = `#{entry.rank}  {entry.name}`,
			body = "Banked lifetime: " .. Format.short(entry.value),
			accent = entry.rank == 1 and theme.gold or theme.panelLight,
		})
	end
end

local function renderRebirth()
	local rebirths = State.data.rebirths or 0
	local requirement = RebirthConfig.requirement(rebirths)
	local current = RebirthConfig.bonuses(rebirths)
	local upcoming = RebirthConfig.bonuses(rebirths + 1)

	local cashOk = (State.data.cash or 0) >= requirement.cash
	local depthOk = ((State.data.stats or {}).bestDepth or 0) >= requirement.depth
	local ready = cashOk and depthOk

	header("REBIRTH KEEPS your codex, drones, records and title")
	header("REBIRTH WIPES your cash and upgrades")

	row({
		icon = "🔥",
		title = `Rebirth {rebirths} → {rebirths + 1}  ·  {RebirthConfig.title(rebirths + 1)}`,
		body = `Now: x{string.format("%.2f", current.cashMultiplier)} cash · +{string.format("%.2f", current.luck)} luck · +{current.capacity} cargo`
			.. `\nAfter: x{string.format("%.2f", upcoming.cashMultiplier)} cash · +{string.format("%.2f", upcoming.luck)} luck · +{upcoming.capacity} cargo`,
		accent = ready and theme.accent or theme.panelLight,
		action = ready and "REBIRTH" or "LOCKED",
		actionColor = ready and theme.accent or theme.panelLight,
		actionTextColor = Color3.fromRGB(255, 255, 255),
		height = 96,
		onAction = function()
			if ready then
				Net.fire("Rebirth")
				task.delay(0.5, function()
					Panels.close()
				end)
			end
		end,
	})

	row({
		icon = cashOk and "✅" or "❌",
		title = "Cash on hand",
		body = `{Format.short(State.data.cash or 0)} / {Format.short(requirement.cash)}`,
		progress = (State.data.cash or 0) / requirement.cash,
		accent = cashOk and theme.green or theme.danger,
	})

	row({
		icon = depthOk and "✅" or "❌",
		title = "Record dive",
		body = `{Format.depth((State.data.stats or {}).bestDepth or 0)} / {Format.depth(requirement.depth)}`,
		progress = ((State.data.stats or {}).bestDepth or 0) / requirement.depth,
		accent = depthOk and theme.green or theme.danger,
	})

	header("LAYERS UNLOCKED BY REBIRTH")
	for _, layer in ipairs(Layers.List) do
		local unlocked = rebirths >= layer.gate
		row({
			height = 58,
			icon = unlocked and "🔓" or "🔒",
			title = `{layer.name}  ·  {Format.depth(layer.minDepth)}+`,
			body = unlocked and layer.blurb or `Needs rebirth {layer.gate}`,
			accent = unlocked and theme.panelLight or theme.danger,
		})
	end
end

local RENDERERS = {
	shop = renderShop,
	tasks = renderTasks,
	codex = renderCodex,
	drones = renderDrones,
	boards = renderBoards,
	rebirth = renderRebirth,
}

function Panels.open(tab: string)
	local renderer = RENDERERS[tab]
	if not renderer then
		return
	end

	currentTab = tab
	titleLabel.Text = TAB_TITLES[tab] or string.upper(tab)
	clear()

	local ok, err = pcall(renderer)
	if not ok then
		warn("DeepRush: panel " .. tab .. " failed: " .. tostring(err))
	end

	window.Visible = true
end

function Panels.close()
	currentTab = nil
	window.Visible = false
end

function Panels.toggle(tab: string)
	if currentTab == tab then
		Panels.close()
	else
		Panels.open(tab)
	end
end

function Panels.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "DeepRushPanels"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	window = Ui.frame({
		parent = gui,
		size = UDim2.new(0.62, 0, 0.78, 0),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = theme.bg,
		visible = false,
		radius = 16,
	})
	Ui.stroke(window, theme.panelLight, 2)

	-- Keep the panel usable on a phone in portrait.
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(320, 320)
	constraint.MaxSize = Vector2.new(760, 900)
	constraint.Parent = window

	titleLabel = Ui.text({
		parent = window,
		size = UDim2.new(1, -80, 0, 56),
		position = UDim2.fromOffset(20, 8),
		text = "UPGRADES",
		align = Enum.TextXAlignment.Left,
		font = Enum.Font.GothamBlack,
		scaled = false,
		textSize = 26,
	})

	Ui.button({
		parent = window,
		size = UDim2.fromOffset(48, 48),
		position = UDim2.new(1, -14, 0, 12),
		anchor = Vector2.new(1, 0),
		text = "✕",
		color = theme.panel,
		onClick = Panels.close,
	})

	content = Instance.new("ScrollingFrame")
	content.Size = UDim2.new(1, -24, 1, -80)
	content.Position = UDim2.fromOffset(12, 68)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = theme.panelLight
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.CanvasSize = UDim2.new()
	content.Parent = window

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content
end

return Panels
