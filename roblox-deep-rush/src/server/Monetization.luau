--!nonstrict
--[[
	Monetization.luau — passes, products, and the receipt handler.

	Everything degrades to a no-op while assetId is 0, so the game is fully
	playable before you have created a single product in the dashboard.

	ProcessReceipt is the one function in a Roblox game where a bug costs
	real money. The rules it follows here:
	  * grant first, then return PurchaseGranted — never the other way round;
	  * if the profile is not loaded, return NotProcessedYet so Roblox retries
	    rather than eating the purchase;
	  * record the purchase id so a retried receipt cannot double-grant.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProductConfig = require(Shared.Config.Products)
local Format = require(Shared.Format)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)
local Rift = require(script.Parent.Rift)
local Cargo = require(script.Parent.Cargo)

local Monetization = {}

local function refreshGamepasses(player: Player)
	local session = Data.session(player)
	if not session then
		return
	end

	for _, pass in ipairs(ProductConfig.configuredGamepasses()) do
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.assetId)
		end)
		if ok then
			session.gamepasses[pass.id] = owned
		end
	end

	Data.push(player, { gamepasses = Data.replace(table.clone(session.gamepasses)) })
	Economy.applyCharacter(player)
	Cargo.resync(player)
end

--- Cash packs scale with what the player can already earn, so a pack is
--- always worth roughly the same number of runs regardless of progression.
local function cashGrant(player: Player, factor: number): number
	local profile = Data.get(player)
	if not profile then
		return 0
	end
	local reference = math.max(profile.stats.bestSingleBank, 5000)
	return math.floor(reference * factor * (1 + profile.rebirths * 0.25))
end

local function applyProduct(player: Player, product): boolean
	local profile = Data.get(player)
	local session = Data.session(player)
	if not profile or not session then
		return false
	end

	local grant = product.grant

	if grant.cashOfBest then
		local amount = cashGrant(player, grant.cashOfBest)
		Economy.addCash(player, amount)
		Feedback.toast(player, { title = "+" .. Format.short(amount), body = product.name, kind = "cash" })
	end

	if grant.luckMultiplier and grant.minutes then
		Economy.addBuff(player, "luck", grant.luckMultiplier, grant.minutes * 60)
		Feedback.toast(player, {
			title = `{grant.luckMultiplier}x LUCK`,
			body = `Active for {grant.minutes} minutes.`,
			kind = "rift",
		})
	end

	if grant.personalRift then
		Rift.grantPersonal(player, grant.personalRift)
	end

	if grant.restoreCargo then
		local loss = session.lastLoss
		if not loss or os.time() - loss.at > 120 then
			Feedback.toast(player, { title = "NOTHING TO RECOVER", body = "No recent loss on record.", kind = "error" })
			-- Still a valid purchase; refunding here would need a manual
			-- Robux refund, so we grant the equivalent in cash instead.
			Economy.addCash(player, cashGrant(player, 0.5))
		else
			session.lastLoss = nil
			-- Pull the crate out of the world first: the items in it are
			-- about to go straight back into the owner's hold.
			if loss.crateId then
				require(script.Parent.World).removeCrate(loss.crateId)
			end
			local recovered = 0
			for _, entry in ipairs(loss.items) do
				if Cargo.add(player, entry) then
					recovered += entry.value
				end
			end
			Feedback.toast(player, {
				title = "CARGO RECOVERED",
				body = Format.short(recovered) .. " back in your hold.",
				kind = "steal",
			})
		end
	end

	return true
end

function Monetization.start()
	local function hook(player: Player)
		task.spawn(function()
			-- Wait for the profile; gamepass state lives on the session.
			for _ = 1, 40 do
				if Data.isReady(player) then
					refreshGamepasses(player)
					return
				end
				task.wait(0.25)
			end
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if purchased then
			refreshGamepasses(player)
			Feedback.effect(player, "purchase", {})
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local profile = Data.get(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Idempotency: Roblox retries receipts, and a retry must not re-grant.
		profile.purchases.receipts = profile.purchases.receipts or {}
		if profile.purchases.receipts[receipt.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local product = ProductConfig.byAssetId(receipt.ProductId)
		if not product then
			warn(`DeepRush: unknown product {receipt.ProductId}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok, granted = pcall(applyProduct, player, product)
		if not ok or not granted then
			warn(`DeepRush: grant failed for {product.id}: {granted}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		profile.purchases.receipts[receipt.PurchaseId] = os.time()
		profile.purchases[product.id] = (profile.purchases[product.id] or 0) + 1
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return Monetization
