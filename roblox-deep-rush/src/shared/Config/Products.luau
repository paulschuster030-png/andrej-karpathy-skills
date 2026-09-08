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

Products.GamepassById = {}
for _, pass in ipairs(Products.Gamepasses) do
	Products.GamepassById[pass.id] = pass
end

Products.DevProductById = {}
for _, product in ipairs(Products.DevProducts) do
	Products.DevProductById[product.id] = product
end

--- Reverse lookup used by the receipt handler, built lazily so re-configured
--- asset ids during a live session still resolve.
function Products.byAssetId(assetId: number)
	for _, product in ipairs(Products.DevProducts) do
		if product.assetId == assetId and assetId ~= 0 then
			return product
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
