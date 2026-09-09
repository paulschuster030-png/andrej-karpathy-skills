--!nonstrict
--[[
	Season.luau — the live window, and the badge you only get by being there.

	Every weekend (UTC) a window opens. Inside it, and nowhere else, the Season
	Core drops. Mine twelve and you keep a title and a trail stamped with that
	season's name, permanently, and that season never comes back.

	The design intent is plain: give a player a specific reason to open the
	game on a specific day, and give them something everyone else can see
	afterwards. It feeds the platform's "play days" signal honestly, because
	the only way to get it is to actually turn up.

	What it will not do: it is never sold, never discounted, never extended for
	a purchase, and the threshold is low enough that one ordinary session
	inside the window earns it. Urgency that a player cannot satisfy is not
	urgency, it is just a bad evening.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Season)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local Ores = require(Shared.Config.Ores)

local Cosmetics = require(script.Parent.Cosmetics)
local Data = require(script.Parent.Data)
local Feedback = require(script.Parent.Feedback)

local Season = {}

local rng = Random.new(os.time() + 31337)
local wasOpen = nil

--- Roll the player's season record over when the season number changes. The
--- badge itself is a cosmetic and survives; only the progress counter resets.
local function ensureSeason(player: Player)
	local profile = Data.get(player)
	if not profile then
		return nil
	end

	local number = Config.number()
	if profile.season.number ~= number then
		profile.season = { number = number, cores = 0, badge = false }
		Data.push(player, { season = Data.replace(table.clone(profile.season)) })
	end
	return profile.season
end

function Season.state()
	local open = Config.isOpen()
	return {
		open = open,
		number = Config.number(),
		label = Config.badge(Config.number()).label,
		seconds = Config.secondsUntilChange(),
		requirement = Config.BadgeRequirement,
	}
end

local function grantBadge(player: Player)
	local profile = Data.get(player)
	local record = ensureSeason(player)
	if not profile or not record or record.badge then
		return
	end

	record.badge = true
	local badge = Config.badge(record.number)
	Cosmetics.unlock(player, badge.title)
	Cosmetics.unlock(player, badge.trail)
	Data.push(player, { season = Data.replace(table.clone(record)) })

	Feedback.broadcast({
		title = "🏅 SEASON BADGE",
		body = `{player.DisplayName} earned "{badge.label}". It cannot be earned again after this weekend.`,
		kind = "announce",
		duration = 7,
	})
end

--- Called by Mining on every swing inside the window. Returns a cargo entry
--- for the Season Core, or nil.
function Season.tryDrop(player: Player, depth: number)
	if not Config.isOpen() or depth < Config.Ore.minDepth then
		return nil
	end

	local record = ensureSeason(player)
	if not record then
		return nil
	end

	if rng:NextNumber() > Config.OreChance then
		return nil
	end

	record.cores += 1
	Data.push(player, { season = { cores = record.cores } })

	if record.cores >= Config.BadgeRequirement and not record.badge then
		grantBadge(player)
	else
		Feedback.toast(player, {
			title = `SEASON CORE {record.cores}/{Config.BadgeRequirement}`,
			body = "Only this weekend. Keep going.",
			kind = "rift",
		})
	end

	local ore = Ores.ById[Config.Ore.id]
	return {
		oreId = Config.Ore.id,
		tier = ore and ore.tier or Config.Ore.tier,
		mutation = nil,
		value = Config.Ore.value,
	}
end

local function announce(open: boolean)
	local badge = Config.badge(Config.number())
	if open then
		Feedback.announce(
			"🏅 SEASON WINDOW OPEN",
			`"{badge.label}" — mine {Config.BadgeRequirement} Season Cores below {Format.depth(Config.Ore.minDepth)} to keep the badge forever.`,
			{ 255, 205, 90 }
		)
		Feedback.effectAll("rift", { season = true })
	else
		Feedback.announce(
			"SEASON WINDOW CLOSED",
			`"{badge.label}" is gone. The next window opens in {Format.clock(Config.secondsUntilChange())}.`,
			{ 150, 150, 170 }
		)
	end
end

function Season.start()
	Data.loaded:connect(function(player)
		ensureSeason(player)
		task.delay(8, function()
			if not player.Parent or not Config.isOpen() then
				return
			end
			local record = Data.get(player) and Data.get(player).season
			if record and not record.badge then
				Feedback.toast(player, {
					title = "🏅 SEASON WINDOW IS OPEN",
					body = `{Config.badge(Config.number()).label} — this badge disappears when the weekend does.`,
					kind = "rift",
					duration = 7,
				})
			end
		end)
	end)

	task.spawn(function()
		while true do
			local open = Config.isOpen()
			if wasOpen ~= nil and open ~= wasOpen then
				announce(open)
			end
			wasOpen = open

			local state = Season.state()
			for _, player in ipairs(Players:GetPlayers()) do
				if Data.isReady(player) then
					local profile = Data.get(player)
					state.cores = profile.season.cores
					state.badge = profile.season.badge
					Net.to(player, "Season", state)
				end
			end

			task.wait(2)
		end
	end)
end

return Season
