--!nonstrict
--[[
	Intro.luau — the rules card, shown before the first dig.

	Six lines, each one a rule a player would otherwise have to lose something
	to learn. It is the cheapest retention work in the game: the platform
	grades a new experience hardest on whether anyone comes back the next day,
	and most of the reasons they do not are simply not knowing what the game
	wanted from them.

	Rules for the rules:
	  * Six lines, no paragraphs. Anything longer gets skipped, and a skipped
	    tutorial is worse than none because it costs the click as well.
	  * Every line is a verb. "Hold to mine", not "Mining is done by holding".
	  * It appears once. The flag lives on the profile, so it does not come
	    back on a new device or after a rejoin.
	  * It stays reachable. The "?" button re-opens it, because the person who
	    needs it most is the one who skipped it.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Intro = {}

local player = Players.LocalPlayer
local theme = Ui.THEME

local gui: ScreenGui
local card: Frame
local shown = false

local RULES = {
	{ icon = "⛏️", title = "THE ROCK SHOWS WHAT IS IN IT", body = "Gold, silver, diamond — each one has its own colour and glow in the wall. Look at one and hold to mine it." },
	{ icon = "⬇️", title = "DEEPER PAYS MORE", body = "Every metre multiplies what the rock is worth. 1,400m ore is not 1,400m of walking — it is a different game." },
	{ icon = "💰", title = "BANK IT OR LOSE IT", body = "Cargo is not yours until you ride a lift up and deposit it at the vault." },
	{ icon = "⚠️", title = "A FULL HOLD MAKES YOU A TARGET", body = "Past 60% you glow, and other miners can snatch from you. Bank early and nobody can touch you." },
	{ icon = "☣️", title = "WALK AROUND THE GLOWING ZONES", body = "Gas, vents and frost are visible and named. The pulsing ones have a rhythm you can walk through." },
	{ icon = "▲", title = "LIFTS ARE THE ONLY WAY UP", body = "Falling is free and fast. Climbing back is the part you pay for — plan the trip. Stuck? Stand still and hold Emergency Ascent." },
	{ icon = "◈", title = "RANK IS FOREVER", body = "Everything you ever bank counts toward your rank, and it never goes down. It is written over your head for everyone to read." },
}

local function buildCard(parent)
	local holder = Ui.frame({
		parent = parent,
		size = UDim2.new(0.62, 0, 0.86, 0),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = theme.bg,
		radius = 20,
	})
	Ui.stroke(holder, theme.gold, 3)

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(340, 380)
	constraint.MaxSize = Vector2.new(720, 860)
	constraint.Parent = holder

	Ui.text({
		parent = holder,
		size = UDim2.new(1, -40, 0, 32),
		position = UDim2.fromOffset(28, 22),
		text = "⛏ DEEP RUSH",
		color = theme.gold,
		align = Enum.TextXAlignment.Left,
		font = Enum.Font.GothamBold,
		scaled = false,
		textSize = 22,
	})

	Ui.text({
		parent = holder,
		size = UDim2.new(1, -40, 0, 46),
		position = UDim2.fromOffset(28, 52),
		text = "SEVEN THINGS AND YOU'RE READY",
		color = theme.text,
		align = Enum.TextXAlignment.Left,
		font = Enum.Font.GothamBlack,
		scaled = false,
		textSize = 34,
	})

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -48, 1, -190)
	list.Position = UDim2.fromOffset(24, 108)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = theme.panelLight
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	for index, rule in ipairs(RULES) do
		local row = Ui.frame({
			parent = list,
			size = UDim2.new(1, -6, 0, 74),
			color = theme.panel,
		})
		row.LayoutOrder = index
		Ui.stroke(row, theme.panelLight, 2)
		Ui.padding(row, 10)

		Ui.text({
			parent = row,
			size = UDim2.fromOffset(44, 44),
			position = UDim2.fromOffset(0, 4),
			text = rule.icon,
			scaled = true,
		})

		Ui.text({
			parent = row,
			size = UDim2.new(1, -56, 0, 22),
			position = UDim2.fromOffset(54, 0),
			text = rule.title,
			color = theme.gold,
			align = Enum.TextXAlignment.Left,
			scaled = false,
			textSize = 18,
		})

		Ui.text({
			parent = row,
			size = UDim2.new(1, -56, 0, 32),
			position = UDim2.fromOffset(54, 22),
			text = rule.body,
			color = theme.muted,
			align = Enum.TextXAlignment.Left,
			valign = Enum.TextYAlignment.Top,
			scaled = false,
			textSize = 14,
			wrap = true,
		})
	end

	Ui.button({
		parent = holder,
		size = UDim2.new(1, -48, 0, 60),
		position = UDim2.new(0.5, 0, 1, -20),
		anchor = Vector2.new(0.5, 1),
		text = "⛏  START DIGGING",
		color = theme.gold,
		textColor = Color3.fromRGB(28, 22, 8),
		scaled = false,
		onClick = function()
			Intro.hide(true)
		end,
	})

	return holder
end

function Intro.show()
	if shown then
		return
	end
	shown = true
	gui.Enabled = true

	card.Size = UDim2.new(0.55, 0, 0.78, 0)
	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.62, 0, 0.86, 0),
		BackgroundTransparency = 0,
	}):Play()
end

function Intro.hide(remember: boolean?)
	if not shown then
		return
	end
	shown = false

	local out = TweenService:Create(card, TweenInfo.new(0.22), {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.55, 0, 0.78, 0),
	})
	out:Play()
	out.Completed:Once(function()
		gui.Enabled = false
	end)

	if remember then
		Net.fire("IntroSeen")
	end
end

function Intro.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "DeepRushIntro"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = Ui.frame({
		parent = gui,
		size = UDim2.fromScale(1, 1),
		color = Color3.fromRGB(0, 0, 0),
		transparency = 0.35,
		radius = false,
	})
	dim.ZIndex = 1

	card = buildCard(gui)
	card.ZIndex = 2

	-- The person who most needs the rules is the one who skipped them, so
	-- they stay one tap away.
	local help = Instance.new("ScreenGui")
	help.Name = "DeepRushHelpButton"
	help.ResetOnSpawn = false
	help.DisplayOrder = 4
	help.Parent = player:WaitForChild("PlayerGui")

	Ui.button({
		parent = help,
		size = UDim2.fromOffset(44, 44),
		position = UDim2.new(0, 258, 0, 16),
		text = "?",
		color = theme.panel,
		stroke = theme.panelLight,
		onClick = function()
			if shown then
				Intro.hide(false)
			else
				Intro.show()
			end
		end,
	})

	-- Wait for the first state snapshot before deciding: showing the card to a
	-- returning player who already dismissed it is the exact opposite of the
	-- point.
	task.spawn(function()
		for _ = 1, 60 do
			if State.data.seenIntro ~= nil then
				break
			end
			task.wait(0.25)
		end
		if not State.data.seenIntro then
			Intro.show()
		end
	end)
end

return Intro
