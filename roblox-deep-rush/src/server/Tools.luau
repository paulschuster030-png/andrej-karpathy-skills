--!nonstrict
--[[
	Tools.luau — build the pickaxe, and swing it.

	A Motor6D rather than a WeldConstraint, because a weld cannot be animated
	and the swing is most of the point: a progress bar tells you mining is
	happening, an arm coming down tells you it is happening to THAT rock.

	Rig-agnostic: R15 characters have a RightHand, R6 characters have a
	"Right Arm". New experiences default to R15, but a place can be switched
	to R6 in one setting and nobody would think to update this file.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Tools)

local Data = require(script.Parent.Data)

local Tools = {}

local motors: { [Player]: Motor6D } = {}

local function handOf(character: Model)
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function makePart(name: string, size: Vector3, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function rgb(triple)
	return Color3.fromRGB(triple[1], triple[2], triple[3])
end

--- Rebuild the pickaxe for whatever tier the player is currently on.
function Tools.equip(player: Player)
	local character = player.Character
	local profile = Data.get(player)
	if not character or not profile then
		return
	end

	local hand = handOf(character)
	if not hand then
		return
	end

	local existing = character:FindFirstChild("Pickaxe")
	if existing then
		existing:Destroy()
	end

	-- The motor too, and not only for tidiness. Re-equipping happens on every
	-- Drill Power level now, so leaving them behind hangs a dead Motor6D on
	-- the hand per upgrade — fifty of them by max level, each pointing at a
	-- pickaxe that no longer exists.
	local staleMotor = hand:FindFirstChild("PickaxeMotor")
	if staleMotor then
		staleMotor:Destroy()
	end
	motors[player] = nil

	local tier = Config.tierFor(profile.upgrades.drill or 0)

	local haft = makePart("Pickaxe", Vector3.new(0.28, 2.6, 0.28), rgb(tier.haft), Enum.Material.Wood)
	haft.CFrame = hand.CFrame
	haft.Parent = character

	local head = makePart(
		"Head",
		Vector3.new(tier.headSize[1], tier.headSize[2], tier.headSize[3]),
		rgb(tier.head),
		tier.neon and Enum.Material.Neon or Enum.Material.Metal
	)
	head.CFrame = haft.CFrame * CFrame.new(0, 1.3, 0)
	head.Parent = haft

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = haft
	headWeld.Part1 = head
	headWeld.Parent = haft

	-- The tip, so the silhouette reads as a pick rather than a hammer.
	local tip = makePart("Tip", Vector3.new(0.5, 0.9, 0.4), rgb(tier.head), head.Material)
	tip.CFrame = head.CFrame * CFrame.new(-tier.headSize[1] / 2 + 0.2, -0.4, 0)
	tip.Parent = haft

	local tipWeld = Instance.new("WeldConstraint")
	tipWeld.Part0 = haft
	tipWeld.Part1 = tip
	tipWeld.Parent = haft

	if tier.neon then
		local glow = Instance.new("PointLight")
		glow.Color = rgb(tier.head)
		glow.Range = 14
		glow.Brightness = 2
		glow.Parent = head
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "PickaxeMotor"
	motor.Part0 = hand
	motor.Part1 = haft
	motor.C0 = CFrame.new(Config.Grip[1], Config.Grip[2], Config.Grip[3])
	motor.Parent = hand

	motors[player] = motor
end

--- One chop, timed to the swing the server is already running.
--- Chop, for as long as the swing lasts.
---
--- One tween down and one back was a single lazy wave of a stick per rock,
--- and at a maxed drill it barely moved at all. A swing is now as many chops
--- as it has room for, each with a wind-up, a fast strike and a recoil — and
--- each one kicks the rock it lands on, so the rock is part of the animation
--- rather than a thing that vanishes at the end of it.
--- How many chops fit in a swing. One per ~0.42s: below that the strikes
--- blur into a vibration, above it the pick hangs in the air.
function Tools.chopsFor(duration: number): number
	return math.clamp(math.round(duration / 0.42), 1, 4)
end

function Tools.swing(player: Player, duration: number, nodeId: string?)
	local motor = motors[player]
	if not motor or not motor.Parent then
		return
	end

	local rest = CFrame.new(Config.Grip[1], Config.Grip[2], Config.Grip[3])
	local raised = rest * CFrame.Angles(math.rad(-Config.SwingAngle * 0.55), 0, math.rad(-12))
	local struck = rest * CFrame.Angles(math.rad(Config.SwingAngle * 0.45), 0, math.rad(6))

	-- One chop per ~0.42s of swing, so a slow pick lands four and a fast one
	-- lands one. Below that the strikes blur into a vibration.
	local chops = Tools.chopsFor(duration)
	local each = duration / chops

	task.spawn(function()
		for index = 1, chops do
			if not motor.Parent then
				return
			end

			local lift = each * 0.34
			local fall = each * 0.30
			local recover = each - lift - fall

			TweenService:Create(motor, TweenInfo.new(lift, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				C0 = raised,
			}):Play()
			task.wait(lift)

			if not motor.Parent then
				return
			end
			-- The strike is the fast part. Quad In means it accelerates into
			-- the rock instead of arriving at a constant speed.
			TweenService:Create(motor, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				C0 = struck,
			}):Play()
			task.wait(fall)

			if nodeId then
				require(script.Parent.World).chipNode(nodeId, index / chops)
			end

			if motor.Parent then
				TweenService:Create(motor, TweenInfo.new(math.max(recover, 0.04), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					C0 = rest,
				}):Play()
			end
			task.wait(math.max(recover, 0.04))
		end
	end)
end

function Tools.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			-- The hand is not there on the first frame.
			task.wait(0.6)
			Tools.equip(player)
		end)
		if player.Character then
			task.delay(1, Tools.equip, player)
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)

	Players.PlayerRemoving:Connect(function(player)
		motors[player] = nil
	end)
end

return Tools
