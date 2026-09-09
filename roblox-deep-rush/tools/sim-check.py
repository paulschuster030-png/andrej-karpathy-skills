#!/usr/bin/env python3
"""
sim-check.py — actually run the server, headless.

Assembles the real server modules against tools/robloxstub.luau and executes
tools/sim-spec.luau against them. This is the check that answers "are you sure
the lift works" with something other than an opinion.

The rewriting is the same trick as balance-check.py: intra-project requires
become registry lookups, so the modules load in dependency order without a
DataModel to hang them off.

Usage:  python3 tools/sim-check.py [path-to-luau-binary]
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

SHARED = [
    ("Ores", "Config/Ores.luau"),
    ("Layers", "Config/Layers.luau"),
    ("Mutations", "Config/Mutations.luau"),
    ("Upgrades", "Config/Upgrades.luau"),
    ("Rebirth", "Config/Rebirth.luau"),
    ("Drones", "Config/Drones.luau"),
    ("Game", "Config/Game.luau"),
    ("Quests", "Config/Quests.luau"),
    ("Crew", "Config/Crew.luau"),
    ("Cosmetics", "Config/Cosmetics.luau"),
    ("Contracts", "Config/Contracts.luau"),
    ("Season", "Config/Season.luau"),
    ("Hazards", "Config/Hazards.luau"),
    ("Tools", "Config/Tools.luau"),
    ("Products", "Config/Products.luau"),
    ("Audio", "Config/Audio.luau"),
    ("Format", "Format.luau"),
    ("Signal", "Signal.luau"),
    ("Rarity", "Rarity.luau"),
    ("Net", "Net.luau"),
]

# Bootstrap order, minus the three that need live Roblox backends
# (DataStores, Marketplace receipts, the ad network). Those are exercised by
# the compile and protocol checks instead; nothing else depends on them.
# Load order. Feedback has no start() so Bootstrap never lists it, but half
# the server requires it, so it has to be in the registry before they load.
SERVER = [
    "Feedback", "Data", "World", "Crew", "Economy", "Cargo", "Cosmetics",
    "Tools", "Contracts", "Quests", "Rift", "Season", "Mining", "Surface", "Steal",
    "Hazards", "Upgrades", "Rebirth", "Drones", "Rewards", "Leaderboards",
    "Monetization", "Ads", "AntiCheat",
]

SKIPPED = []  # everything loads; the DataStore-backed paths no-op without stores


def rewrite(source: str) -> str:
    """Point intra-project requires at the registries."""
    source = re.sub(r"require\(script\.Parent\.Config\.(\w+)\)", r"MODULES.\1", source)
    source = re.sub(r"require\(script\.Parent\.(\w+)\)", r"SERVER.\1", source)
    source = re.sub(r"require\(Shared\.Config\.(\w+)\)", r"MODULES.\1", source)
    source = re.sub(r"require\(Shared\.(\w+)\)", r"MODULES.\1", source)
    return source


def build_program(spec: str) -> str:
    parts = []

    with open(os.path.join(ROOT, "tools", "robloxstub.luau"), encoding="utf-8") as handle:
        stub = handle.read().replace("return Stub", "")
    parts.append("local Stub = (function()\n" + stub + "\nreturn Stub\nend)()\n")

    parts.append(
        """
local ENV = Stub.build(nil)
local game, workspace = ENV.game, ENV.workspace
local Instance, Vector3, Vector2 = ENV.Instance, ENV.Vector3, ENV.Vector2
local CFrame, Color3, Random, Enum = ENV.CFrame, ENV.Color3, ENV.Random, ENV.Enum
local UDim2, UDim, TweenInfo = ENV.UDim2, ENV.UDim, ENV.TweenInfo
local NumberRange, NumberSequence = ENV.NumberRange, ENV.NumberSequence
local NumberSequenceKeypoint, ColorSequence = ENV.NumberSequenceKeypoint, ENV.ColorSequence
local task = ENV.task

-- Virtual time has to reach os.clock too, or Net's token-bucket rate limiter
-- never refills and every remote after the first few is silently dropped.
local realDate = os.date
local baseTime = 1767225600
local os = {
	clock = function() return Stub.now() end,
	time = function() return math.floor(baseTime + Stub.now()) end,
	date = function(format, when) return realDate(format, when or math.floor(baseTime + Stub.now())) end,
}

-- Roblox globals the modules assume exist. Warnings are collected rather than
-- printed so the spec can assert that a clean run produced none — Net wraps
-- every handler in pcall, so without this a broken handler would fail
-- silently and the suite would still go green.
local WARNINGS = {}
local function warn(...)
	local pieces = {}
	for index = 1, select("#", ...) do
		pieces[index] = tostring((select(index, ...)))
	end
	table.insert(WARNINGS, table.concat(pieces, " "))
end

local function typeof(value)
	if type(value) == "table" then
		local meta = getmetatable(value)
		if meta == ENV.Vector3 then return "Vector3" end
		if meta == ENV.CFrame then return "CFrame" end
		if meta == ENV.Color3 then return "Color3" end
		if value.ClassName then return "Instance" end
	end
	return type(value)
end

local MODULES = {}
local SERVER = {}
"""
    )

    for name, relative in SHARED:
        with open(os.path.join(SRC, "shared", relative), encoding="utf-8") as handle:
            parts.append(f"MODULES.{name} = (function()\n{rewrite(handle.read())}\nend)()\n")

    # DataStores are unreachable from a headless run; the profile lives in
    # memory, which is exactly what UseDataStores = false is for.
    parts.append("MODULES.Game.UseDataStores = false\n")

    for name in SERVER:
        with open(os.path.join(SRC, "server", f"{name}.luau"), encoding="utf-8") as handle:
            parts.append(f"SERVER.{name} = (function()\n{rewrite(handle.read())}\nend)()\n")

    parts.append("-- === Spec ===\n")
    parts.append(spec)
    return "\n".join(parts)


def main() -> int:
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"

    with open(os.path.join(ROOT, "tools", "sim-spec.luau"), encoding="utf-8") as handle:
        spec = handle.read()

    program = build_program(spec)
    out_path = os.path.join(ROOT, "build", "sim-program.luau")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(program)

    result = subprocess.run([luau, out_path], capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if SKIPPED:
        print("not simulated (need live Roblox backends): " + ", ".join(SKIPPED))
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
