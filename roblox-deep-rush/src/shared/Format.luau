--!nonstrict
--[[
	Format.luau — number and time formatting.

	Roblox economies run into numbers no human reads at a glance. Everything
	shown to a player goes through here so "12.4M" never appears next to
	"12400000" on the same screen.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

--- 12400 -> "12.4K". Keeps three significant digits, which is the most a
--- player can absorb mid-swing.
function Format.short(value: number): string
	value = value or 0
	local negative = value < 0
	value = math.abs(value)

	if value < 1000 then
		local rounded = math.floor(value + 0.5)
		return (negative and "-" or "") .. tostring(rounded)
	end

	local index = math.min(math.floor(math.log(value, 1000)), #SUFFIXES - 1)
	local scaled = value / (1000 ^ index)
	local text
	if scaled >= 100 then
		text = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.2f", scaled)
	end

	-- Trim trailing zeros so we get "1.5K" instead of "1.50K". Guarded on a
	-- decimal point being present: without the guard "250" becomes "25",
	-- which silently divides every round number on screen by ten.
	if text:find("%.") then
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
	end

	return (negative and "-" or "") .. text .. SUFFIXES[index + 1]
end

function Format.comma(value: number): string
	local text = tostring(math.floor(value or 0))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

--- 95 -> "1:35". Used for rift countdowns and quest resets.
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

--- 0.000004 -> "1 in 250K". Shown on the rarity reveal, because the odds
--- are the brag.
function Format.odds(probability: number): string
	if probability <= 0 then
		return "?"
	end
	return "1 in " .. Format.short(math.floor(1 / probability + 0.5))
end

function Format.depth(meters: number): string
	return Format.comma(math.floor(meters or 0)) .. "m"
end

return Format
