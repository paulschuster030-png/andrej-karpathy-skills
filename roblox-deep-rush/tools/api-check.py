#!/usr/bin/env python3
"""Check every property this game assigns against Roblox's own API dump.

Why this exists: tools/robloxstub.luau accepts any property you set on
anything, because it is a table. Roblox does not. Setting a property that
does not exist, or one the engine reserves for itself, throws at runtime —
and a throw inside a service's start() is swallowed into a warn(), so the
symptom is a world that silently never gets built.

That is exactly what happened: Lighting.Technology is RobloxScriptSecurity
for both read and write. It looked fine in every check we had, compiled
fine, simulated fine, and could not work in a real place.

tools/api-dump.json in this repo is Roblox's published API description,
trimmed to the class/property/enum names this check needs (531 KB instead of
7 MB). Refresh it from:

    https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json

The check skips itself, and says so, when the dump is missing — a clone
without it still runs every other check.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP = os.path.join(ROOT, "tools", "api-dump.json")

# Security levels a normal game script is allowed to write. Only "None".
#
# PluginSecurity was in this set once, on the assumption that it meant "a
# plugin may also write it". It means the opposite: ONLY a plugin may. That
# single wrong entry is why this check passed
# workspace.FallenPartsDestroyHeight, which threw at runtime with "the
# current thread cannot write it, lacking capability Plugin" and took the
# whole world generator down.
OPEN = {"None"}

# Globals and project helpers whose class we know without tracking them.
KNOWN_GLOBALS = {
    "workspace": "Workspace",
    "Workspace": "Workspace",
    "Lighting": "Lighting",
    "Players": "Players",
    "SoundService": "SoundService",
    "TweenService": "TweenService",
    "Debris": "Debris",
    "RunService": "RunService",
    "camera": "Camera",
}

# makePart() in World.luau and Tools.luau both return a plain anchored Part.
HELPER_RETURNS = {"makePart": "Part"}


def load_dump():
    with open(DUMP, encoding="utf-8") as handle:
        dump = json.load(handle)

    by_name = {c["Name"]: c for c in dump["Classes"]}

    def properties(class_name):
        """Every property on a class, including everything it inherits."""
        out = {}
        chain = []
        cursor = class_name
        while cursor and cursor in by_name:
            chain.append(by_name[cursor])
            cursor = by_name[cursor].get("Superclass")
        for entry in reversed(chain):
            for member in entry["Members"]:
                if member["MemberType"] == "Property":
                    out[member["Name"]] = member
        return out

    enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}
    return by_name, properties, enums


ASSIGN = re.compile(r"^\s*(?:local\s+)?(\w+)(?:\s*:\s*[\w?.]+)?\s*=\s*(.+?)\s*$")
NEW = re.compile(r'Instance\.new\(\s*"(\w+)"')
SET = re.compile(r"^\s*(\w+)\.(\w+)\s*=\s*[^=]")
PARAM = re.compile(r"(\w+)\s*:\s*(\w+)\??[,)]")
ENUM_USE = re.compile(r"\bEnum\.(\w+)\.(\w+)\b")


def check_file(path, properties, enums, by_name):
    """One pass, in order, so a name means what the most recent assignment
    above it made it mean. Scanning assignments first and uses second read
    `local layout = Instance.new("UIGridLayout")` as whatever the *last*
    layout in the file was, and reported grid properties as errors on a
    perfectly correct line."""
    problems = []
    with open(path, encoding="utf-8") as handle:
        lines = handle.readlines()

    classes = dict(KNOWN_GLOBALS)
    relative = os.path.relpath(path, ROOT)

    for number, line in enumerate(lines, 1):
        if line.lstrip().startswith("--"):
            continue

        # Typed parameters describe their instance as well as a constructor
        # does, and most of the code that decorates the world takes its parts
        # that way.
        for name, annotated in PARAM.findall(line):
            if annotated in by_name:
                classes[name] = annotated

        # Instance.new on a class that does not exist, or that the engine
        # refuses to construct, throws — and a throw at module scope means the
        # require fails and every service behind it goes with it.
        for made in NEW.findall(line):
            if made not in by_name:
                problems.append(f"{relative}:{number}: there is no class {made}")
            elif "NotCreatable" in (by_name[made].get("Tags") or []):
                problems.append(
                    f"{relative}:{number}: {made} cannot be built with Instance.new"
                )
            elif "Service" in (by_name[made].get("Tags") or []):
                problems.append(
                    f"{relative}:{number}: {made} is a service — use game:GetService"
                )

        match = ASSIGN.match(line)
        if match:
            name, value = match.group(1), match.group(2)
            made = NEW.search(value)
            if made:
                classes[name] = made.group(1)
            else:
                for helper, produced in HELPER_RETURNS.items():
                    if value.startswith(helper + "("):
                        classes[name] = produced

        setter = SET.match(line)
        if setter:
            holder, prop = setter.group(1), setter.group(2)
            class_name = classes.get(holder)
            if class_name and class_name in by_name:
                member = properties(class_name).get(prop)
                if member is None:
                    problems.append(
                        f"{relative}:{number}: {class_name} has no property {prop}"
                    )
                else:
                    write = member.get("Security", {})
                    write = write.get("Write") if isinstance(write, dict) else write
                    if write not in OPEN:
                        problems.append(
                            f"{relative}:{number}: {class_name}.{prop} is {write}"
                            " — a game script may not write it"
                        )

        for category, item in ENUM_USE.findall(line):
            if category in enums and item not in enums[category]:
                problems.append(
                    f"{relative}:{number}: Enum.{category}.{item} does not exist"
                )
            elif category not in enums:
                problems.append(f"{relative}:{number}: there is no Enum.{category}")

    return problems


OPEN_STORE = re.compile(r":Get(?:Ordered|Global)?DataStore\(")


def check_datastore_opens():
    """Opening a DataStore has to be inside a pcall.

    In Studio, on a place that has not been published or with API access off,
    GetDataStore throws. Every one of these calls sits at module scope, so the
    throw does not fail one save — it fails the require, and every service
    that depends on that module fails with it. That is how a missing save
    system turned into twenty-three dead services and an empty world.
    """
    problems = []
    for folder, _, names in os.walk(os.path.join(ROOT, "src")):
        for name in sorted(names):
            if not name.endswith(".luau"):
                continue
            path = os.path.join(folder, name)
            with open(path, encoding="utf-8") as handle:
                lines = handle.readlines()
            for number, line in enumerate(lines, 1):
                if line.lstrip().startswith("--") or not OPEN_STORE.search(line):
                    continue
                window = "".join(lines[max(0, number - 6) : number + 1])
                if "pcall" not in window:
                    problems.append(
                        f"{os.path.relpath(path, ROOT)}:{number}: opening a DataStore"
                        " outside a pcall — this throws in Studio and takes the"
                        " whole module with it"
                    )
    return problems


# Built-in sound paths a game is actually allowed to play.
#
# rbxasset://sounds/ holds more than this, but not all of it is ours to use:
# swoosh.wav answers with "Asset is not approved for the requester", which
# Roblox reports as a WARNING. The sound is silent, the game carries on, and
# the only evidence is a line in the Output. That is the worst failure shape
# there is, so the set is pinned here.
#
# Every entry has been seen loading in a live session. Adding one means
# playing it in Studio first and reading the Output — there is no offline way
# to tell an allowed path from a forbidden one.
PLAYABLE_BUILTINS = {
    "rbxasset://sounds/bass.wav",
    "rbxasset://sounds/snap.wav",
    "rbxasset://sounds/electronicpingshort.wav",
    "rbxasset://sounds/clickfast.wav",
}

BUILTIN_USE = re.compile(r'"(rbxasset://sounds/[^"]+)"')


def check_builtin_sounds():
    problems = []
    for folder, _, names in os.walk(os.path.join(ROOT, "src")):
        for name in sorted(names):
            if not name.endswith(".luau"):
                continue
            path = os.path.join(folder, name)
            with open(path, encoding="utf-8") as handle:
                lines = handle.readlines()
            for number, line in enumerate(lines, 1):
                if line.lstrip().startswith("--"):
                    continue
                for used in BUILTIN_USE.findall(line):
                    if used not in PLAYABLE_BUILTINS:
                        problems.append(
                            f"{os.path.relpath(path, ROOT)}:{number}: {used} is not on the"
                            " list of built-ins proven to load — play it in Studio first"
                        )
    return problems


def main():
    if not os.path.exists(DUMP):
        print("skipped: tools/api-dump.json is not present (see the header of this file)")
        return 0

    by_name, properties, enums = load_dump()

    problems = []
    files = 0
    for folder, _, names in os.walk(os.path.join(ROOT, "src")):
        for name in sorted(names):
            if name.endswith(".luau"):
                files += 1
                problems += check_file(os.path.join(folder, name), properties, enums, by_name)

    problems += check_datastore_opens()
    problems += check_builtin_sounds()

    for problem in problems:
        print(f"  FAIL {problem}")

    print(f"\n{files} files checked against the Roblox API, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
