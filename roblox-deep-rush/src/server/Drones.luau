--!nonstrict
--[[
	Drones.luau — ownership, equipping, and the little thing that follows you.

	The visual matters more than the stats. A drone bobbing next to your head
	is the cheapest possible way to make a player feel like they have a
	loadout, and it is what other players see when they look at you.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DroneConfig = require(Shared.Config.Drones)
local Ores = require(Shared.Config.Ores)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Drones = {}

local models: { [Player]: BasePart } = {}

local function destroyModel(player: Player)
	local model = models[player]
	if model then
		model:Destroy()
		models[player] = nil
	end
end

local function buildModel(player: Player)
	destroyModel(player)

	local profile = Data.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not profile or not root or not profile.drones.equipped then
		return
	end

	local drone = DroneConfig.ById[profile.drones.equipped]
	if not drone then
		return
	end

	local part = Instance.new("Part")
	part.Name = "Drone"
	part.Size = Vector3.new(1.6, 1.6, 1.6)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = Ores.color(drone.rarity)
	part.CanCollide = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(2.6, 2.4, 1)

	-- AlignPosition on a floating attachment gives the lazy trailing bob for
	-- free; hand-animating it would cost a heartbeat connection per player.
	local droneAttachment = Instance.new("Attachment")
	droneAttachment.Parent = part

	-- The root outlives the drone model, so a re-equip would otherwise leave
	-- its old target attachment behind and stack one per swap.
	local existing = root:FindFirstChild("DroneTarget")
	if existing then
		existing:Destroy()
	end

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "DroneTarget"
	targetAttachment.Position = Vector3.new(2.6, 2.4, 1)
	targetAttachment.Parent = root

	local align = Instance.new("AlignPosition")
	align.Attachment0 = droneAttachment
	align.Attachment1 = targetAttachment
	align.MaxForce = 45000
	align.Responsiveness = 12
	align.Parent = part

	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Range = 16
	light.Brightness = 1.6
	light.Parent = part

	part.Parent = workspace
	models[player] = part
end

function Drones.equip(player: Player, droneId: string)
	local profile = Data.get(player)
	if not profile or not profile.drones.owned[droneId] then
		return
	end

	profile.drones.equipped = droneId
	Data.push(player, { drones = Data.replace(table.clone(profile.drones)) })
	buildModel(player)

	local drone = DroneConfig.ById[droneId]
	Feedback.toast(player, { title = "EQUIPPED", body = drone and drone.name or droneId, kind = "upgrade" })
end

function Drones.buy(player: Player, droneId: string)
	local profile = Data.get(player)
	local drone = DroneConfig.ById[droneId]
	if not profile or not drone then
		return
	end

	if profile.drones.owned[droneId] then
		Drones.equip(player, droneId)
		return
	end

	if not drone.cost then
		Feedback.toast(player, {
			title = "NOT FOR SALE",
			body = `{drone.name} only turns up below {Format.depth(drone.findDepth or 0)}.`,
			kind = "error",
		})
		return
	end

	if not Economy.spend(player, drone.cost) then
		Feedback.toast(player, {
			title = "NOT ENOUGH CASH",
			body = `{drone.name} costs {Format.short(drone.cost)}.`,
			kind = "error",
		})
		return
	end

	profile.drones.owned[droneId] = true
	Data.push(player, { drones = Data.replace(table.clone(profile.drones)) })
	Drones.equip(player, droneId)
end

function Drones.start()
	Net.on("BuyDrone", function(player, droneId)
		if type(droneId) == "string" then
			Drones.buy(player, droneId)
		end
	end)

	Net.on("EquipDrone", function(player, droneId)
		if type(droneId) == "string" then
			Drones.equip(player, droneId)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			buildModel(player)
		end)
	end)

	Players.PlayerRemoving:Connect(destroyModel)
end

return Drones
