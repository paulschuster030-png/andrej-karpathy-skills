--!nonstrict
--[[
	Upgrades.luau — the shop.

	Server recomputes the price from the player's CURRENT level on every
	purchase rather than trusting a price the client sent. That one rule kills
	the most common Roblox economy exploit outright.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.Upgrades)
local Format = require(Shared.Format)
local Net = require(Shared.Net)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)
local Quests = require(script.Parent.Quests)

local Upgrades = {}

function Upgrades.buy(player: Player, upgradeId: string)
	local profile = Data.get(player)
	local upgrade = UpgradeConfig.ById[upgradeId]
	if not profile or not upgrade then
		return
	end

	local level = profile.upgrades[upgradeId] or 0
	if level >= upgrade.maxLevel then
		Feedback.toast(player, { title = "MAXED", body = upgrade.name .. " is fully upgraded.", kind = "error" })
		return
	end

	local cost = UpgradeConfig.cost(upgradeId, level)
	if not Economy.spend(player, cost) then
		Feedback.toast(player, {
			title = "NOT ENOUGH CASH",
			body = `{upgrade.name} Lv{level + 1} costs {Format.short(cost)}.`,
			kind = "error",
		})
		return
	end

	profile.upgrades[upgradeId] = level + 1
	Data.push(player, { upgrades = { [upgradeId] = level + 1 } })

	Quests.record(player, "upgrade", 1)
	Economy.applyCharacter(player)

	Feedback.effect(player, "upgrade", { id = upgradeId })
	Feedback.toast(player, {
		title = `{upgrade.name} Lv{level + 1}`,
		body = upgrade.format(level + 1),
		kind = "upgrade",
	})
end

function Upgrades.start()
	Net.on("BuyUpgrade", function(player, upgradeId)
		if type(upgradeId) == "string" then
			Upgrades.buy(player, upgradeId)
		end
	end)
end

return Upgrades
