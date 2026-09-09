--!nonstrict
--[[
	Client.client.luau — client start order.

	State first: every controller renders from it, and a HUD that builds
	before the first snapshot arrives shows zeroes for a frame.
]]

local CONTROLLERS = {
	"State",
	"Effects",
	"Atmosphere",
	"Mining",
	"Panels",
	"Notify",
	"Hud",
	"Crew",
	"Intro",
	"Onboarding",
}

for _, name in ipairs(CONTROLLERS) do
	local module = script.Parent:FindFirstChild(name)
	if not module then
		warn(`DeepRush: controller "{name}" is missing`)
		continue
	end

	local ok, controller = pcall(require, module)
	if not ok then
		warn(`DeepRush: controller "{name}" failed to load: {controller}`)
		continue
	end

	if type(controller) == "table" and type(controller.start) == "function" then
		local startOk, err = pcall(controller.start)
		if not startOk then
			warn(`DeepRush: controller "{name}" failed to start: {err}`)
		end
	end
end
