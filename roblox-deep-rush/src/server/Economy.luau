--!nonstrict
--[[
	Economy.luau — the single place that answers "how good is this player?"

	Luck, cash multiplier, capacity and oxygen all come from four stacking
	sources: upgrades, rebirths, the equipped drone, and temporary buffs
	(potions, gamepasses, rift). Every other service asks this module rather
	than adding up bonuses itself, which is what keeps a "+2x luck" pass from
	silently missing one of the six places luck is used.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.Game)
local UpgradeConfig = require(Shared.Config.Upgrades)
local RebirthConfig = require(Shared.Config.Rebirth)
local DroneConfig = require(Shared.Config.Drones)
local ProductConfig = require(Shared.Config.Products)

local Crew = require(script.Parent.Crew)
local Data = require(script.Parent.Data)
local Feedback = require(script.Parent.Feedback)

local Economy = {}

--- Drop expired buffs. Called by every getter, so buffs never linger.
local function activeBuffs(player: Player)
	local session = Data.session(player)
	if not session then
		return {}
	end

	local now = os.time()
	local kept = {}
	local changed = false
	for _, buff in ipairs(session.buffs) do
		if buff.expires > now then
			table.insert(kept, buff)
		else
			changed = true
		end
	end

	if changed then
		session.buffs = kept
		Data.push(player, { buffs = Data.replace(table.clone(kept)) })
	end
	return kept
end

local function gamepassBonus(player: Player, field: string, default: number): number
	local session = Data.session(player)
	if not session then
		return default
	end

	local total = default
	for passId, owned in pairs(session.gamepasses) do
		if owned then
			local pass = ProductConfig.GamepassById[passId]
			local value = pass and pass.apply[field]
			if value then
				if field == "capacity" then
					total += value
				else
					total *= value
				end
			end
		end
	end
	return total
end

function Economy.addBuff(player: Player, kind: string, multiplier: number, seconds: number)
	local session = Data.session(player)
	if not session then
		return
	end
	table.insert(session.buffs, { kind = kind, multiplier = multiplier, expires = os.time() + seconds })
	Data.push(player, { buffs = Data.replace(table.clone(session.buffs)) })
end

function Economy.hasGamepass(player: Player, passId: string): boolean
	local session = Data.session(player)
	return session ~= nil and session.gamepasses[passId] == true
end

--- Total luck, capped. Cap exists because the tier table is exponential in
--- luck — uncapped, a stacked buff turns Singularity into a coin flip.
function Economy.luck(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 1
	end

	local luck = 1
	luck += UpgradeConfig.value("charm", profile.upgrades.charm or 0)
	luck += RebirthConfig.bonuses(profile.rebirths).luck
	luck += DroneConfig.bonusesOf(profile.drones.equipped).luck

	-- Paid for digging within bond range of a crewmate, not for being on a
	-- roster. See Server/Crew.luau.
	luck += Crew.bonus(player).luck

	luck *= gamepassBonus(player, "luckMultiplier", 1)

	for _, buff in ipairs(activeBuffs(player)) do
		if buff.kind == "luck" then
			luck *= buff.multiplier
		end
	end

	return math.clamp(luck, 1, Config.MaxLuck)
end

function Economy.cashMultiplier(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 1
	end

	local multiplier = RebirthConfig.bonuses(profile.rebirths).cashMultiplier
	multiplier *= 1 + DroneConfig.bonusesOf(profile.drones.equipped).cash
	multiplier *= 1 + Crew.bonus(player).cash
	multiplier *= gamepassBonus(player, "cashMultiplier", 1)

	for _, buff in ipairs(activeBuffs(player)) do
		if buff.kind == "cash" then
			multiplier *= buff.multiplier
		end
	end

	return multiplier
end

function Economy.capacity(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return Config.BaseCapacity
	end

	local capacity = Config.BaseCapacity
	capacity += UpgradeConfig.value("backpack", profile.upgrades.backpack or 0)
	capacity += RebirthConfig.bonuses(profile.rebirths).capacity
	capacity += gamepassBonus(player, "capacity", 0)
	return math.floor(capacity)
end

function Economy.maxOxygen(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return Config.BaseOxygen
	end

	local oxygen = Config.BaseOxygen
	oxygen += UpgradeConfig.value("oxygen", profile.upgrades.oxygen or 0)
	oxygen += RebirthConfig.bonuses(profile.rebirths).oxygen
	oxygen += DroneConfig.bonusesOf(profile.drones.equipped).oxygen

	for _, buff in ipairs(activeBuffs(player)) do
		if buff.kind == "oxygen" then
			oxygen *= buff.multiplier
		end
	end

	return oxygen
end

function Economy.mineTime(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return Config.BaseMineTime
	end
	local reduction = UpgradeConfig.value("drill", profile.upgrades.drill or 0)
	return math.max(Config.MinMineTime, Config.BaseMineTime * (1 - reduction))
end

function Economy.walkSpeed(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 16
	end
	return 16 + UpgradeConfig.value("boots", profile.upgrades.boots or 0)
end

function Economy.hazardResist(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 0
	end
	return math.min(DroneConfig.bonusesOf(profile.drones.equipped).hazardResist, 0.8)
end

function Economy.protectedShare(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 0
	end
	return UpgradeConfig.value("pocket", profile.upgrades.pocket or 0)
end

-- Cash and levels ----------------------------------------------------------

function Economy.xpToLevel(level: number): number
	return math.floor(Config.BaseXpToLevel * (Config.LevelCurve ^ (level - 1)))
end

function Economy.addCash(player: Player, amount: number)
	local profile = Data.get(player)
	if not profile or amount == 0 then
		return
	end

	profile.cash = math.max(0, profile.cash + amount)

	local patch = { cash = profile.cash }
	if amount > 0 then
		profile.xp += amount * Config.XpPerCashUnit
		local leveled = false
		while profile.xp >= Economy.xpToLevel(profile.level) do
			profile.xp -= Economy.xpToLevel(profile.level)
			profile.level += 1
			leveled = true
		end
		patch.xp = profile.xp
		patch.level = profile.level
		if leveled then
			Feedback.toast(player, {
				title = "LEVEL " .. profile.level,
				body = "Deeper strata, better nodes.",
				kind = "level",
			})
		end
	end

	Data.push(player, patch)
end

function Economy.spend(player: Player, amount: number): boolean
	local profile = Data.get(player)
	if not profile or profile.cash < amount then
		return false
	end
	profile.cash -= amount
	Data.push(player, { cash = profile.cash })
	return true
end

--- Push walkspeed onto the character. Called after upgrades and on spawn.
function Economy.applyCharacter(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Economy.walkSpeed(player)
	end
end

function Economy.start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			Economy.applyCharacter(player)
		end)
	end)
end

return Economy
