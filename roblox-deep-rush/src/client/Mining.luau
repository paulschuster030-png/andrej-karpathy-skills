--!nonstrict
--[[
	Mining.luau (client) — targeting and input.

	Targeting rule: among the nodes in reach, pick the one closest to where
	the camera is looking, not the one closest to the body. On a phone the
	camera IS the aim, and "nearest to me" picks the rock behind your feet.

	The client never decides that a rock broke. It asks, the server times the
	swing and answers. Everything here is presentation plus intent.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Net = require(Shared.Net)

local State = require(script.Parent.State)

local Mining = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local holding = false
local swingEndsAt = 0
local swingDuration = 0
local target = nil
local highlight: Highlight

local RETRY_GAP = 0.15 -- kept comfortably under the server's 12/s limit

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

--- Nodes in reach, scored by how close they are to the camera's aim.
local function findTarget()
	local root = rootPart()
	if not root then
		return nil
	end

	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector

	local best, bestScore = nil, -1
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, Config.MineReach)) do
		if part:GetAttribute("NodeId") and part.Transparency < 1 then
			local toPart = (part.Position - origin)
			local distance = toPart.Magnitude
			if distance > 0.1 then
				local alignment = toPart.Unit:Dot(look)
				-- Require it to be roughly in front, then prefer centred.
				if alignment > 0.35 then
					local score = alignment - (distance / Config.MineReach) * 0.25
					if score > bestScore then
						best, bestScore = part, score
					end
				end
			end
		end
	end

	return best
end

function Mining.setHolding(value: boolean)
	holding = value
end

function Mining.isHolding(): boolean
	return holding
end

function Mining.target()
	return target
end

--- 0..1 progress of the current swing, for the HUD ring.
function Mining.progress(): number
	if swingDuration <= 0 or os.clock() >= swingEndsAt then
		return 0
	end
	return 1 - ((swingEndsAt - os.clock()) / swingDuration)
end

local lastRequest = 0

local function tick()
	target = findTarget()

	if highlight then
		highlight.Adornee = target
		highlight.Enabled = target ~= nil
	end

	local autoMine = State.data.gamepasses and State.data.gamepasses.autodrill
	local wantsToMine = holding or autoMine == true

	if not wantsToMine or not target then
		return
	end

	-- A full hold means the server will refuse anyway; asking anyway just
	-- burns the rate limit and hides real requests behind it.
	local cargo = State.data.cargo
	if cargo and (cargo.count or 0) >= (cargo.capacity or math.huge) then
		return
	end
	if os.clock() < swingEndsAt then
		return
	end
	if os.clock() - lastRequest < RETRY_GAP then
		return
	end

	lastRequest = os.clock()
	Net.fire("Mine", target:GetAttribute("NodeId"))
end

function Mining.start()
	highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 220, 130)
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = Color3.fromRGB(255, 240, 190)
	highlight.OutlineTransparency = 0
	highlight.Enabled = false
	highlight.Parent = workspace

	-- The server tells us how long this swing takes; we render the bar.
	Net.listen("Effect", function(kind, payload)
		if kind == "swing" and payload and payload.duration then
			swingDuration = payload.duration
			swingEndsAt = os.clock() + payload.duration
		elseif kind == "mined" or kind == "full" then
			swingEndsAt = 0
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)

	-- Keyboard/gamepad alternative so the game is playable without aiming.
	ContextActionService:BindAction("DeepRushMine", function(_, inputState)
		holding = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonR2)

	RunService.Heartbeat:Connect(tick)

	-- Depth is reported on a timer rather than every frame: it drives the
	-- HUD, hazards and rift eligibility, none of which need 60Hz.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if rootPart() then
				Net.fire("ReportDepth")
			end
		end
	end)
end

return Mining
