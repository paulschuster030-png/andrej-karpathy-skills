--!nonstrict
--[[
	Notify.luau — toasts and the rare-pull reveal card.

	The reveal card is the single most important 1.5 seconds in the game. It
	is what a player screenshots, what they clip, and what makes a friend ask
	what they are playing. So it gets the tier colour, the real odds, and a
	deliberate slam-in animation rather than a polite fade.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Mutations = require(Shared.Config.Mutations)
local Net = require(Shared.Net)
local Ores = require(Shared.Config.Ores)

local Effects = require(script.Parent.Effects)
local Ui = require(script.Parent.Ui)

local Notify = {}

local player = Players.LocalPlayer
local theme = Ui.THEME

local toastHolder: Frame
local revealHolder: Frame

local KIND_COLOR = {
	cash = theme.gold,
	quest = theme.cyan,
	error = theme.danger,
	steal = theme.accent,
	upgrade = theme.green,
	rift = theme.accent,
	level = theme.cyan,
	announce = theme.gold,
}

local MAX_TOASTS = 5

local function pushToast(payload)
	if typeof(payload) ~= "table" then
		return
	end

	-- Oldest first out, so a burst of pickups cannot bury the screen.
	local existing = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(existing, child)
		end
	end
	if #existing >= MAX_TOASTS then
		existing[1]:Destroy()
	end

	local accent = KIND_COLOR[payload.kind or "cash"] or theme.cyan
	if payload.color then
		accent = Color3.fromRGB(payload.color[1], payload.color[2], payload.color[3])
	end

	local card = Ui.frame({
		parent = toastHolder,
		size = UDim2.new(1, 0, 0, 62),
		color = theme.panel,
	})
	Ui.stroke(card, accent, 2)
	Ui.padding(card, 8)

	Ui.text({
		parent = card,
		size = UDim2.new(1, 0, 0, 24),
		text = tostring(payload.title or ""),
		color = accent,
		align = Enum.TextXAlignment.Left,
		scaled = false,
		textSize = 18,
	})

	Ui.text({
		parent = card,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 24),
		text = tostring(payload.body or ""),
		color = theme.muted,
		align = Enum.TextXAlignment.Left,
		valign = Enum.TextYAlignment.Top,
		scaled = false,
		textSize = 14,
		wrap = true,
	})

	card.Position = UDim2.fromOffset(340, 0)
	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()

	if payload.kind ~= "error" then
		Effects.sound("ping", 0.35, 1.2)
	end

	task.delay(payload.duration or 3.5, function()
		if not card.Parent then
			return
		end
		local out = TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		card:Destroy()
	end)
end

local function showReveal(payload)
	if typeof(payload) ~= "table" then
		return
	end

	revealHolder:ClearAllChildren()

	local tierColor = payload.tier and Ores.color(payload.tier) or theme.gold
	local mutationColor = Mutations.color(payload.mutation)

	local card = Ui.frame({
		parent = revealHolder,
		size = UDim2.fromScale(1, 1),
		color = theme.bg,
		transparency = 0.05,
		radius = 18,
	})
	Ui.stroke(card, mutationColor or tierColor, 4)
	Ui.padding(card, 14)

	Ui.text({
		parent = card,
		size = UDim2.new(1, 0, 0, 26),
		text = tostring(payload.title or "RARE PULL"),
		color = theme.muted,
		scaled = false,
		textSize = 17,
	})

	Ui.text({
		parent = card,
		size = UDim2.new(1, 0, 0, 54),
		position = UDim2.fromOffset(0, 26),
		text = tostring(payload.name or ""),
		color = mutationColor or tierColor,
		font = Enum.Font.GothamBlack,
		scaled = false,
		textSize = 36,
	})

	local subtitle = payload.tier and string.upper(payload.tier) or ""
	if payload.value then
		subtitle ..= `  ·  {Format.short(payload.value)}`
	end
	if payload.odds and payload.odds > 0 then
		subtitle ..= `  ·  {Format.odds(payload.odds)}`
	end

	Ui.text({
		parent = card,
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 82),
		text = subtitle,
		color = tierColor,
		scaled = false,
		textSize = 18,
	})

	if payload.body then
		Ui.text({
			parent = card,
			size = UDim2.new(1, 0, 0, 30),
			position = UDim2.fromOffset(0, 108),
			text = tostring(payload.body),
			color = theme.muted,
			scaled = false,
			textSize = 14,
			wrap = true,
		})
	end

	-- Slam in, hold, drop out.
	card.Size = UDim2.fromScale(1.35, 1.35)
	card.Position = UDim2.fromScale(-0.17, -0.17)
	TweenService:Create(card, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
	}):Play()

	Effects.sound("boom", 0.6, 1.1)
	Effects.shake(1.4, 0.3)

	task.delay(3.2, function()
		if card.Parent then
			local out = TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
			out:Play()
			out.Completed:Wait()
			card:Destroy()
		end
	end)
end

function Notify.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeepRushNotify"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	toastHolder = Ui.frame({
		parent = gui,
		size = UDim2.fromOffset(320, 400),
		position = UDim2.new(1, -16, 0, 92),
		anchor = Vector2.new(1, 0),
		transparency = 1,
		radius = false,
	})

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.Parent = toastHolder

	revealHolder = Ui.frame({
		parent = gui,
		size = UDim2.fromOffset(440, 160),
		position = UDim2.fromScale(0.5, 0.32),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 1,
		radius = false,
	})

	Net.listen("Toast", pushToast)
	Net.listen("Reveal", showReveal)
end

return Notify
