--!nonstrict
--[[
	Hazards.luau — why depth costs something.

	Two pressures, both scaling with the layer:
	  OXYGEN   a soft timer. It never kills you outright at first; it starts
	           chewing health, which gives you a chance to run for a lift.
	  EVENTS   cave-ins, gas, heat, the Hollow. Telegraphed one second before
	           they land, so a paying-attention player can react and a
	           tabbed-out one cannot.

	Everything here is resisted by the Coolant/Void drones, which is what
	makes a drone feel like equipment rather than a stat stick.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Layers = require(Shared.Config.Layers)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Hazards = {}

local SURFACE_DEPTH = 15 -- above this, you are breathing normally
local SUFFOCATION_DPS = 6

local HAZARD_TEXT = {
	cavein = { warn = "The ceiling is cracking...", hit = "CAVE-IN" },
	gas = { warn = "Something hisses nearby...", hit = "GAS POCKET" },
	heat = { warn = "The rock is glowing...", hit = "HEAT BURST" },
	freeze = { warn = "Your visor is frosting...", hit = "FLASH FREEZE" },
	hollow = { warn = "Something down here noticed you...", hit = "THE HOLLOW" },
	pressure = { warn = "Your suit is groaning...", hit = "PRESSURE CRUSH" },
	collapse = { warn = "Everything goes quiet...", hit = "COLLAPSE" },
}

local rng = Random.new(os.time() + 777)

local function humanoidOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function strike(player: Player, layer)
	local hazard = layer.hazard
	if not hazard then
		return
	end

	local text = HAZARD_TEXT[hazard.kind] or { warn = "Something is wrong...", hit = "HAZARD" }
	Feedback.effect(player, "hazardWarn", { kind = hazard.kind, text = text.warn })

	task.delay(1.1, function()
		local humanoid = humanoidOf(player)
		local session = Data.session(player)
		if not humanoid or humanoid.Health <= 0 or not session then
			return
		end
		-- Escaping the layer during the telegraph is a real out.
		if Layers.at(session.depth) ~= layer then
			return
		end

		local damage = hazard.damage * (1 - Economy.hazardResist(player))
		humanoid:TakeDamage(damage)
		Feedback.effect(player, "hazardHit", { kind = hazard.kind, text = text.hit, damage = damage })
	end)
end

local function tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local session = Data.session(player)
		local humanoid = humanoidOf(player)
		if session and humanoid and humanoid.Health > 0 then
			local depth = session.depth or 0
			local layer = Layers.at(depth)
			local maxOxygen = Economy.maxOxygen(player)

			if depth <= SURFACE_DEPTH then
				session.oxygen = math.min(maxOxygen, (session.oxygen or maxOxygen) + Config.OxygenRegenRate)
			else
				session.oxygen = (session.oxygen or maxOxygen) - layer.oxygenDrain
				if session.oxygen <= 0 then
					session.oxygen = 0
					humanoid:TakeDamage(SUFFOCATION_DPS * (1 - Economy.hazardResist(player)))
					Feedback.effect(player, "suffocating", {})
				end
			end

			Data.push(player, { oxygen = session.oxygen, oxygenMax = maxOxygen })

			-- Layer hazard roll. The per-layer chance is a per-encounter
			-- number, so we scale it down to a per-second probability.
			if layer.hazard and depth > SURFACE_DEPTH then
				if rng:NextNumber() < layer.hazard.chance * 0.05 then
					strike(player, layer)
				end
			end
		end
	end
end

function Hazards.start()
	task.spawn(function()
		while true do
			task.wait(Config.HazardTickRate)
			tick()
		end
	end)
end

return Hazards
