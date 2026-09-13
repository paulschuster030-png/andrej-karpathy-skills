--!nonstrict
--[[
	Surface.luau — getting out, and cashing in.

	These two live together because to a player they are one thought: "I am
	full, get me up and pay me."

	The streak bonus only counts trips that went past Config.DeepBankDepth.
	Without that clause the optimal play is to hover at 10m banking single
	rocks, which is both boring and unbeatable — a classic idle-game exploit
	that we design out rather than patch later.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Format = require(Shared.Format)
local Ranks = require(Shared.Config.Ranks)
local Net = require(Shared.Net)

local Cargo = require(script.Parent.Cargo)
local Contracts = require(script.Parent.Contracts)
local ContractConfig = require(Shared.Config.Contracts)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)
local Quests = require(script.Parent.Quests)
local World = require(script.Parent.World)

local Surface = {}

local LIFT_CHANNEL_SECONDS = 4

local function rootOf(player: Player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function atVault(player: Player): boolean
	local root = rootOf(player)
	if not root or not World.vaultPosition then
		return false
	end
	return (root.Position - World.vaultPosition).Magnitude <= Config.BankRadius
end

function Surface.deposit(player: Player)
	local profile = Data.get(player)
	local session = Data.session(player)
	if not profile or not session then
		return
	end

	if not atVault(player) then
		Feedback.toast(player, { title = "NOT AT THE VAULT", body = "Ride a lift up to the surface.", kind = "error" })
		return
	end

	local cargo = Cargo.get(player)
	if not cargo or #cargo.items == 0 then
		Feedback.toast(player, { title = "NOTHING TO BANK", body = "Go get some rocks.", kind = "error" })
		return
	end

	local deepEnough = (session.runDepth or 0) >= Config.DeepBankDepth
	if deepEnough then
		session.bankStreak = math.min((session.bankStreak or 0) + 1, math.floor(Config.BankStreakMax / Config.BankStreakStep))
	else
		session.bankStreak = 0
	end

	local streakBonus = math.min((session.bankStreak or 0) * Config.BankStreakStep, Config.BankStreakMax)
	local multiplier = Economy.cashMultiplier(player)
	local _, rawValue = Cargo.clear(player)
	local payout = math.floor(rawValue * multiplier * (1 + streakBonus))

	Economy.addCash(player, payout)

	local rankBefore = select(2, Ranks.at(profile.stats.bankedTotal))
	profile.stats.bankedTotal += payout
	profile.stats.bestSingleBank = math.max(profile.stats.bestSingleBank, payout)
	session.cleanBanks = (session.cleanBanks or 0) + 1
	session.runDepth = 0
	session.lastBank = os.time()

	Data.push(player, {
		stats = { bankedTotal = profile.stats.bankedTotal, bestSingleBank = profile.stats.bestSingleBank },
		streak = session.bankStreak,
	})

	Quests.record(player, "bank", payout)
	Quests.record(player, "bank_runs", 1)
	Quests.record(player, "bank_single", payout, "max")
	Quests.record(player, "clean_banks", session.cleanBanks, "set")
	-- Only trips that actually went down count, matching the streak rule.
	if deepEnough then
		Contracts.award(player, ContractConfig.Points.perDeepBank)
	end

	-- Feedback first, and the leaderboard write is allowed to fail.
	--
	-- This order is not cosmetic. Net wraps every handler in pcall, so when
	-- the leaderboard threw — as it does whenever the DataStore is unhappy —
	-- the player had already been paid and then got no toast, no sound and no
	-- effect. Banking looked broken while working perfectly.
	Feedback.effect(player, "bank", { amount = payout, streak = streakBonus })
	Feedback.toast(player, {
		title = "+" .. Format.short(payout),
		body = streakBonus > 0
			and `Banked. x{string.format("%.2f", multiplier)} multiplier, +{math.floor(streakBonus * 100)}% streak.`
			or `Banked. x{string.format("%.2f", multiplier)} multiplier.`,
		kind = "cash",
	})

	-- Rank up. Lifetime banked is the only figure that never falls, so this
	-- fires perhaps ten times in a player's whole history — which is exactly
	-- why it gets the reveal card and a line to the whole server rather than
	-- a toast nobody reads.
	local rank, rankAfter = Ranks.at(profile.stats.bankedTotal)
	if rankAfter > rankBefore then
		Feedback.reveal(player, {
			title = "RANK UP",
			name = `{rank.icon} {string.upper(rank.name)}`,
			body = `Lifetime banked {Format.short(profile.stats.bankedTotal)}. Everyone can see it over your head.`,
			kind = "rank",
		})
		Feedback.announce(
			`{rank.icon} RANK UP`,
			`{player.DisplayName} reached {rank.name}.`,
			rank.color
		)
		require(script.Parent.Cosmetics).apply(player)
	end

	local ok, err = pcall(function()
		require(script.Parent.Leaderboards).submit(player, payout)
	end)
	if not ok then
		warn("DeepRush: leaderboard submit failed: " .. tostring(err))
	end
end

--- The way out that always exists.
---
--- Lift pads are on every chunk now, but "every chunk" is not "everywhere":
--- a player can end up wedged, or on a ledge with nothing below, or simply
--- lost. A mining game where getting stuck is possible is a mining game where
--- someone loses an hour of cargo to level geometry.
---
--- It is deliberately worse than a lift: three times the channel, and any real
--- movement cancels it. That keeps the pads worth finding.
function Surface.emergencyAscent(player: Player)
	local session = Data.session(player)
	local root = rootOf(player)
	if not session or not root or session.lifting then
		return
	end

	if (session.depth or 0) < 20 then
		Feedback.toast(player, {
			title = "YOU ARE ALREADY UP",
			body = "Emergency ascent only works underground.",
			kind = "error",
		})
		return
	end

	session.lifting = true
	local origin = root.Position
	local seconds = Config.EmergencyAscentSeconds

	Feedback.effect(player, "lift", { duration = seconds })
	Feedback.toast(player, {
		title = "EMERGENCY ASCENT",
		body = `Hold still for {seconds}s. Moving cancels it.`,
		kind = "quest",
		duration = seconds,
	})

	task.spawn(function()
		local elapsed = 0
		while elapsed < seconds do
			task.wait(0.5)
			elapsed += 0.5

			local current = rootOf(player)
			if not player.Parent or not current then
				session.lifting = false
				return
			end

			if (current.Position - origin).Magnitude > Config.EmergencyAscentDrift then
				session.lifting = false
				Feedback.toast(player, {
					title = "ASCENT CANCELLED",
					body = "You moved. Stand still and try again.",
					kind = "error",
				})
				return
			end
		end

		session.lifting = false
		local current = rootOf(player)
		if not current or not World.spawnPosition then
			return
		end
		current.CFrame = CFrame.new(World.spawnPosition + Vector3.new(0, 3, 0))
		session.depth = 0
		Feedback.effect(player, "lifted", {})
	end)
end

--- Ride a lift pad back to the surface. The channel time is the real cost of
--- being deep; the Express Lift pass removes it, which is exactly the kind
--- of thing a pass should sell — time, not power.
function Surface.useLift(player: Player)
	local session = Data.session(player)
	local root = rootOf(player)
	if not session or not root or session.lifting then
		return
	end

	-- Must actually be standing on a pad.
	local onPad = false
	for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, 12)) do
		if part:GetAttribute("LiftPad") then
			onPad = true
			break
		end
	end

	if not onPad then
		Feedback.toast(player, { title = "NO LIFT HERE", body = "Find a green lift pad.", kind = "error" })
		return
	end

	local instant = Economy.hasGamepass(player, "fastlift")
	local channel = instant and 0 or LIFT_CHANNEL_SECONDS

	session.lifting = true
	Feedback.effect(player, "lift", { duration = channel })

	task.delay(channel, function()
		session.lifting = false
		local currentRoot = rootOf(player)
		if not currentRoot or not World.spawnPosition then
			return
		end
		currentRoot.CFrame = CFrame.new(World.spawnPosition + Vector3.new(0, 3, 0))
		session.depth = 0
		Feedback.effect(player, "lifted", {})
	end)
end

function Surface.start()
	Net.on("Bank", function(player)
		Surface.deposit(player)
	end)

	Net.on("UseLift", function(player)
		Surface.useLift(player)
	end)

	Net.on("EmergencyAscent", function(player)
		Surface.emergencyAscent(player)
	end)

	-- Track the deepest point of the current trip for the streak rule.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local session = Data.session(player)
				if session then
					session.runDepth = math.max(session.runDepth or 0, session.depth or 0)
				end
			end
		end
	end)
end

return Surface
