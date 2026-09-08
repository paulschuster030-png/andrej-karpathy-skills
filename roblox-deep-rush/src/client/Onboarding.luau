--!nonstrict
--[[
	Onboarding.luau — the first two minutes.

	Roblox decides whether a game lives on D1 retention, and D1 is mostly
	settled before a new player has been in the world for three minutes. So a
	first-timer is never allowed to wonder what to do: there is one objective
	on screen and one waypoint in the world pointing at it, and both follow
	the server's onboarding quest chain rather than a separate script that
	could drift out of sync with it.

	It removes itself the moment the chain is done. A tutorial that overstays
	is worse than no tutorial.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Onboarding = {}

local player = Players.LocalPlayer
local theme = Ui.THEME

local banner: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local waypoint: BasePart
local waypointLabel: TextLabel

--- Where the player should be looking right now, per onboarding step.
local WAYPOINTS = {
	ob_mine = { kind = "shaft", text = "▼ JUMP IN & MINE" },
	ob_bank = { kind = "vault", text = "▼ BANK HERE" },
	ob_upgrade = { kind = "none" },
	ob_depth = { kind = "shaft", text = "▼ GO DEEPER" },
	ob_rare = { kind = "shaft", text = "▼ DIG DEEPER FOR RARES" },
	ob_deep = { kind = "shaft", text = "▼ FILL YOUR HOLD" },
}

local vaultPart: BasePart? = nil

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function findVault()
	if vaultPart and vaultPart.Parent then
		return vaultPart
	end
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Vault") then
			vaultPart = descendant
			return vaultPart
		end
	end
	return nil
end

--- Nearest lift pad, used once the hold is full and the player is deep.
local function nearestLift()
	local root = rootPart()
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, 260)) do
		if part:GetAttribute("LiftPad") then
			local distance = (part.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

local function currentStep()
	local board = State.data.questBoard
	return board and board.onboarding or nil
end

local function update()
	local step = currentStep()

	if not step then
		banner.Visible = false
		waypoint.Transparency = 1
		waypointLabel.Visible = false
		return
	end

	banner.Visible = true
	titleLabel.Text = `STEP {step.index}/{step.total} — {step.name}`
	bodyLabel.Text = `{step.desc}   ({Format.short(step.progress)}/{Format.short(step.target)})`
	if step.progress >= step.target then
		bodyLabel.Text = "DONE — open 📋 Tasks to claim your reward"
		bodyLabel.TextColor3 = theme.green
	else
		bodyLabel.TextColor3 = theme.muted
	end

	-- Waypoint: a full hold overrides the scripted step, because "get back
	-- up" is genuinely the right advice at that moment.
	local root = rootPart()
	if not root then
		return
	end

	local cargoFull = (State.data.cargo.count or 0) >= (State.data.cargo.capacity or 8)
	local depth = State.data.depth or 0

	local targetPosition, text
	if cargoFull and depth > 20 then
		local lift = nearestLift()
		if lift then
			targetPosition, text = lift.Position + Vector3.new(0, 6, 0), "▼ RIDE UP"
		end
	end

	if not targetPosition then
		local config = WAYPOINTS[step.id] or { kind = "none" }
		if config.kind == "vault" then
			local vault = findVault()
			if vault then
				targetPosition, text = vault.Position + Vector3.new(0, 12, 0), config.text
			end
		elseif config.kind == "shaft" and depth < 12 then
			targetPosition, text = Vector3.new(0, 6, 0), config.text
		end
	end

	if targetPosition then
		waypoint.Position = targetPosition
		waypoint.Transparency = 1
		waypointLabel.Text = text or "▼"
		waypointLabel.Visible = true
	else
		waypointLabel.Visible = false
	end
end

function Onboarding.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeepRushOnboarding"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")

	banner = Ui.frame({
		parent = gui,
		size = UDim2.fromOffset(420, 62),
		position = UDim2.new(0.5, 0, 0, 142),
		anchor = Vector2.new(0.5, 0),
		color = theme.panel,
		transparency = 0.1,
		visible = false,
	})
	Ui.stroke(banner, theme.cyan, 2)
	Ui.padding(banner, 8)

	titleLabel = Ui.text({
		parent = banner,
		size = UDim2.new(1, 0, 0, 22),
		text = "",
		color = theme.cyan,
		scaled = false,
		textSize = 16,
	})

	bodyLabel = Ui.text({
		parent = banner,
		size = UDim2.new(1, 0, 0, 22),
		position = UDim2.fromOffset(0, 22),
		text = "",
		color = theme.muted,
		scaled = false,
		textSize = 14,
	})

	waypoint = Instance.new("Part")
	waypoint.Name = "OnboardingWaypoint"
	waypoint.Size = Vector3.new(1, 1, 1)
	waypoint.Anchored = true
	waypoint.CanCollide = false
	waypoint.Transparency = 1
	waypoint.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(14, 4)
	billboard.AlwaysOnTop = true
	billboard.Parent = waypoint

	waypointLabel = Instance.new("TextLabel")
	waypointLabel.Size = UDim2.fromScale(1, 1)
	waypointLabel.BackgroundTransparency = 1
	waypointLabel.Font = Enum.Font.GothamBlack
	waypointLabel.TextColor3 = theme.cyan
	waypointLabel.TextScaled = true
	waypointLabel.TextStrokeTransparency = 0.3
	waypointLabel.Visible = false
	waypointLabel.Parent = billboard

	State.changed:connect(update)

	-- The waypoint tracks a moving player, so it needs its own slow tick
	-- rather than only updating when state changes.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(update)
			if not ok then
				warn("DeepRush: onboarding update failed: " .. tostring(err))
			end
		end
	end)
end

return Onboarding
