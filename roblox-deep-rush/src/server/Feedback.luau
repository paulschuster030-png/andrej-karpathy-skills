--!nonstrict
--[[
	Feedback.luau — the game's voice.

	Split out from the systems that trigger it so that "what happened" and
	"how loud it feels" stay separate. Tuning game feel then means editing
	one file instead of nineteen.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local Feedback = {}

--- Corner notification. `kind` drives colour and sound on the client.
function Feedback.toast(player: Player, payload)
	Net.to(player, "Toast", payload)
end

function Feedback.broadcast(payload)
	Net.all("Toast", payload)
end

--- The full-screen card for a rare pull. Reserved for Epic+ so it keeps
--- meaning something; below that, the ore just pops off the rock.
function Feedback.reveal(player: Player, payload)
	Net.to(player, "Reveal", payload)
end

--- One-shot client effect: screen shake, a sound, a burst of particles.
function Feedback.effect(player: Player, kind: string, payload)
	Net.to(player, "Effect", kind, payload)
end

function Feedback.effectAll(kind: string, payload)
	Net.all("Effect", kind, payload)
end

--- Server-wide announcement for a Mythic+ pull or a rift. These are the
--- moments that make a full server look at the same thing at once, which is
--- most of what "social" means in a mining game.
function Feedback.announce(title: string, body: string, color)
	Net.all("Toast", {
		title = title,
		body = body,
		kind = "announce",
		color = color,
		duration = 6,
	})
end

return Feedback
