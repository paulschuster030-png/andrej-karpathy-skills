--!nonstrict
--[[
	AntiCheat.luau — movement sanity only.

	Deliberately narrow. The real protection in this game is that the server
	owns every decision that matters: what an ore is worth, whether a node
	exists, whether you are near the vault, what an upgrade costs. This module
	only covers the one thing the client legitimately controls — its own
	character position.

	Vertical movement is exempt. Players fall 9,000 studs down an open shaft,
	and any speed threshold that allows that also allows every vertical
	exploit, so there is no honest check to make there.
]]

local Players = game:GetService("Players")

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)

local AntiCheat = {}

local HORIZONTAL_TOLERANCE = 2.2 -- multiple of the player's legal walkspeed
local TELEPORT_THRESHOLD = 220 -- studs in one sample: never legitimate
local SAMPLE_RATE = 0.5

local lastKnown: { [Player]: Vector3 } = {}
local strikes: { [Player]: number } = {}

local function rootOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function sample()
	for _, player in ipairs(Players:GetPlayers()) do
		local session = Data.session(player)
		local root = rootOf(player)

		if not root or not session then
			lastKnown[player] = nil
		elseif session.lifting then
			-- The server teleports players during a lift ride; do not flag
			-- the movement we caused ourselves.
			lastKnown[player] = root.Position
		else
			local previous = lastKnown[player]
			lastKnown[player] = root.Position

			if previous then
				local delta = root.Position - previous
				local horizontal = Vector2.new(delta.X, delta.Z).Magnitude
				local allowed = Economy.walkSpeed(player) * SAMPLE_RATE * HORIZONTAL_TOLERANCE + 8

				if horizontal > TELEPORT_THRESHOLD or horizontal > allowed then
					strikes[player] = (strikes[player] or 0) + 1
					-- Three strikes before acting: a lag spike looks exactly
					-- like a small teleport, and snapping a laggy player back
					-- is worse than letting one cheat through.
					if strikes[player] >= 3 then
						strikes[player] = 0
						root.CFrame = CFrame.new(previous)
						lastKnown[player] = previous
					end
				else
					strikes[player] = 0
				end
			end
		end
	end
end

function AntiCheat.start()
	task.spawn(function()
		while true do
			task.wait(SAMPLE_RATE)
			sample()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastKnown[player] = nil
		strikes[player] = nil
	end)
end

return AntiCheat
