--!nonstrict
--[[
	Crew.luau — tuning for the co-play layer.

	Roblox's Recommended For You algorithm names "7 day intentional co-play
	days per user" as one of its six ranking signals, alongside play days and
	spend days. A game where playing together is merely possible scores zero
	on it; the bonus has to be big enough that a player actively wants a
	second person in the shaft.

	Everything here is designed to work WITHOUT text chat, because since the
	January 2026 age-check rollout a large share of players cannot freely
	chat with each other. Coordination happens through pings and proximity,
	never through typing.
]]

return {
	MaxSize = 4,
	JoinRadius = 40, -- studs; how close you must be to join a beacon
	BondRadius = 120, -- studs; how close members must stay to earn the bonus
	BeaconLifetime = 45, -- seconds a beacon stays open for joiners

	-- Per ADDITIONAL member beyond yourself. A full crew of 4 is +36% cash
	-- and +0.75 luck — large enough to change behaviour, small enough that a
	-- solo player is never locked out of content.
	CashPerMember = 0.12,
	LuckPerMember = 0.25,

	-- Pings are the entire coordination vocabulary. Fixed set, no free text,
	-- which is what keeps this compliant with the preset-communication rules.
	PingTypes = {
		{ id = "ore", label = "RICH VEIN", icon = "💎", color = { 255, 205, 90 } },
		{ id = "danger", label = "DANGER", icon = "⚠️", color = { 255, 80, 80 } },
		{ id = "lift", label = "LIFT HERE", icon = "▲", color = { 110, 235, 160 } },
		{ id = "here", label = "ON ME", icon = "📍", color = { 110, 230, 255 } },
	},
	PingLifetime = 8,
	PingCooldown = 1.5,

	-- A downed crewmate's crate can be handed back instead of looted. Costs
	-- the rescuer nothing and is the clearest possible "we are on the same
	-- side" signal in a game otherwise built on theft.
	RescueRadius = 16,
	RescueReward = 0.10, -- rescuer gets 10% of the value as a finder's fee
}
