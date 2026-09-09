--!nonstrict
--[[
	Cosmetics.luau — status you can see on someone else.

	The 2026 spending picture is that cosmetics, status items and rarity-flex
	out-earn time-skips, and DEEP RUSH sold only time-skips. This is the
	correction.

	The single rule that makes a cosmetic worth anything: it must be visible
	to OTHER players. A skin only you can see is a screenshot; a skin the
	shaft can see is status. So all three kinds render on the character —
	the lamp lights the rock around you, the trail is what people see when
	you fall past them, and the title sits on your nameplate.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Cosmetics)
local Format = require(Shared.Format)
local Ores = require(Shared.Config.Ores)
local Mutations = require(Shared.Config.Mutations)
local Net = require(Shared.Net)
local RebirthConfig = require(Shared.Config.Rebirth)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Cosmetics = {}

local function equippedId(profile, kind: string): string
	return profile.cosmetics.equipped[kind] or Config.Defaults[kind]
end

local function applyLamp(character: Model, profile)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local existing = head:FindFirstChild("DeepRushLamp")
	if existing then
		existing:Destroy()
	end

	local lamp = Instance.new("SpotLight")
	lamp.Name = "DeepRushLamp"
	lamp.Color = Config.color(equippedId(profile, "lamp"))
	lamp.Range = 42
	lamp.Angle = 75
	lamp.Brightness = 2.4
	lamp.Face = Enum.NormalId.Front
	lamp.Parent = head
end

local function applyTrail(character: Model, profile)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local existing = root:FindFirstChild("DeepRushTrail")
	if existing then
		existing:Destroy()
	end

	local id = equippedId(profile, "trail")
	if id == "trail_none" then
		return
	end

	-- A Trail needs two attachments to stretch between.
	local top = root:FindFirstChild("TrailTop") or Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1.4, 0)
	top.Parent = root

	local bottom = root:FindFirstChild("TrailBottom") or Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.4, 0)
	bottom.Parent = root

	local color = Config.color(id)
	local trail = Instance.new("Trail")
	trail.Name = "DeepRushTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.7
	trail.LightEmission = 0.8
	trail.MinLength = 0
	trail.Parent = root
end

