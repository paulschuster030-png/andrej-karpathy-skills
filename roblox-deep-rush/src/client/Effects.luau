--!nonstrict
--[[
	Effects.luau — game feel.

	All of it is client-side and reactive to server "Effect" signals, so the
	server stays authoritative about what happened while the client decides
	how loud it is. Sounds are Roblox built-ins (rbxasset://) so the place
	works the moment you open it — swap in your own asset ids later.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local Ores = require(Shared.Config.Ores)
local Net = require(Shared.Net)

local Effects = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local AudioConfig = require(Shared.Config.Audio)

--- Built-ins by default; anything uploaded and configured wins. The mining
--- hit is the sound a player hears thousands of times a session, so it is the
--- one most worth replacing.
local SOUNDS = {
	hit = AudioConfig.source("pickHit") ~= "" and AudioConfig.source("pickHit")
		or "rbxasset://sounds/snap.wav",
	reveal = AudioConfig.source("rareReveal") ~= "" and AudioConfig.source("rareReveal")
		or "rbxasset://sounds/bass.wav",
	ping = "rbxasset://sounds/electronicpingshort.wav",
	click = "rbxasset://sounds/clickfast.wav",
	whoosh = "rbxasset://sounds/swoosh.wav",
	boom = "rbxasset://sounds/bass.wav",
}

local shakeUntil = 0
local shakeStrength = 0

function Effects.sound(name: string, volume: number?, pitch: number?)
	local id = SOUNDS[name]
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 5)
end

function Effects.shake(strength: number, duration: number)
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

--- A burst of coloured chunks where the rock broke.
local function burst(position: Vector3, color: Color3, count: number)
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.new(1, 1, 1)
	emitterPart.Position = position
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.Transparency = 1
	emitterPart.Parent = workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = emitterPart

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.Size = NumberSequence.new(0.7)
	particles.Lifetime = NumberRange.new(0.35, 0.8)
	particles.Speed = NumberRange.new(9, 20)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rate = 0
	particles.Acceleration = Vector3.new(0, -40, 0)
	particles.Parent = attachment
	particles:Emit(count)

	Debris:AddItem(emitterPart, 1.5)
end

--- The floating "+1.2K" that sells the whole game.
local function popNumber(position: Vector3, text: string, color: Color3, scale: number)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(8 * scale, 3 * scale)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextStrokeTransparency = 0.2
	label.Parent = billboard

	TweenService:Create(anchor, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = position + Vector3.new(0, 9, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()

	Debris:AddItem(anchor, 1.3)
end

Effects.popNumber = popNumber

local handlers = {}

handlers.mined = function(payload)
	local color = Ores.color(payload.tier)
	local tier = Ores.tier(payload.tier)

	if payload.position then
		burst(payload.position, color, 14 + math.floor(tier.shake * 20))
		popNumber(payload.position, "+" .. Format.short(payload.value), color, 1 + tier.shake * 0.5)
	end

	Effects.sound("hit", 0.45, 0.9 + math.random() * 0.25)
	if tier.shake > 0 then
		Effects.shake(tier.shake * 1.6, 0.25 + tier.shake * 0.2)
		Effects.sound("ping", 0.5, 1 + tier.shake * 0.3)
	end
end

handlers.full = function()
	Effects.sound("click", 0.4, 0.7)
end

handlers.bank = function(payload)
	Effects.sound("boom", 0.6, 1.2)
	Effects.shake(0.6, 0.2)
end

handlers.snatch = function()
	Effects.sound("whoosh", 0.7, 1.1)
	Effects.shake(1.2, 0.3)
end

handlers.robbed = function()
	Effects.sound("boom", 0.7, 0.7)
	Effects.shake(2.2, 0.5)
end

handlers.crate = function()
	Effects.sound("ping", 0.6, 1.3)
end

handlers.upgrade = function()
	Effects.sound("ping", 0.5, 1.5)
end

handlers.purchase = function()
	Effects.sound("boom", 0.7, 1.4)
end

handlers.rebirth = function()
	Effects.sound("boom", 0.9, 0.6)
	Effects.shake(3, 1.2)
end

handlers.rift = function()
	Effects.sound("boom", 0.8, 0.9)
	Effects.shake(2, 0.8)
end

handlers.hazardWarn = function()
	Effects.sound("ping", 0.5, 0.5)
	Effects.shake(0.8, 0.9)
end

handlers.hazardHit = function()
	Effects.sound("boom", 0.8, 0.8)
	Effects.shake(3, 0.6)
end

handlers.suffocating = function()
	Effects.shake(1.2, 0.6)
end

handlers.hazardTick = function()
	-- Persistent zones tick several times a second. Anything louder than this
	-- turns standing in gas into a jackhammer.
	Effects.shake(0.35, 0.15)
end

handlers.lift = function()
	Effects.sound("whoosh", 0.6, 0.8)
end

handlers.lifted = function()
	Effects.sound("ping", 0.6, 1.2)
end

function Effects.start()
	Net.listen("Effect", function(kind, payload)
		local handler = handlers[kind]
		if handler then
			local ok, err = pcall(handler, payload or {})
			if not ok then
				warn("DeepRush: effect " .. tostring(kind) .. " failed: " .. tostring(err))
			end
		end
	end)

	-- Camera shake, applied on top of whatever the camera is already doing.
	RunService.RenderStepped:Connect(function(delta)
		if os.clock() > shakeUntil then
			shakeStrength = math.max(0, shakeStrength - delta * 8)
			if shakeStrength <= 0.01 then
				return
			end
		end

		local offset = Vector3.new(
			(math.random() - 0.5) * shakeStrength,
			(math.random() - 0.5) * shakeStrength,
			0
		) * 0.35

		camera.CFrame = camera.CFrame * CFrame.new(offset)
	end)
end

return Effects
