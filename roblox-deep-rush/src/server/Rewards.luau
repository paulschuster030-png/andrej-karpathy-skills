--!nonstrict
--[[
	Rewards.luau — the two retention drips.

	LOGIN STREAK  escalating daily payout, day 7 is a real prize. Missing a
	              day drops you to day 1, which is the whole point.
	PLAYTIME      a chest every 10 minutes of session time. Cheap, but it
	              reliably converts a "one more run" into another 10 minutes.

	Both are pure gifts. Nothing here is gated behind a purchase, because a
	retention mechanic that costs Robux does not retain anybody.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Format = require(Shared.Format)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Rewards = {}

local STREAK_PAYOUT = { 1500, 3500, 7000, 14000, 28000, 60000, 150000 }

local function today(): string
	local now = os.date("!*t")
	return string.format("%d-%03d", now.year, now.yday)
end

local function yesterday(): string
	local now = os.date("!*t", os.time() - 86400)
	return string.format("%d-%03d", now.year, now.yday)
end

local function claimDaily(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end

	local day = today()
	if profile.rewards.lastLogin == day then
		return
	end

	profile.rewards.streak = (profile.rewards.lastLogin == yesterday()) and (profile.rewards.streak + 1) or 1
	profile.rewards.lastLogin = day

	local index = math.min(profile.rewards.streak, #STREAK_PAYOUT)
	local payout = STREAK_PAYOUT[index] * (1 + profile.rebirths * 0.5)
	payout = math.floor(payout)

	Economy.addCash(player, payout)
	Data.push(player, { rewards = Data.replace(table.clone(profile.rewards)) })

	Feedback.reveal(player, {
		title = `DAY {profile.rewards.streak} STREAK`,
		name = "+" .. Format.short(payout),
		tier = profile.rewards.streak >= 7 and "Legendary" or "Rare",
		body = profile.rewards.streak >= 7 and "Maximum streak. Come back tomorrow to hold it."
			or `Come back tomorrow for {Format.short(STREAK_PAYOUT[math.min(index + 1, #STREAK_PAYOUT)])}.`,
		kind = "streak",
	})
end

local function playtimeLoop()
	while true do
		task.wait(Config.PlaytimeRewardInterval)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = Data.get(player)
			local session = Data.session(player)
			if profile and session then
				profile.rewards.chests += 1
				local payout = math.floor(2500 * (1 + profile.rebirths) * (1 + profile.rewards.chests * 0.15))
				Economy.addCash(player, payout)
				Economy.addBuff(player, "luck", 1.5, 300)
				Data.push(player, { rewards = Data.replace(table.clone(profile.rewards)) })
				Feedback.toast(player, {
					title = "⏱️ PLAYTIME CHEST",
					body = `+{Format.short(payout)} and 1.5x luck for 5 minutes.`,
					kind = "cash",
					duration = 5,
				})
			end
		end
	end
end

function Rewards.start()
	Data.loaded:connect(function(player)
		task.delay(3, claimDaily, player)
	end)
	task.spawn(playtimeLoop)
end

return Rewards