local function applyNameplate(character: Model, profile, player: Player)
	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end

	-- Replace Roblox's own name tag so the title and rebirth can sit with it.
	-- NameDisplayDistance specifically, NOT DisplayDistanceType: the latter
	-- would also hide the health bar, which players need while hazards are
	-- chewing on them.
	humanoid.NameDisplayDistance = 0

	local existing = head:FindFirstChild("DeepRushPlate")
	if existing then
		existing:Destroy()
	end

	local plate = Instance.new("BillboardGui")
	plate.Name = "DeepRushPlate"
	-- Taller than it looks it needs to be: the rank and best-pull lines are
	-- positioned below the plate's own box, at y = 1.0 and 1.3.
	plate.Size = UDim2.fromScale(12, 3.4)
	plate.StudsOffset = Vector3.new(0, 2.6, 0)
	plate.AlwaysOnTop = false
	plate.MaxDistance = 160
	plate.Parent = head

	local titleId = equippedId(profile, "title")
	local titleConfig = Config.ById[titleId]
	local hasTitle = titleConfig ~= nil and titleConfig.text ~= nil and titleConfig.text ~= ""

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, hasTitle and 0.55 or 1, 0)
	name.Position = UDim2.new(0, 0, hasTitle and 0.45 or 0, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = player.DisplayName
	name.TextColor3 = Color3.fromRGB(235, 235, 245)
	name.TextScaled = true
	name.TextStrokeTransparency = 0.4
	name.Parent = plate

	if hasTitle then
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.45, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBlack
		title.Text = titleConfig.text
		title.TextColor3 = Config.color(titleId)
		title.TextScaled = true
		title.TextStrokeTransparency = 0.35
		title.Parent = plate
	end

	local rank = Instance.new("TextLabel")
	rank.Size = UDim2.new(1, 0, 0.3, 0)
	rank.Position = UDim2.new(0, 0, 1, 0)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.GothamMedium
	rank.Text = profile.rebirths > 0
		and `R{profile.rebirths} · {RebirthConfig.title(profile.rebirths)}`
		or RebirthConfig.title(0)
	rank.TextColor3 = Color3.fromRGB(150, 150, 175)
	rank.TextScaled = true
	rank.TextStrokeTransparency = 0.5
	rank.Parent = plate

	-- The rarest thing this player has ever pulled, in that ore's own colour.
	--
	-- This is the cheapest strong idea in the game. Collection games run on
	-- players being able to see what everyone else has; without that, a rare
	-- find is a private number. With it, walking past someone wearing a
	-- 1-in-4,300,000 pull is the reason you keep digging.
	local best = profile.stats.bestPull
	if best then
		local mutationName = best.mutation and Mutations.ById[best.mutation]
		local oreName = Ores.ById[best.oreId]
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0.3, 0)
		label.Position = UDim2.new(0, 0, 1.3, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = string.format(
			"◆ %s%s · %s",
			mutationName and (mutationName.name .. " ") or "",
			oreName and oreName.name or best.oreId,
			best.odds and best.odds > 0 and Format.odds(best.odds) or Format.short(best.value)
		)
		label.TextColor3 = Mutations.color(best.mutation) or Ores.color(best.tier)
		label.TextScaled = true
		label.TextStrokeTransparency = 0.4
		label.Parent = plate
	end
end

function Cosmetics.apply(player: Player)
	local profile = Data.get(player)
	local character = player.Character
	if not profile or not character then
		return
	end

	applyLamp(character, profile)
	applyTrail(character, profile)
	applyNameplate(character, profile, player)
end

function Cosmetics.unlock(player: Player, id: string)
	local profile = Data.get(player)
	local cosmetic = Config.ById[id]
	if not profile or not cosmetic or profile.cosmetics.owned[id] then
		return
	end

	profile.cosmetics.owned[id] = true
	profile.cosmetics.equipped[cosmetic.kind] = id
	Data.push(player, { cosmetics = Data.replace(table.clone(profile.cosmetics)) })
	Cosmetics.apply(player)

	Feedback.reveal(player, {
		title = "COSMETIC UNLOCKED",
		name = cosmetic.name,
		tier = "Epic",
		body = "Equipped. Everyone in the shaft can see it.",
		kind = "cosmetic",
	})
end

function Cosmetics.equip(player: Player, id: string)
	local profile = Data.get(player)
	local cosmetic = Config.ById[id]
	if not profile or not cosmetic then
		return
	end

	local isDefault = cosmetic.source == "default"
	if not isDefault and not profile.cosmetics.owned[id] then
		return
	end

	profile.cosmetics.equipped[cosmetic.kind] = id
	Data.push(player, { cosmetics = Data.replace(table.clone(profile.cosmetics)) })
	Cosmetics.apply(player)
end

function Cosmetics.buy(player: Player, id: string)
	local profile = Data.get(player)
	local cosmetic = Config.ById[id]
	if not profile or not cosmetic then
		return
	end

	if profile.cosmetics.owned[id] then
		Cosmetics.equip(player, id)
		return
	end

	if cosmetic.source ~= "shop" or not cosmetic.cost then
		Feedback.toast(player, {
			title = "NOT FOR SALE",
			body = `{cosmetic.name} is earned, not bought.`,
			kind = "error",
		})
		return
	end

	if not Economy.spend(player, cosmetic.cost) then
		Feedback.toast(player, {
			title = "NOT ENOUGH CASH",
			body = `{cosmetic.name} costs {Format.short(cosmetic.cost)}.`,
			kind = "error",
		})
		return
	end

	profile.cosmetics.owned[id] = true
	Data.push(player, { cosmetics = Data.replace(table.clone(profile.cosmetics)) })
	Cosmetics.equip(player, id)
end

function Cosmetics.start()
	Net.on("EquipCosmetic", function(player, id)
		if type(id) == "string" then
			Cosmetics.equip(player, id)
		end
	end)

	Net.on("BuyCosmetic", function(player, id)
		if type(id) == "string" then
			Cosmetics.buy(player, id)
		end
	end)

	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.6)
			Cosmetics.apply(player)
		end)
		if player.Character then
			task.delay(1, Cosmetics.apply, player)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
end

return Cosmetics
