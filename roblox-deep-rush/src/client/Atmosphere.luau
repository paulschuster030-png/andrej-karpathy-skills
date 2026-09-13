--!nonstrict
--[[
	Atmosphere.luau — what depth sounds and looks like.

	The world geometry says where you are; this says how far down. Three
	things move together as you descend:

	  LIGHT     fog closes in, ambient drops, the tint cools then goes wrong.
	            By the Abyss you can see about forty studs, which is what makes
	            a headlamp upgrade feel like a purchase rather than a stat.
	  SOUND     four ambience layers cross-fade by depth. Nothing switches;
	            everything bleeds, so the change is felt rather than noticed.
	  TENSION   a separate layer that rises when oxygen is low or a hazard has
	            you. It is the only audio that reacts to state rather than
	            position, which is why it reads as danger.

	All of it runs on the client. The server has no opinion about your fog.
]]

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AudioConfig = require(Shared.Config.Audio)
local Layers = require(Shared.Config.Layers)
local Net = require(Shared.Net)

local State = require(script.Parent.State)

local Atmosphere = {}

local layers: { [string]: Sound } = {}
local tension: Sound
local colorCorrection: ColorCorrectionEffect
local bloom: BloomEffect
local depthOfField: DepthOfFieldEffect
local sunRays: SunRaysEffect
local haze

local tensionTarget = 0
local hazardUntil = 0

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

--- 0 at `from`, 1 at `to`, and it fades back out past the band so a layer
--- does not stack forever once you are below it.
local function bandVolume(depth: number, band): number
	if depth < band.from then
		return 0
	end
	local span = math.max(band.to - band.from, 1)
	local ramp = math.clamp((depth - band.from) / (span * 0.35), 0, 1)
	local falloff = depth > band.to and math.clamp(1 - (depth - band.to) / (span * 0.5), 0, 1) or 1
	return ramp * falloff
end

local function buildAudio()
	local group = Instance.new("SoundGroup")
	group.Name = "DeepRushAmbience"
	group.Volume = 1
	group.Parent = SoundService

	for _, band in ipairs(AudioConfig.Ambience) do
		local custom = AudioConfig.source(band.custom)
		local sound = Instance.new("Sound")
		sound.Name = "Ambience_" .. band.id
		sound.SoundId = custom ~= "" and custom or AudioConfig.Builtin.rumble
		-- Built-ins are short one-shots; looping them at low pitch is what
		-- turns a snare of a clip into a bed. A real uploaded loop plays at
		-- its own pitch instead.
		sound.PlaybackSpeed = custom ~= "" and 1 or band.pitch
		sound.Looped = true
		sound.Volume = 0
		sound.SoundGroup = group
		sound.Parent = SoundService
		sound:Play()
		layers[band.id] = sound
	end

	tension = Instance.new("Sound")
	tension.Name = "Tension"
	tension.SoundId = AudioConfig.Builtin.wind
	tension.PlaybackSpeed = 0.45
	tension.Looped = true
	tension.Volume = 0
	tension.SoundGroup = group
	tension.Parent = SoundService
	tension:Play()

	local music = AudioConfig.source("music")
	if music ~= "" then
		local track = Instance.new("Sound")
		track.Name = "Music"
		track.SoundId = music
		track.Looped = true
		track.Volume = AudioConfig.MusicVolume
		track.SoundGroup = group
		track.Parent = SoundService
		track:Play()
	end
end

local function buildLighting()
	-- Future is what makes the ore look like ore. It is the only lighting
	-- technology with real shadows from point lights and specular response to
	-- materials, and this whole game is point lights inside rock: a gold seam
	-- under Voxel is a yellow box, under Future it has a highlight that moves
	-- as you walk past it.
	Lighting.Technology = Enum.Technology.Future
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.6

	colorCorrection = Lighting:FindFirstChild("DeepRushGrade") or Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "DeepRushGrade"
	colorCorrection.Parent = Lighting

	-- Threshold deliberately high. Bloom at a low threshold smears the whole
	-- screen and reads as a cheap filter; up here only genuinely bright
	-- things glow, which in this game means neon ore, lift pads and the
	-- vault. The glow then means something.
	bloom = Lighting:FindFirstChild("DeepRushBloom") or Instance.new("BloomEffect")
	bloom.Name = "DeepRushBloom"
	bloom.Intensity = 0.9
	bloom.Size = 22
	bloom.Threshold = 1.35
	bloom.Parent = Lighting

	-- Focus sits just past mining range, so the rock in your hands is sharp
	-- and the shaft below you falls away. It is also the cheapest way to make
	-- a 3,000m hole read as deep rather than tall.
	depthOfField = Lighting:FindFirstChild("DeepRushDof") or Instance.new("DepthOfFieldEffect")
	depthOfField.Name = "DeepRushDof"
	depthOfField.FarIntensity = 0.35
	depthOfField.FocusDistance = 28
	depthOfField.InFocusRadius = 42
	depthOfField.NearIntensity = 0
	depthOfField.Parent = Lighting

	-- Surface only: it fades out with the sunlight as you descend.
	sunRays = Lighting:FindFirstChild("DeepRushSun") or Instance.new("SunRaysEffect")
	sunRays.Name = "DeepRushSun"
	sunRays.Intensity = 0.16
	sunRays.Spread = 0.9
	sunRays.Parent = Lighting

	haze = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	haze.Density = 0.3
	haze.Offset = 0.2
	haze.Glare = 0.1
	haze.Haze = 1
	haze.Parent = Lighting
