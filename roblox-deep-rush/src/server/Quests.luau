--!nonstrict
--[[
	Quests.luau — the task layer, and the reason a player logs in tomorrow.

	Everything funnels through Quests.record(player, metric, value, mode).
	Systems do not know what a quest is; they just report facts ("this
	player mined an Epic"). Quests decides what that means. Adding a new
	daily quest is then a data edit in Config/Quests.luau, not a code change.

	Daily reset is UTC-midnight based so every player on earth flips at the
	same instant — timezone-local resets let players farm the boundary twice.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local QuestConfig = require(Shared.Config.Quests)
local Net = require(Shared.Net)

local ContractConfig = require(Shared.Config.Contracts)
local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Feedback = require(script.Parent.Feedback)

local Quests = {}

local function today(): string
	local now = os.date("!*t")
	return string.format("%d-%03d", now.year, now.yday)
end

local function rollDailies(profile)
	local pool = table.clone(QuestConfig.DailyPool)
	local rng = Random.new(os.time() + math.random(1, 100000))

	local picked = {}
	for _ = 1, math.min(QuestConfig.DailyCount, #pool) do
		local index = rng:NextInteger(1, #pool)
		table.insert(picked, { id = pool[index].id, claimed = false })
		table.remove(pool, index)
	end

	profile.quests.daily = { day = today(), list = picked, rerolls = 0 }
	profile.quests.metrics = {} -- daily metrics reset with the quests
end

local function ensureDaily(player: Player): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	if profile.quests.daily.day == today() and #profile.quests.daily.list > 0 then
		return false
	end
	rollDailies(profile)
	return true
end

--- Read a metric, resolving the "_alltime" suffix to the lifetime table.
local function readMetric(profile, metric: string): number
	local base = metric:match("^(.-)_alltime$")
	if base then
		return profile.quests.alltime[base] or 0
	end
	return profile.quests.metrics[metric] or 0
end

--- Every quest currently live for this player, with progress attached.
function Quests.active(player: Player)
	local profile = Data.get(player)
	if not profile then
		return {}
	end
	ensureDaily(player)

	local out = { onboarding = nil, daily = {}, milestones = {} }

	local step = QuestConfig.Onboarding[profile.quests.onboarding]
	if step then
		out.onboarding = {
			id = step.id,
			name = step.name,
			desc = step.desc,
			target = step.target,
			progress = math.min(readMetric(profile, step.metric), step.target),
			reward = step.reward,
			index = profile.quests.onboarding,
			total = #QuestConfig.Onboarding,
		}
	end

	for _, entry in ipairs(profile.quests.daily.list) do
		local quest = QuestConfig.All[entry.id]
		if quest then
			table.insert(out.daily, {
				id = quest.id,
				name = quest.name,
				desc = quest.desc,
				target = quest.target,
				progress = math.min(readMetric(profile, quest.metric), quest.target),
				reward = quest.reward,
				claimed = entry.claimed,
			})
		end
	end

	for _, quest in ipairs(QuestConfig.Milestones) do
		if not profile.quests.milestones[quest.id] then
			table.insert(out.milestones, {
				id = quest.id,
				name = quest.name,
				desc = quest.desc,
				target = quest.target,
				progress = math.min(readMetric(profile, quest.metric), quest.target),
				reward = quest.reward,
			})
		end
	end

	out.rerolls = QuestConfig.DailyRerolls - profile.quests.daily.rerolls
	return out
end

-- Mining a single ore writes up to six metrics. Rebuilding and shipping the
-- whole board each time would cost a 30-player server real CPU for a panel
-- nobody has open, so writes only mark the board dirty and a slow loop flushes.
local dirty: { [Player]: boolean } = {}

local function syncQuests(player: Player)
	dirty[player] = true
end

local function flushQuests()
	for player in pairs(dirty) do
		dirty[player] = nil
		if player.Parent and Data.isReady(player) then
			Data.push(player, { questBoard = Data.replace(Quests.active(player)) })
		end
	end
end

--- The one entry point every other system uses.
--- mode: "count" accumulates, "max" keeps the best, "set" overwrites.
function Quests.record(player: Player, metric: string, value: number, mode: string?)
	local profile = Data.get(player)
	if not profile then
		return
	end
	ensureDaily(player)

	mode = mode or "count"
	local metrics = profile.quests.metrics
	local alltime = profile.quests.alltime

	if mode == "count" then
		metrics[metric] = (metrics[metric] or 0) + value
		alltime[metric] = (alltime[metric] or 0) + value
	elseif mode == "max" then
		metrics[metric] = math.max(metrics[metric] or 0, value)
		alltime[metric] = math.max(alltime[metric] or 0, value)
	else
		metrics[metric] = value
		alltime[metric] = math.max(alltime[metric] or 0, value)
	end

	syncQuests(player)
end

local function grant(player: Player, reward)
	local profile = Data.get(player)
	if not profile or not reward then
		return
	end

	require(script.Parent.Contracts).award(player, ContractConfig.Points.perQuestClaimed)

	if reward.cash then
		Economy.addCash(player, reward.cash)
	end
	if reward.luckMinutes then
		Economy.addBuff(player, "luck", 2, reward.luckMinutes * 60)
	end
	if reward.cosmetic then
		require(script.Parent.Cosmetics).unlock(player, reward.cosmetic)
	end
	if reward.drone and not profile.drones.owned[reward.drone] then
		profile.drones.owned[reward.drone] = true
		if not profile.drones.equipped then
			profile.drones.equipped = reward.drone
		end
		Data.push(player, { drones = Data.replace(table.clone(profile.drones)) })
	end
end

local function isComplete(profile, quest): boolean
	return readMetric(profile, quest.metric) >= quest.target
end

function Quests.claim(player: Player, questId: string)
	local profile = Data.get(player)
	local quest = QuestConfig.All[questId]
	if not profile or not quest or not isComplete(profile, quest) then
		return
	end

	-- Onboarding: only the current step is claimable, and claiming advances.
	local step = QuestConfig.Onboarding[profile.quests.onboarding]
	if step and step.id == questId then
		profile.quests.onboarding += 1
		grant(player, quest.reward)
		Feedback.toast(player, { title = "TASK DONE", body = quest.name, kind = "quest" })
		Data.push(player, { quests = { onboarding = profile.quests.onboarding } })
		syncQuests(player)
		return
	end

	for _, entry in ipairs(profile.quests.daily.list) do
		if entry.id == questId then
			if entry.claimed then
				return
			end
			entry.claimed = true
			grant(player, quest.reward)
			Feedback.toast(player, { title = "DAILY DONE", body = quest.name, kind = "quest" })
			Data.push(player, { quests = { daily = Data.replace(table.clone(profile.quests.daily)) } })
			syncQuests(player)
			return
		end
	end

	for _, milestone in ipairs(QuestConfig.Milestones) do
		if milestone.id == questId and not profile.quests.milestones[questId] then
			profile.quests.milestones[questId] = true
			grant(player, quest.reward)
			Feedback.broadcast({
				title = "MILESTONE",
				body = `{player.DisplayName} completed "{quest.name}"`,
				kind = "announce",
				duration = 5,
			})
			Data.push(player, { quests = { milestones = Data.replace(table.clone(profile.quests.milestones)) } })
			syncQuests(player)
			return
		end
	end
end

function Quests.reroll(player: Player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	if profile.quests.daily.rerolls >= QuestConfig.DailyRerolls then
		Feedback.toast(player, { title = "NO REROLLS LEFT", body = "Resets at midnight UTC.", kind = "error" })
		return
	end

	local usedRerolls = profile.quests.daily.rerolls + 1
	rollDailies(profile)
	profile.quests.daily.rerolls = usedRerolls
	Data.push(player, { quests = { daily = Data.replace(table.clone(profile.quests.daily)) } })
	syncQuests(player)
end

function Quests.start()
	Net.on("ClaimQuest", function(player, questId)
		if type(questId) == "string" then
			Quests.claim(player, questId)
		end
	end)

	Net.on("RerollDaily", function(player)
		Quests.reroll(player)
	end)

	-- The rules card lives with onboarding: it teaches the same six things the
	-- onboarding chain then makes you do.
	Net.on("IntroSeen", function(player)
		local profile = Data.get(player)
		if profile and not profile.seenIntro then
			profile.seenIntro = true
			Data.push(player, { seenIntro = true })
		end
	end)

	Data.loaded:connect(function(player)
		ensureDaily(player)
		-- Milestones read lifetime metrics, so a returning player may already
		-- have several waiting. Sync once so the board is correct on join.
		syncQuests(player)
	end)

	-- Profiles can finish loading before this service connects above, so cover
	-- anyone already in the server.
	for _, player in ipairs(Players:GetPlayers()) do
		if Data.isReady(player) then
			ensureDaily(player)
			syncQuests(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			flushQuests()
		end
	end)
end

return Quests
