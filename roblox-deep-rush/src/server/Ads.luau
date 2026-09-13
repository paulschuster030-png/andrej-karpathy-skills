--!nonstrict
--[[
	Ads.luau — opt-in Rewarded Video.

	Roblox opened Rewarded Video to all eligible creators in February 2026,
	and for games that place it well it now carries a real slice of revenue
	without touching game balance. Ours pays a luck boost — never Robux,
	never anything a player could not also earn.

	Two boundaries this module holds deliberately:

	  IT IS A BUTTON, NOT A LOOP. In August 2026 Roblox banned experiences
	  that pair a media feed with autoplay/infinite-scroll and rewards gated
	  on continuous viewing, after Steal an Egg's treadmill Reels. A single
	  opt-in video behind an hour-long cooldown is the opposite shape, and we
	  keep it that way: no feed, no autoplay, no reward that requires
	  continued watching.

	  IT NEVER APPEARS UNLESS IT WORKS. Availability is asked of Roblox first,
	  so a player is never shown a button that fails. Before the experience is
	  ads-eligible at all, the whole feature is silently absent.
]]

local AdService = game:GetService("AdService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ProductConfig = require(Shared.Config.Products)
local Net = require(Shared.Net)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Ads = {}

local settings = ProductConfig.RewardedVideo
local available = false
local showing: { [Player]: boolean } = {}

local function isConfigured(): boolean
	return settings.devProductId ~= 0
end

--- Roblox has reported this result object under more than one field name
--- across engine releases, so accept either rather than pinning one and
--- silently disabling the feature on the next update.
local function checkAvailability(): boolean
	if not isConfigured() then
		return false
	end

	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	if not ok or result == nil then
		return false
	end

	local status = result
	if type(result) == "table" or typeof(result) == "Instance" then
		status = result.AdAvailabilityResult or result.Result or result
	end
	return string.find(tostring(status), "Available") ~= nil
end

function Ads.offer(player: Player)
	local profile = Data.get(player)
	local session = Data.session(player)
	if not profile or not session or not isConfigured() then
		return
	end

	if showing[player] then
		return
	end

	local since = os.time() - (session.lastAd or 0)
	if since < settings.cooldownSeconds then
		Feedback.toast(player, {
			title = "ALREADY BOOSTED",
			body = `Next free boost in {math.ceil((settings.cooldownSeconds - since) / 60)} min.`,
			kind = "error",
		})
		return
	end

	if not available then
		Feedback.toast(player, { title = "NO BOOST AVAILABLE", body = "Try again later.", kind = "error" })
		return
	end

	showing[player] = true

	local ok, result = pcall(function()
		local reward = AdService:CreateAdRewardFromDevProductId(settings.devProductId)
		return AdService:ShowRewardedVideoAdAsync(player, reward)
	end)

	showing[player] = nil

	if not ok then
		warn("DeepRush: rewarded video failed: " .. tostring(result))
		return
	end

	if result ~= Enum.ShowAdResult.ShowCompleted then
		return
	end

	session.lastAd = os.time()
	Economy.addBuff(player, "luck", settings.rewardLuckMultiplier, settings.rewardMinutes * 60)
	Feedback.effect(player, "purchase", {})
	Feedback.toast(player, {
		title = `{settings.rewardLuckMultiplier}x LUCK`,
		body = `Active for {settings.rewardMinutes} minutes. Thanks for watching.`,
		kind = "rift",
	})
	Net.to(player, "Ad", { available = false, nextAt = session.lastAd + settings.cooldownSeconds })
end

function Ads.start()
	if not isConfigured() then
		-- Nothing to do, and nothing shown to players. Set
		-- Products.RewardedVideo.devProductId once the experience qualifies.
		return
	end

	Net.on("WatchAd", function(player)
		task.spawn(Ads.offer, player)
	end)

	task.spawn(function()
		-- Asking before AdService has loaded returns a false "no fill".
		if not AdService:IsLoaded() then
			pcall(function()
				AdService.Loaded:Wait()
			end)
		end

		while true do
			available = checkAvailability()
			for _, player in ipairs(Players:GetPlayers()) do
				local session = Data.session(player)
				if session then
					local ready = os.time() - (session.lastAd or 0) >= settings.cooldownSeconds
					Net.to(player, "Ad", { available = available and ready })
				end
			end
			task.wait(60)
		end
	end)
end

return Ads
