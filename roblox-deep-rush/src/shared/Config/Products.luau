--!nonstrict
--[[
	Products.luau — monetisation.

	IDs are 0 until you create the passes and products in the Roblox creator
	dashboard and paste the real numbers in. Everything degrades gracefully:
	an unconfigured product simply does not appear in the shop, and the game
	is fully completable without spending a single Robux.

	Design rule we hold to: passes buy SPEED and CONVENIENCE, never exclusive
	content and never protection from other players' actions. A paid player
	gets there sooner; nobody gets there only by paying.
]]

local Products = {}

Products.Gamepasses = {
	{
		id = "cash2x",
		assetId = 0,
		name = "2x Cash",
		desc = "Every deposit pays double. Forever.",
		icon = "💰",
		apply = { cashMultiplier = 2 },
	},
	{
		id = "luck2x",
		assetId = 0,
		name = "2x Luck",
		desc = "Doubles your roll luck on every swing.",
		icon = "🍀",
		apply = { luckMultiplier = 2 },
	},
	{
		id = "bigpack",
		assetId = 0,
		name = "+25 Cargo",
		desc = "A much bigger hold. Fewer trips, bigger hauls.",
		icon = "🎒",
		apply = { capacity = 25 },
	},
	{
		id = "autodrill",
		assetId = 0,
		name = "Auto Drill",
		desc = "Hold to keep mining the nearest node without tapping.",
		icon = "🤖",
		apply = { autoMine = true },
	},
	{
		id = "fastlift",
		assetId = 0,
		name = "Express Lift",
		desc = "Instant ride back to the surface from any depth.",
		icon = "🛗",
		apply = { fastLift = true },
	},
	{
		id = "vip",
		assetId = 0,
		name = "VIP Miner",
		desc = "+50% cash, +25% luck, a daily bonus and a VIP tag.",
		icon = "👑",
		apply = { cashMultiplier = 1.5, luckMultiplier = 1.25, vip = true },
	},
}

Products.DevProducts = {
	{ id = "cash_small", assetId = 0, name = "Cash Crate", desc = "A quick top-up.", icon = "📦", grant = { cashOfBest = 0.25 } },
	{ id = "cash_large", assetId = 0, name = "Cash Vault", desc = "A serious top-up.", icon = "🏦", grant = { cashOfBest = 1.5 } },
	{ id = "luck_potion", assetId = 0, name = "Luck Potion", desc = "3x luck for 10 minutes.", icon = "🧪", grant = { luckMultiplier = 3, minutes = 10 } },
	{ id = "rift_key", assetId = 0, name = "Rift Key", desc = "Open a private Rift Surge right where you stand.", icon = "🗝️", grant = { personalRift = 90 } },
	{ id = "revive", assetId = 0, name = "Cargo Insurance", desc = "Recover the cargo you just lost.", icon = "🛟", grant = { restoreCargo = true } },
}

--- One cheap, rotating product per day.
---
--- This exists because of a specific ranking signal: Roblox counts "7 day
--- spend days per user" separately from "7 day Robux spent per user". Five
--- small purchases on five days are worth more to discovery than one large
--- purchase on one day — and they are also friendlier to a player's wallet
--- than a single expensive pass. Keep these cheap and genuinely useful.
Products.DailyDeals = {
	{ id = "deal_luck", assetId = 0, name = "Shift Luck", desc = "2x luck for 20 minutes.", icon = "🍀", robux = 25, grant = { luckMultiplier = 2, minutes = 20 } },
	{ id = "deal_cash", assetId = 0, name = "Shift Bonus", desc = "A cash top-up scaled to your best haul.", icon = "💰", robux = 29, grant = { cashOfBest = 0.6 } },
	{ id = "deal_rift", assetId = 0, name = "Pocket Rift", desc = "60 seconds of private rift, right where you stand.", icon = "🗝️", robux = 39, grant = { personalRift = 60 } },
	{ id = "deal_air", assetId = 0, name = "Deep Lungs", desc = "Double air for 30 minutes.", icon = "🫁", robux = 25, grant = { oxygenMultiplier = 2, minutes = 30 } },
	{ id = "deal_crew", assetId = 0, name = "Crew Rations", desc = "Your whole crew gets 2x cash for 15 minutes.", icon = "🤝", robux = 45, grant = { crewCash = 2, minutes = 15 } },
	{ id = "deal_codex", assetId = 0, name = "Surveyor's Eye", desc = "3x luck for 10 minutes. Best odds in the game.", icon = "👁️", robux = 49, grant = { luckMultiplier = 3, minutes = 10 } },
}

--- Deterministic per UTC day, so every player sees the same deal and it is
--- obvious the offer is a rotation rather than a targeted price.
function Products.dealOfTheDay()
	local day = os.date("!*t")
	local index = ((day.year * 366 + day.yday) % #Products.DailyDeals) + 1
	return Products.DailyDeals[index]
end

--- Rewarded Video, opened to all eligible creators in February 2026 and now
--- worth roughly 8-15% of revenue for games that use it well.
---
--- Eligibility is not automatic: the experience needs 2FA, an ID-verified
--- 13+ owner, public status and at least 2,000 unique visitors per month. So
--- this stays switched off until you have those, and the button simply never
--- appears until Roblox reports an ad is available.
---
--- AdService builds the reward from a Developer Product, so create one named
--- after the boost and paste its id here. Ad rewards may never be Robux.
Products.RewardedVideo = {
	devProductId = 0,
	rewardMinutes = 10,
	rewardLuckMultiplier = 2,
	cooldownSeconds = 3600,
}

Products.GamepassById = {}
for _, pass in ipairs(Products.Gamepasses) do
	Products.GamepassById[pass.id] = pass
end

Products.DevProductById = {}
for _, product in ipairs(Products.DevProducts) do
	Products.DevProductById[product.id] = product
end
for _, product in ipairs(Products.DailyDeals) do
	Products.DevProductById[product.id] = product
end

--- Reverse lookup used by the receipt handler, built lazily so re-configured
--- asset ids during a live session still resolve.
function Products.byAssetId(assetId: number)
	if assetId == 0 then
		return nil
	end
	for _, list in ipairs({ Products.DevProducts, Products.DailyDeals }) do
		for _, product in ipairs(list) do
			if product.assetId == assetId then
				return product
			end
		end
	end
	return nil
end

function Products.configuredGamepasses()
	local out = {}
	for _, pass in ipairs(Products.Gamepasses) do
		if pass.assetId ~= 0 then
			table.insert(out, pass)
		end
	end
	return out
end

return Products
