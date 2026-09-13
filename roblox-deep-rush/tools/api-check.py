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

# Security levels a normal game script is allowed to write.
OPEN = {"None", "PluginSecurity"}

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

    for problem in problems:
        print(f"  FAIL {problem}")

    print(f"\n{files} files checked against the Roblox API, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
