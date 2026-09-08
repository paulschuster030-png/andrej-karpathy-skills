--!nonstrict
--[[
	Rebirth.luau — the prestige reset.

	Wipes cash and upgrades. Keeps everything that is identity: codex,
	drones, records, milestones, title. That split is deliberate — a reset
	that erased your collection would make players hesitate, and a prestige
	system only works if pressing the button is obviously correct.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RebirthConfig = require(Shared.Config.Rebirth)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)
local Quests = require(script.Parent.Quests)

local Rebirth = {}

function Rebirth.perform(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end

	local requirement = RebirthConfig.requirement(profile.rebirths)
	if profile.cash < requirement.cash then
		Feedback.toast(player, {
			title = "NOT YET",
			body = `Rebirth needs {Format.short(requirement.cash)} banked.`,
			kind = "error",
		})
		return
	end
	if profile.stats.bestDepth < requirement.depth then
		Feedback.toast(player, {
			title = "NOT DEEP ENOUGH",
			body = `Rebirth needs a record dive of {Format.depth(requirement.depth)}.`,
			kind = "error",
		})
		return
	end

	profile.rebirths += 1
	profile.cash = 0
	profile.upgrades = {}

	local bonuses = RebirthConfig.bonuses(profile.rebirths)
	local title = RebirthConfig.title(profile.rebirths)

	Data.push(player, {
		rebirths = profile.rebirths,
		cash = 0,
		upgrades = Data.replace({}),
	})

	Quests.record(player, "rebirths", profile.rebirths, "max")
	Economy.applyCharacter(player)

	Feedback.effect(player, "rebirth", { count = profile.rebirths })
	Feedback.reveal(player, {
		title = "REBIRTH " .. profile.rebirths,
		name = title,
		tier = "Legendary",
		body = `x{string.format("%.2f", bonuses.cashMultiplier)} cash · +{string.format("%.2f", bonuses.luck)} luck · +{bonuses.capacity} cargo`,
		kind = "rebirth",
	})
	Feedback.broadcast({
		title = "🔥 REBIRTH " .. profile.rebirths,
		body = `{player.DisplayName} is now a {title}.`,
		kind = "announce",
		duration = 5,
	})
end

function Rebirth.start()
	Net.on("Rebirth", function(player)
		Rebirth.perform(player)
	end)
end

return Rebirth
