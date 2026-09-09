--!nonstrict
--[[
	Data.luau — profiles, persistence, and the one funnel that pushes state
	to clients.

	Two things here are non-negotiable in a live Roblox game and are the
	reason this module is longer than it looks like it should be:

	  SESSION LOCKING  Roblox can run the same user in two servers at once
	                   (teleports, region hops, rejoin spam). Without a lock,
	                   the older server's autosave overwrites the newer one
	                   and the player loses progress. We stamp a lock with a
	                   JobId and only steal it once it has gone stale.

	  BINDTOCLOSE      A shutdown gives you ~30 seconds. If you do not flush
	                   there, everyone who was online loses their last save.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local Data = {}

Data.loaded = Signal.new() -- fired (player) once a profile is live
Data.unloading = Signal.new() -- fired (player, profile) before the final save

local LOCK_STALE_SECONDS = 100
local LOAD_ATTEMPTS = 5

local store = Config.UseDataStores and DataStoreService:GetDataStore("DeepRushProfiles_v1") or nil
local profiles: { [Player]: any } = {}
local sessions: { [Player]: any } = {}
local pendingPatches: { [Player]: any } = {}

local function template()
	return {
		version = 1,
		cash = 0,
		xp = 0,
		level = 1,
		rebirths = 0,
		upgrades = {},
		drones = { owned = {}, equipped = nil },
		codex = {},
		quests = {
			onboarding = 1, -- index into Quests.Onboarding; > #list means done
			daily = { day = "", list = {}, rerolls = 0 },
			milestones = {}, -- id -> true once claimed
			metrics = {}, -- resets daily
			alltime = {},
		},
		stats = {
			-- The rarest thing this player has ever pulled, shown to everyone
			-- who walks past them. See Cosmetics.applyNameplate.
			bestPull = nil,
			bestDepth = 0,
			bankedTotal = 0,
			bestSingleBank = 0,
			minedTotal = 0,
			steals = 0,
			deaths = 0,
			playtime = 0,
			cleanBanks = 0,
		},
		rewards = { lastLogin = "", streak = 0, chests = 0 },

		-- The rules card shows once per account, not once per session.
		seenIntro = false,

		-- Weekly ladder. dayPoints enforces the daily cap that pushes play
		-- DAYS rather than long single sessions.
		contract = { week = "", points = 0, dayPoints = 0, day = "", claimed = {} },

		-- Distinct days played, which is the metric the 28-day discovery
		-- window actually grades.
		descent = { days = 0, lastDay = "", claimed = {} },

		cosmetics = { owned = {}, equipped = {} },

		-- Live-window progress. The badge itself lives in cosmetics and
		-- survives the season; only the counter here resets.
		season = { number = 0, cores = 0, badge = false },
		deals = { day = "", bought = {} },
		purchases = {},
		createdAt = os.time(),
		lastSeen = os.time(),
	}
end

--- A fresh per-session scratchpad. Nothing here is ever saved.
local function newSession()
	return {
		cargo = { items = {}, value = 0 },
		depth = 0,
		joinedAt = os.clock(),
		mining = nil,
		oxygen = Config.BaseOxygen,
		buffs = {}, -- { kind, multiplier, expires }
		gamepasses = {},
		lastSnatch = 0,
		lastBank = 0,
		lastPosition = nil,
		riftMined = 0,
	}
end

--- Fill in fields added by a later version of the game without clobbering
--- anything the player already has.
local function reconcile(saved, defaults)
	for key, value in pairs(defaults) do
		if saved[key] == nil then
			saved[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(saved[key]) == "table" then
			reconcile(saved[key], value)
		end
	end
	return saved
end

local function key(userId: number): string
	return "player_" .. userId
end

-- Loading ------------------------------------------------------------------

local function tryLoad(userId: number)
	local jobId = game.JobId ~= "" and game.JobId or "studio"

	local loaded, err = pcall(function()
		return store:UpdateAsync(key(userId), function(existing)
			local now = os.time()

			if existing and existing.lock then
				local age = now - (existing.lock.at or 0)
				local mine = existing.lock.jobId == jobId
				if not mine and age < LOCK_STALE_SECONDS then
					-- Someone else holds a live lock. Abort and retry.
					return nil
				end
			end

			local payload = existing and existing.data or template()
			return {
				lock = { jobId = jobId, at = now },
				data = payload,
			}
		end)
	end)

	if not loaded then
		return nil, tostring(err)
	end
	return loaded
end

local function loadProfile(player: Player)
	if not store then
		return template()
	end

	for attempt = 1, LOAD_ATTEMPTS do
		local result, err = tryLoad(player.UserId)
		if result and result.data then
			return reconcile(result.data, template())
		end
		if err then
			warn(`DeepRush: load attempt {attempt} failed for {player.Name}: {err}`)
		end
		-- Back off: a held lock usually clears within a few seconds.
		task.wait(2 ^ attempt)
		if not player.Parent then
			return nil
		end
	end

	return nil
end

local function saveProfile(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not store then
		return
	end

	profile.lastSeen = os.time()
	local session = sessions[player]
	if session then
		profile.stats.playtime += math.floor(os.clock() - session.joinedAt)
		session.joinedAt = os.clock()
	end

	local jobId = game.JobId ~= "" and game.JobId or "studio"
	local ok, err = pcall(function()
		store:UpdateAsync(key(player.UserId), function(existing)
			-- Refuse to write over a server that legitimately took the lock
			-- from us; our copy is the stale one in that case.
			if existing and existing.lock and existing.lock.jobId ~= jobId then
				local age = os.time() - (existing.lock.at or 0)
				if age < LOCK_STALE_SECONDS then
					return nil
				end
			end
			return {
				lock = if release then nil else { jobId = jobId, at = os.time() },
				data = profile,
			}
		end)
	end)

	if not ok then
		warn(`DeepRush: save failed for {player.Name}: {err}`)
	end
end

-- Public API ---------------------------------------------------------------

function Data.get(player: Player)
	return profiles[player]
end

function Data.session(player: Player)
	return sessions[player]
end

function Data.isReady(player: Player): boolean
	return profiles[player] ~= nil
end

--- Merge a patch into the outgoing queue. Patches are coalesced and flushed
--- on a timer so a burst of mining does not become a burst of replication.
function Data.push(player: Player, patch)
	if not patch then
		return
	end
	local queued = pendingPatches[player]
	if not queued then
		pendingPatches[player] = patch
		return
	end

	local function merge(target, source)
		for k, v in pairs(source) do
			if type(v) == "table" and type(target[k]) == "table" and not v.__replace then
				merge(target[k], v)
			else
				target[k] = v
			end
		end
	end
	merge(queued, patch)
end

--- Mark a table so the client replaces rather than merges it. Needed for
--- lists (daily quests, cargo contents) where a merge would leave orphans.
function Data.replace(value)
	value.__replace = true
	return value
end

--- The full snapshot a joining client needs. Session-only fields are folded
--- in so the client has one shape to reason about.
function Data.snapshot(player: Player)
	local profile = profiles[player]
	local session = sessions[player]
	if not profile or not session then
		return nil
	end

	return {
		cash = profile.cash,
		xp = profile.xp,
		level = profile.level,
		rebirths = profile.rebirths,
		upgrades = profile.upgrades,
		drones = profile.drones,
		codex = profile.codex,
		quests = profile.quests,
		stats = profile.stats,
		rewards = profile.rewards,
		seenIntro = profile.seenIntro,
		contract = profile.contract,
		descent = profile.descent,
		cosmetics = profile.cosmetics,
		season = profile.season,
		deals = profile.deals,
		cargo = { count = #session.cargo.items, value = session.cargo.value },
		depth = session.depth,
		oxygen = session.oxygen,
		buffs = session.buffs,
		gamepasses = session.gamepasses,
	}
end

function Data.start()
	Net.handle("GetState", function(player)
		-- A client can invoke before its profile finished loading.
		for _ = 1, 40 do
			if profiles[player] then
				return Data.snapshot(player)
			end
			task.wait(0.25)
		end
		return nil
	end)

	local function onPlayerAdded(player: Player)
		local profile = loadProfile(player)
		if not profile then
			player:Kick("Could not load your save. Please rejoin — your progress is safe.")
			return
		end
		if not player.Parent then
			return
		end

		profiles[player] = profile
		sessions[player] = newSession()
		Data.loaded:fire(player)
		Net.to(player, "State", Data.snapshot(player))
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if profiles[player] then
			Data.unloading:fire(player, profiles[player])
			saveProfile(player, true)
		end
		profiles[player] = nil
		sessions[player] = nil
		pendingPatches[player] = nil
	end)

	-- Patch flush loop.
	task.spawn(function()
		while true do
			task.wait(Config.StateSyncRate)
			for player, patch in pairs(pendingPatches) do
				if player.Parent then
					Net.to(player, "State", patch)
				end
				pendingPatches[player] = nil
			end
		end
	end)

	-- Autosave loop, staggered so 40 players do not all write at once.
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in ipairs(Players:GetPlayers()) do
				if profiles[player] then
					task.spawn(saveProfile, player, false)
					task.wait(0.4)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for player in pairs(profiles) do
			pending += 1
			task.spawn(function()
				saveProfile(player, true)
				pending -= 1
			end)
		end
		-- Shutdown gives us roughly 30s; spend what we need and no more.
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return Data
