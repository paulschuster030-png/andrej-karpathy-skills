#!/usr/bin/env python3
"""Keep the middle of the screen clear.

A mining game is played by looking at a rock and holding a button. Anything
parked over the middle of the screen is parked over the rock — and unlike a
crash, nobody finds out until a player sends a photo of their monitor.

So the layout is computed here rather than eyeballed: every panel's rectangle
is worked out on a reference screen and checked against the aiming zone.

Modal UI is exempt by file: the intro card, the reveal card and the panel
overlay are *supposed* to cover the view, that is what they are for.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CLIENT = os.path.join(ROOT, "src", "client")

# A 16:9 desktop window. The zone scales with the screen, so the exact
# reference only decides how offsets in pixels weigh against scale terms.
SCREEN_W, SCREEN_H = 1280, 720

# The middle 30% across and 50% down: where the reticle sits and where the
# rock you are aiming at appears.
#
# Calibrated against the layout a player actually complained about, not
# guessed. At 40%/30% this box cleared both offenders and would have shipped
# the same screenshot again — the tall-and-narrow shape is what matters,
# because the panels stacked UP the centre column rather than across it.
ZONE = (0.35 * SCREEN_W, 0.25 * SCREEN_H, 0.65 * SCREEN_W, 0.75 * SCREEN_H)

# Files whose whole job is to cover the screen.
MODAL = {"Intro.luau", "Notify.luau", "Panels.luau", "Ui.luau"}

# The one builder whose output belongs in the middle: the aim indicator
# itself. Named by function, because the local inside it is just `holder`.
ALLOWED = {"buildReticle"}

CALL = re.compile(r"Ui\.(frame|button|bar)\(\{")
UDIM_NEW = re.compile(r"UDim2\.new\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)")
UDIM_OFFSET = re.compile(r"UDim2\.fromOffset\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)")
UDIM_SCALE = re.compile(r"UDim2\.fromScale\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)")
VEC2 = re.compile(r"Vector2\.new\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*\)")


def udim(text, screen_w, screen_h):
    """Resolve a UDim2 literal to pixels, or None if it is not a literal."""
    match = UDIM_NEW.search(text)
    if match:
        sx, ox, sy, oy = (float(g) for g in match.groups())
        return sx * screen_w + ox, sy * screen_h + oy
    match = UDIM_OFFSET.search(text)
    if match:
        return float(match.group(1)), float(match.group(2))
    match = UDIM_SCALE.search(text)
    if match:
        return float(match.group(1)) * screen_w, float(match.group(2)) * screen_h
    return None


def blocks(source):
    """Every Ui.frame/button/bar call, as (start line, body)."""
    for match in CALL.finditer(source):
        depth = 0
        index = match.end() - 1
        while index < len(source):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    break
            index += 1
        yield source[: match.start()].count("\n") + 1, source[match.end() : index]


def prop(body, name):
    match = re.search(rf"\b{name}\s*=\s*([^\n]+)", body)
    return match.group(1) if match else None


def main():
    problems = []
    checked = 0

    for name in sorted(os.listdir(CLIENT)):
        if not name.endswith(".luau") or name in MODAL:
            continue
        path = os.path.join(CLIENT, name)
        with open(path, encoding="utf-8") as handle:
            source = handle.read()

        for line, body in blocks(source):
            size_text, position_text = prop(body, "size"), prop(body, "position")
            if not size_text or not position_text:
                continue
            size = udim(size_text, SCREEN_W, SCREEN_H)
            position = udim(position_text, SCREEN_W, SCREEN_H)
            if not size or not position:
                continue

            anchor = (0.0, 0.0)
            anchor_text = prop(body, "anchor")
            if anchor_text:
                match = VEC2.search(anchor_text)
                if match:
                    anchor = (float(match.group(1)), float(match.group(2)))

            width, height = size
            left = position[0] - anchor[0] * width
            top = position[1] - anchor[1] * height
            right, bottom = left + width, top + height

            zl, zt, zr, zb = ZONE
            if right <= zl or left >= zr or bottom <= zt or top >= zb:
                checked += 1
                continue

            # Attribute it to the builder it lives in — that is the unit a
            # reader thinks in, and it survives renaming a local.
            owner = ""
            for match in re.finditer(r"local function (\w+)\(", source):
                if source[: match.start()].count("\n") + 1 <= line:
                    owner = match.group(1)
                else:
                    break

            checked += 1
            if owner in ALLOWED:
                continue
            problems.append(
                f"src/client/{name}:{line}: a {int(width)}x{int(height)} panel"
                f" at ({int(left)},{int(top)}) sits over the aiming zone"
                + (f" [{owner}]" if owner else "")
            )

    for problem in problems:
        print(f"  FAIL {problem}")
    print(f"\n{checked} panels checked against the aiming zone, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