end

local function step(delta: number)
	local depth = State.data.depth or 0
	local layer = Layers.at(depth)
	local blend = math.clamp(delta * 1.8, 0, 1)

	-- Lighting follows the layer the player is actually in.
	local ambient = Color3.fromRGB(layer.ambient[1], layer.ambient[2], layer.ambient[3])
	Lighting.Ambient = Lighting.Ambient:Lerp(ambient, blend)
	Lighting.OutdoorAmbient = Lighting.OutdoorAmbient:Lerp(ambient, blend)
	Lighting.FogEnd = lerp(Lighting.FogEnd, layer.fog, blend)
	Lighting.FogStart = lerp(Lighting.FogStart, layer.fog * 0.12, blend)

	local rock = Color3.fromRGB(layer.rock[1], layer.rock[2], layer.rock[3])
	Lighting.FogColor = Lighting.FogColor:Lerp(rock:Lerp(Color3.fromRGB(0, 0, 0), 0.72), blend)
	Lighting.Brightness = lerp(Lighting.Brightness, math.max(0.35, 2 - depth / 700), blend)

	-- The deep is desaturated and cold; the surface is not.
	local descent = math.clamp(depth / 1800, 0, 1)
	colorCorrection.Saturation = lerp(colorCorrection.Saturation, -0.12 - descent * 0.28, blend)
	colorCorrection.Contrast = lerp(colorCorrection.Contrast, 0.08 + descent * 0.22, blend)
	colorCorrection.TintColor = colorCorrection.TintColor:Lerp(
		Color3.fromRGB(255, 250, 240):Lerp(Color3.fromRGB(170, 190, 235), descent),
		blend
	)
	haze.Density = lerp(haze.Density, 0.3 + descent * 0.32, blend)

	-- The post stack follows the same descent curve as the colour grade: the
	-- deeper you are the more the light you carry is the only light there is,
	-- so bloom climbs, the far field blurs out, and the sun stops existing.
	bloom.Intensity = lerp(bloom.Intensity, 0.9 + descent * 1.5, blend)
	depthOfField.FarIntensity = lerp(depthOfField.FarIntensity, 0.35 + descent * 0.35, blend)
	depthOfField.InFocusRadius = lerp(depthOfField.InFocusRadius, 42 - descent * 20, blend)
	sunRays.Intensity = lerp(sunRays.Intensity, math.max(0, 0.16 * (1 - depth / 220)), blend)

	-- Ambience.
	for _, band in ipairs(AudioConfig.Ambience) do
		local sound = layers[band.id]
		if sound then
			sound.Volume = lerp(sound.Volume, bandVolume(depth, band) * band.volume, blend)
		end
	end

	-- Tension: low oxygen, or a hazard within the last few seconds.
	local oxygenRatio = (State.data.oxygen or 60) / math.max(State.data.oxygenMax or 60, 1)
	local fromOxygen = oxygenRatio < 0.35 and (1 - oxygenRatio / 0.35) or 0
	local fromHazard = os.clock() < hazardUntil and 1 or 0
	tensionTarget = math.max(fromOxygen, fromHazard)
	tension.Volume = lerp(tension.Volume, tensionTarget * 0.5, blend * 0.8)
	tension.PlaybackSpeed = lerp(tension.PlaybackSpeed, 0.35 + tensionTarget * 0.5, blend)
end

function Atmosphere.start()
	buildAudio()
	buildLighting()

	Net.listen("Effect", function(kind)
		if kind == "hazardWarn" or kind == "hazardHit" or kind == "hazardTick" or kind == "suffocating" then
			hazardUntil = os.clock() + 3
		end
	end)

	RunService.Heartbeat:Connect(step)
end

return Atmosphere
