--!nonstrict
--[[
	Bootstrap.server.luau — start order is the dependency order.

	Data goes first because it publishes the remote tree and owns profiles;
	everything else assumes a profile can exist. World goes early because
	Surface and Steal need the vault and the crate container to be there.
]]

local SERVICES = {
	"Data",
	"World",
	"Crew",
	"Economy",
	"Cargo",
	"Cosmetics",
	"Contracts",
	"Quests",
	"Rift",
	"Mining",
	"Surface",
	"Steal",
	"Hazards",
	"Upgrades",
	"Rebirth",
	"Drones",
	"Rewards",
	"Leaderboards",
	"Monetization",
	"Ads",
	"AntiCheat",
}

local started = os.clock()

for _, name in ipairs(SERVICES) do
	local module = script.Parent:FindFirstChild(name)
	if not module then
		warn(`DeepRush: service "{name}" is missing`)
		continue
	end

	local ok, service = pcall(require, module)
	if not ok then
		warn(`DeepRush: service "{name}" failed to load: {service}`)
		continue
	end

	if type(service) == "table" and type(service.start) == "function" then
		local startOk, err = pcall(service.start)
		if not startOk then
			warn(`DeepRush: service "{name}" failed to start: {err}`)
		end
	end
end

print(string.format("[DEEP RUSH] %d services up in %.2fs", #SERVICES, os.clock() - started))
