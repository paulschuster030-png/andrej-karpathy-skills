--!nonstrict
--[[
	Rift.luau — the scheduled server-wide event.

	A Rift Surge opens at a random layer every ~12 minutes for 90 seconds:
	5x luck for anyone inside that depth band, plus the Rift-Touched mutation
	that exists nowhere else.

	It does three jobs at once, which is why it earns its complexity:
	  * it collapses a spread-out server into one place, which is what makes
	    a server feel alive (and produces the steal drama);
	  * it gives a bored player a reason to stay two more minutes;
	  * it is the only content that reliably pulls veterans back up out of
	    the deep layers to mix with new players.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Layers = require(Shared.Config.Layers)
local Net = require(Shared.Net)

local Data = require(script.Parent.Data)
local Feedback = require(script.Parent.Feedback)

local Rift = {}

Rift.active = nil -- { layer, minDepth, maxDepth, endsAt }

local rng = Random.new(os.time() + 991)

--- Is this player inside a rift right now — global or their own Rift Key?
function Rift.isActiveFor(player: Player): boolean
	local session = Data.session(player)
	if session and session.personalRift and session.personalRift > os.time() then
		return true
	end

	if not Rift.active or os.time() >= Rift.active.endsAt then
		return false
	end

	local depth = session and session.depth or 0
	return depth >= Rift.active.minDepth and depth <= Rift.active.maxDepth
end

function Rift.luckMultiplier(player: Player): number
	return Rift.isActiveFor(player) and Config.RiftLuckMultiplier or 1
end

function Rift.grantPersonal(player: Player, seconds: number)
	local session = Data.session(player)
	if not session then
		return
	end
	session.personalRift = os.time() + seconds
	Feedback.toast(player, {
		title = "PRIVATE RIFT OPEN",
		body = `{seconds}s of {Config.RiftLuckMultiplier}x luck, right here.`,
		kind = "rift",
	})
	Feedback.effect(player, "rift", { personal = true })
end

local function pickLayer()
	-- Weight toward layers people can actually reach: an event nobody can
	-- attend is worse than no event.
	local reachable = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Data.get(player)
		if profile then
			table.insert(reachable, Layers.maxSafeDepth(profile.rebirths))
		end
	end

	local ceiling = 260 -- default when the server is fresh
	for _, depth in ipairs(reachable) do
		ceiling = math.max(ceiling, depth)
	end

	local options = {}
	for _, layer in ipairs(Layers.List) do
		if layer.minDepth < ceiling then
			table.insert(options, layer)
		end
	end
	return options[rng:NextInteger(1, #options)]
end

local function openRift()
	local layer = pickLayer()
	Rift.active = {
		layerId = layer.id,
		layerName = layer.name,
		minDepth = layer.minDepth,
		maxDepth = layer.maxDepth,
		endsAt = os.time() + Config.RiftDuration,
	}

	Feedback.announce(
		"⚡ RIFT SURGE",
		`{layer.name} — {Config.RiftLuckMultiplier}x luck for {Config.RiftDuration}s. Get to {math.floor(layer.minDepth)}m.`,
		{ 255, 90, 200 }
	)
	Feedback.effectAll("rift", { layer = layer.id })
end

local function closeRift()
	if not Rift.active then
		return
	end
	Rift.active = nil
	Feedback.announce("RIFT CLOSED", "The pressure equalises. Next surge is coming.", { 150, 150, 170 })
end

function Rift.state()
	if not Rift.active then
		return { active = false, nextIn = Rift.nextAt and math.max(0, Rift.nextAt - os.time()) or 0 }
	end
	return {
		active = true,
		layer = Rift.active.layerName,
		minDepth = Rift.active.minDepth,
		maxDepth = Rift.active.maxDepth,
		remaining = math.max(0, Rift.active.endsAt - os.time()),
	}
end

function Rift.start()
	Rift.nextAt = os.time() + Config.FirstRiftDelay

	task.spawn(function()
		while true do
			task.wait(1)

			if Rift.active then
				if os.time() >= Rift.active.endsAt then
					closeRift()
					Rift.nextAt = os.time() + Config.RiftInterval + rng:NextInteger(-Config.RiftJitter, Config.RiftJitter)
				end
			elseif os.time() >= Rift.nextAt then
				openRift()
			end

			-- Clients render the countdown, so they need the tick.
			for _, player in ipairs(Players:GetPlayers()) do
				if Data.isReady(player) then
					local state = Rift.state()
					state.mine = Rift.isActiveFor(player)
					Net.to(player, "Rift", state)
				end
			end
		end
	end)
end

return Rift
