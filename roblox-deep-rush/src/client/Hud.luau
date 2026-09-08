--!nonstrict
--[[
	Hud.luau — everything on screen during play.

	Layout priorities, in order:
	  1. DEPTH, dead centre top and huge. It is the score, the progress bar
	     and the brag, all at once.
	  2. CARGO, bottom centre, colour-shifting to red as greed rises. A player
	     must be able to read "I am a target now" without reading a word.
	  3. Contextual actions, bottom right. BANK only exists at the vault,
	     LIFT only on a pad, SNATCH only when someone marked is in range —
	     so the button that is showing is always the button you want.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Format = require(Shared.Format)
local Layers = require(Shared.Config.Layers)
local Net = require(Shared.Net)
local RebirthConfig = require(Shared.Config.Rebirth)

local Mining = require(script.Parent.Mining)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer
local theme = Ui.THEME

local widgets = {}
local vaultPart: BasePart? = nil

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function findVault()
	task.spawn(function()
		while not vaultPart do
			for _, descendant in ipairs(workspace:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant:GetAttribute("Vault") then
					vaultPart = descendant
					return
				end
			end
			task.wait(1)
		end
	end)
end

local function buildTopLeft(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(230, 96),
		position = UDim2.fromOffset(16, 16),
		color = theme.panel,
		transparency = 0.15,
	})
	Ui.stroke(holder, theme.panelLight, 2)
	Ui.padding(holder, 10)

	widgets.cash = Ui.text({
		parent = holder,
		size = UDim2.new(1, 0, 0, 40),
		text = "💰 0",
		color = theme.gold,
		align = Enum.TextXAlignment.Left,
		font = Enum.Font.GothamBlack,
	})

	widgets.title = Ui.text({
		parent = holder,
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 42),
		text = "Surface Rat",
		color = theme.muted,
		align = Enum.TextXAlignment.Left,
		scaled = false,
		textSize = 15,
	})

	local barHolder, barFill, barLabel = Ui.bar({
		parent = holder,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 62),
		color = theme.cyan,
		text = "LV 1",
		textSize = 12,
	})
	widgets.xpFill = barFill
	widgets.xpLabel = barLabel
end

local function buildTopCenter(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(300, 120),
		position = UDim2.new(0.5, 0, 0, 12),
		anchor = Vector2.new(0.5, 0),
		transparency = 1,
		radius = false,
	})

	widgets.depth = Ui.text({
		parent = holder,
		size = UDim2.new(1, 0, 0, 62),
		text = "0m",
		color = theme.text,
		font = Enum.Font.GothamBlack,
	})

	widgets.layer = Ui.text({
		parent = holder,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 60),
		text = "Topsoil",
		color = theme.muted,
		scaled = false,
		textSize = 16,
	})

	local _, oxygenFill, oxygenLabel = Ui.bar({
		parent = holder,
		size = UDim2.new(1, -40, 0, 14),
		position = UDim2.new(0.5, 0, 0, 88),
		anchor = Vector2.new(0.5, 0),
		color = theme.cyan,
		text = "AIR",
		textSize = 11,
	})
	widgets.oxygenFill = oxygenFill
	widgets.oxygenLabel = oxygenLabel
end

local function buildRiftChip(parent)
	local chip = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(210, 62),
		position = UDim2.new(1, -16, 0, 16),
		anchor = Vector2.new(1, 0),
		color = theme.panel,
		transparency = 0.15,
	})
	Ui.stroke(chip, theme.accent, 2)
	Ui.padding(chip, 8)

	widgets.riftTitle = Ui.text({
		parent = chip,
		size = UDim2.new(1, 0, 0, 22),
		text = "NEXT RIFT",
		color = theme.accent,
		scaled = false,
		textSize = 15,
	})

	widgets.riftBody = Ui.text({
		parent = chip,
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 22),
		text = "--:--",
		color = theme.text,
		font = Enum.Font.GothamBlack,
		scaled = false,
		textSize = 20,
	})

	widgets.riftChip = chip
end

local function buildCargo(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(360, 58),
		position = UDim2.new(0.5, 0, 1, -18),
		anchor = Vector2.new(0.5, 1),
		color = theme.panel,
		transparency = 0.15,
	})
	Ui.stroke(holder, theme.panelLight, 2)
	Ui.padding(holder, 8)

	widgets.cargoStroke = holder:FindFirstChildOfClass("UIStroke")

	local _, fill, label = Ui.bar({
		parent = holder,
		size = UDim2.new(1, 0, 0, 22),
		color = theme.green,
		text = "CARGO 0 / 8",
		textSize = 13,
	})
	widgets.cargoFill = fill
	widgets.cargoLabel = label

	widgets.cargoValue = Ui.text({
		parent = holder,
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 24),
		text = "worth 0",
		color = theme.muted,
		scaled = false,
		textSize = 14,
	})
