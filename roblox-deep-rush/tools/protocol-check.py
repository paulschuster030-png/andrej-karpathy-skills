#!/usr/bin/env python3
"""
protocol-check.py — verify that the client and server agree on every remote.

Net.luau declares the whole protocol in one place, which makes a specific
class of bug easy to write and impossible to see: a remote that one side uses
and the other never does. It compiles, it runs, and the feature is simply
absent.

That is not hypothetical. This check found that `GrabCrate` had a server
handler and no caller anywhere in the client — dropped cargo crates, one of
the game's core mechanics, could not be picked up by hand at all.

Run:  python3 tools/protocol-check.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")


def read_all(folder: str) -> str:
    path = os.path.join(SRC, folder)
    return "".join(
        open(os.path.join(path, name), encoding="utf-8").read()
        for name in sorted(os.listdir(path))
        if name.endswith(".luau")
    )


def main() -> int:
    net = open(os.path.join(SRC, "shared", "Net.luau"), encoding="utf-8").read()
    server = read_all("server")
    client = read_all("client")

    events_block = re.search(r"Net\.Events = \{(.*?)\n\}", net, re.S).group(1)
    events = re.findall(r"^\t(\w+) = [\d.]+,", events_block, re.M)

    signals_block = re.search(r"Net\.Signals = \{(.*?)\n\}", net, re.S).group(1)
    signals = re.findall(r'"(\w+)"', signals_block)

    functions_block = re.search(r"Net\.Functions = \{(.*?)\n\}", net, re.S).group(1)
    functions = re.findall(r'"(\w+)"', functions_block)

    problems = []

    for event in events:
        if f'Net.on("{event}"' not in server:
            problems.append(f"event {event}: declared, but no server handler")
        if f'Net.fire("{event}"' not in client:
            problems.append(f"event {event}: declared, but the client never fires it")

    for signal in signals:
        if f'"{signal}"' not in server:
            problems.append(f"signal {signal}: declared, but the server never sends it")
        if f'Net.listen("{signal}"' not in client:
            problems.append(f"signal {signal}: declared, but the client never listens")

    for function in functions:
        if f'Net.handle("{function}"' not in server:
            problems.append(f"function {function}: declared, but no server handler")
        if f'Net.invoke("{function}"' not in client:
            problems.append(f"function {function}: declared, but the client never invokes it")

    for problem in problems:
        print(f"  FAIL {problem}")

    problems += check_boot_order()

    total = len(events) + len(signals) + len(functions)
    print(f"\n{total} remotes checked, {len(problems)} problems")
    return 1 if problems else 0


def check_boot_order():
    """Nobody may spawn before the world is generated.

    This one is static because Bootstrap is a Script, not a module: the
    simulator drives the services directly and never runs it, so the guard
    around them is exactly the code no other check can see. Losing it puts a
    player in an empty sky, which is what it looked like the first time.
    """
    path = os.path.join(ROOT, "src", "server", "Bootstrap.server.luau")
    with open(path, encoding="utf-8") as handle:
        source = handle.read()

    problems = []
    off = source.find("Players.CharacterAutoLoads = false")
    on = source.find("Players.CharacterAutoLoads = true")
    first_start = source.find("service.start")

    if off < 0 or on < 0:
        problems.append("Bootstrap no longer holds character spawning until the world is built")
    elif not (off < first_start < on):
        problems.append("Bootstrap re-enables spawning before the services have started")
    else:
        print("  ok   characters are held back until the world exists")

    if "LoadCharacter" not in source:
        problems.append("Bootstrap never loads the characters it held back")

    for problem in problems:
        print(f"  FAIL {problem}")
    return problems


if __name__ == "__main__":
    raise SystemExit(main())
