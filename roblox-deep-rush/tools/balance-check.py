#!/usr/bin/env python3
"""
balance-check.py — run the game's pure balance logic outside Roblox.

The economy modules (ores, layers, rarity, upgrades, rebirth) are plain Luau
with no Roblox API surface beyond Color3 and Random. This script stubs those
two, concatenates the modules into one program with a tiny module registry,
appends tools/balance-spec.luau, and runs it under the Luau interpreter.

That means the drop tables and cost curves are actually TESTED rather than
eyeballed — a value typo shows up here instead of in a live server.

Usage:  python3 tools/balance-check.py [path-to-luau-binary]
"""

import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "shared")

# Order matters: a module may only require ones already defined.
MODULES = [
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
    ("Products", "Config/Products.luau"),
    ("Format", "Format.luau"),
    ("Rarity", "Rarity.luau"),
]

STUBS = r"""
-- === Roblox API stubs =====================================================
local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
end

local RandomClass = {}
RandomClass.__index = RandomClass
function RandomClass:NextNumber(min, max)
	if min == nil then
		return math.random()
	end
	return min + math.random() * (max - min)
end
function RandomClass:NextInteger(min, max)
	return math.random(min, max)
end
local Random = {}
function Random.new(seed)
	if seed then
		math.randomseed(math.floor(seed) % 2147483647)
	end
	return setmetatable({}, RandomClass)
end

local MODULES = {}
-- === Modules ==============================================================
"""


def build_program(spec_source: str) -> str:
    parts = [STUBS]

    for name, relative in MODULES:
        with open(os.path.join(SHARED, relative), encoding="utf-8") as handle:
            source = handle.read()

        # Rewrite intra-project requires to registry lookups.
        source = re.sub(
            r"require\(script\.Parent\.Config\.(\w+)\)", r"MODULES.\1", source
        )
        source = re.sub(r"require\(script\.Parent\.(\w+)\)", r"MODULES.\1", source)
        source = re.sub(r"require\(Shared\.Config\.(\w+)\)", r"MODULES.\1", source)
        source = re.sub(r"require\(Shared\.(\w+)\)", r"MODULES.\1", source)

        parts.append(f"MODULES.{name} = (function()\n{source}\nend)()\n")

    parts.append("-- === Spec =================================================================\n")
    parts.append(spec_source)
    return "\n".join(parts)


def main() -> int:
    luau = sys.argv[1] if len(sys.argv) > 1 else "luau"

    with open(os.path.join(ROOT, "tools", "balance-spec.luau"), encoding="utf-8") as handle:
        spec = handle.read()

    program = build_program(spec)
    out_path = os.path.join(ROOT, "build", "balance-program.luau")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(program)

    result = subprocess.run([luau, out_path], capture_output=True, text=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