end

local function buildMenu(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(72, 300),
		position = UDim2.new(0, 16, 1, -18),
		anchor = Vector2.new(0, 1),
		transparency = 1,
		radius = false,
	})

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = holder

	local entries = {
		{ icon = "⛏️", tab = "shop", color = theme.panelLight },
		{ icon = "📋", tab = "tasks", color = theme.panelLight },
		{ icon = "📖", tab = "codex", color = theme.panelLight },
		{ icon = "🛠️", tab = "drones", color = theme.panelLight },
		{ icon = "🏆", tab = "boards", color = theme.panelLight },
		{ icon = "🔥", tab = "rebirth", color = theme.accent },
	}

	for _, entry in ipairs(entries) do
		local button = Ui.button({
			parent = holder,
			size = UDim2.fromOffset(64, 56),
			text = entry.icon,
			color = entry.color,
			onClick = function()
				Panels.toggle(entry.tab)
			end,
		})

		-- The tasks button carries the "you have something to claim" dot,
		-- which is most of why anyone opens the panel at all.
		if entry.tab == "tasks" then
			widgets.taskDot = Ui.frame({
				parent = button,
				size = UDim2.fromOffset(16, 16),
				position = UDim2.new(1, -4, 0, 4),
				anchor = Vector2.new(1, 0),
				color = theme.accent,
				radius = 8,
				z = 5,
				visible = false,
			})
		end
	end
end

local function buildActions(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(180, 280),
		position = UDim2.new(1, -16, 1, -18),
		anchor = Vector2.new(1, 1),
		transparency = 1,
		radius = false,
	})

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = holder

	widgets.bankButton = Ui.button({
		parent = holder,
		size = UDim2.fromOffset(176, 58),
		text = "💰 BANK",
		color = theme.gold,
		textColor = Color3.fromRGB(30, 24, 10),
		onClick = function()
			Net.fire("Bank")
		end,
		visible = false,
	})

	widgets.liftButton = Ui.button({
		parent = holder,
		size = UDim2.fromOffset(176, 58),
		text = "▲ LIFT UP",
		color = theme.green,
		textColor = Color3.fromRGB(10, 30, 20),
		onClick = function()
			Net.fire("UseLift")
		end,
		visible = false,
	})

	widgets.snatchButton = Ui.button({
		parent = holder,
		size = UDim2.fromOffset(176, 58),
		text = "🫳 SNATCH",
		color = theme.accent,
		onClick = function()
			Net.fire("Snatch")
		end,
		visible = false,
	})

	-- Touch devices get an explicit mine button; mouse players hold LMB.
	if UserInputService.TouchEnabled then
		local mineButton = Ui.button({
			parent = holder,
			size = UDim2.fromOffset(176, 74),
			text = "⛏️ MINE",
			color = theme.panelLight,
			stroke = theme.cyan,
		})
		mineButton.MouseButton1Down:Connect(function()
			Mining.setHolding(true)
		end)
		mineButton.MouseButton1Up:Connect(function()
			Mining.setHolding(false)
		end)
		mineButton.MouseLeave:Connect(function()
			Mining.setHolding(false)
		end)
	end
end

local function buildReticle(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.fromOffset(180, 40),
		position = UDim2.new(0.5, 0, 0.5, 40),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 1,
		radius = false,
	})

	widgets.reticle = Ui.text({
		parent = holder,
		size = UDim2.new(1, 0, 0, 18),
		text = "",
		color = theme.muted,
		scaled = false,
		textSize = 14,
	})

	local _, fill = Ui.bar({
		parent = holder,
		size = UDim2.new(1, 0, 0, 8),
		position = UDim2.fromOffset(0, 22),
		color = theme.gold,
		radius = 4,
	})
	widgets.swingFill = fill
	widgets.swingHolder = fill.Parent
	widgets.swingHolder.Visible = false
end

-- Rendering ----------------------------------------------------------------

local function renderState()
	local data = State.data

	widgets.cash.Text = "💰 " .. Format.short(data.cash)
	widgets.title.Text = RebirthConfig.title(data.rebirths or 0)
		.. (data.rebirths > 0 and `  ·  R{data.rebirths}` or "")

	local needed = math.floor(Config.BaseXpToLevel * (Config.LevelCurve ^ ((data.level or 1) - 1)))
	widgets.xpFill.Size = UDim2.fromScale(math.clamp((data.xp or 0) / needed, 0, 1), 1)
	widgets.xpLabel.Text = `LV {data.level or 1}`

	local capacity = data.cargo.capacity or 8
	local ratio = math.clamp((data.cargo.count or 0) / capacity, 0, 1)
	widgets.cargoFill.Size = UDim2.fromScale(ratio, 1)
	widgets.cargoLabel.Text = `CARGO {data.cargo.count or 0} / {capacity}`
	widgets.cargoValue.Text = "worth " .. Format.short(data.cargo.value or 0)

	-- Anything claimable lights the dot on the tasks button.
	if widgets.taskDot then
		local board = data.questBoard or {}
		local claimable = false
		if board.onboarding and board.onboarding.progress >= board.onboarding.target then
			claimable = true
		end
		for _, list in ipairs({ board.daily or {}, board.milestones or {} }) do
			for _, quest in ipairs(list) do
				if not quest.claimed and quest.progress >= quest.target then
					claimable = true
				end
			end
		end
		widgets.taskDot.Visible = claimable
	end

	local marked = ratio >= Config.GreedMarkThreshold
	widgets.cargoFill.BackgroundColor3 = marked and theme.accent or theme.green
	if widgets.cargoStroke then
		widgets.cargoStroke.Color = marked and theme.accent or theme.panelLight
	end
	if marked then
		widgets.cargoValue.Text = `worth {Format.short(data.cargo.value or 0)}  ·  ⚠ MARKED — you can be snatched`
		widgets.cargoValue.TextColor3 = theme.accent
	else
		widgets.cargoValue.TextColor3 = theme.muted
	end
end

local function renderRift()
	local rift = State.rift or {}
	if rift.active then
		widgets.riftTitle.Text = rift.mine and "⚡ RIFT — YOU'RE IN IT" or "⚡ RIFT OPEN"
		widgets.riftTitle.TextColor3 = rift.mine and theme.green or theme.accent
		widgets.riftBody.Text = `{rift.layer or "?"} · {Format.clock(rift.remaining or 0)}`
	else
		widgets.riftTitle.Text = "NEXT RIFT"
		widgets.riftTitle.TextColor3 = theme.muted
		widgets.riftBody.Text = Format.clock(rift.nextIn or 0)
	end
end

local function renderContextual()
	local root = rootPart()
	if not root then
		return
	end

	local nearVault = vaultPart ~= nil
		and (root.Position - vaultPart.Position).Magnitude <= Config.BankRadius
	widgets.bankButton.Visible = nearVault and (State.data.cargo.count or 0) > 0

	local onPad = false
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, 12)) do
		if part:GetAttribute("LiftPad") then
			onPad = true
			break
		end
	end
	widgets.liftButton.Visible = onPad

	-- Snatch shows only when a marked player is actually in range.
	local snatchable = false
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and State.marked[other.UserId] then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Config.SnatchRange then
				snatchable = true
				break
			end
		end
	end
	widgets.snatchButton.Visible = snatchable

	local depth = State.data.depth or 0
	widgets.depth.Text = Format.depth(depth)
	local layer = Layers.at(depth)
	widgets.layer.Text = string.upper(layer.name)

	local oxygenRatio = math.clamp((State.data.oxygen or 0) / math.max(State.data.oxygenMax or 60, 1), 0, 1)
	widgets.oxygenFill.Size = UDim2.fromScale(oxygenRatio, 1)
	widgets.oxygenFill.BackgroundColor3 = oxygenRatio < 0.25 and theme.danger or theme.cyan
	widgets.oxygenLabel.Text = oxygenRatio >= 0.999 and "AIR OK"
		or `AIR {math.floor(oxygenRatio * 100)}%`

	local progress = Mining.progress()
	widgets.swingHolder.Visible = progress > 0
	widgets.swingFill.Size = UDim2.fromScale(progress, 1)

	if Mining.target() then
		widgets.reticle.Text = progress > 0 and "MINING..." or "◈ HOLD TO MINE"
		widgets.reticle.TextColor3 = theme.gold
	else
		widgets.reticle.Text = ""
	end
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeepRushHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	buildTopLeft(gui)
	buildTopCenter(gui)
	buildRiftChip(gui)
	buildCargo(gui)
	buildMenu(gui)
	buildActions(gui)
	buildReticle(gui)

	findVault()

	State.changed:connect(renderState)
	State.riftChanged:connect(renderRift)
	renderState()
	renderRift()

	RunService.RenderStepped:Connect(renderContextual)
end

return Hud
