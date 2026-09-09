#!/usr/bin/env python3
"""
audio-check.py — prove the loops actually loop.

"Seamless" is a claim, and an audible click at the loop point is the single
most common way generated ambience gives itself away. This measures it: the
jump from the last sample back to the first, against the loudest
sample-to-sample step anywhere inside the file. If the seam is not
dramatically larger than normal interior movement, there is nothing to hear.

Usage:  python3 tools/audio-check.py
"""

import os
import re
import sys

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio")

LOOPS = [
    "ambience-surface", "ambience-shallow", "ambience-deep", "ambience-abyss",
    "zone-gas", "zone-vent", "lift-motor",
]

ONE_SHOTS = ["pick-hit", "rare-reveal"]

# A seam within this multiple of the loudest interior step is inaudible.
TOLERANCE = 3.0


def main() -> int:
    problems = 0

    print(f"{'file':24s} {'seam':>10s} {'p99.9 step':>12s}  verdict")
    for name in LOOPS:
        path = os.path.join(AUDIO, name + ".ogg")
        if not os.path.exists(path):
            print(f"{name:24s} {'':>10s} {'':>12s}  MISSING")
            problems += 1
            continue

        data, _ = sf.read(path)
        interior = float(np.percentile(np.abs(np.diff(data)), 99.9))
        seam = float(abs(data[0] - data[-1]))
        ok = seam <= interior * TOLERANCE
        problems += 0 if ok else 1
        print(f"{name:24s} {seam:10.5f} {interior:12.5f}  {'seamless' if ok else 'CLICKS'}")

    for name in ONE_SHOTS:
        path = os.path.join(AUDIO, name + ".ogg")
        if not os.path.exists(path):
            print(f"{name:24s} MISSING")
            problems += 1
            continue
        data, _ = sf.read(path)
        # A one-shot must end in silence, or it clicks when it stops.
        tail = float(np.max(np.abs(data[-256:])))
        ok = tail < 0.02
        problems += 0 if ok else 1
        print(f"{name:24s} tail {tail:.5f}{'':17s}{'clean' if ok else 'ENDS ABRUPTLY'}")

    problems += check_upload_list()

    print(f"\n{len(LOOPS) + len(ONE_SHOTS) - problems}/{len(LOOPS) + len(ONE_SHOTS)} files good")
    return 1 if problems else 0


def check_upload_list():
    """Audio.Uploads is what the boot notice reads out. If it names a file that
    is not in audio/, the game tells the user to upload something that does not
    exist; if a file is missing from the list, they never hear about it."""
    config = os.path.join(ROOT, "src", "shared", "Config", "Audio.luau")
    body = open(config, encoding="utf-8").read()
    block = body.split("Audio.Uploads = {", 1)[1].split("\n}", 1)[0]
    listed = re.findall(r'file = "audio/([^"]+)"', block)
    on_disk = {n + ".ogg" for n in LOOPS} | {n + ".ogg" for n in ONE_SHOTS}

    problems = 0
    for name in listed:
        if name not in on_disk:
            print(f"upload list names {name}, which is not in audio/")
            problems += 1
    for name in sorted(on_disk - set(listed)):
        print(f"{name} exists but Audio.Uploads never mentions it")
        problems += 1
    if problems == 0:
        print(f"\nupload list: {len(listed)} slots, every one backed by a real file")
    return problems


if __name__ == "__main__":
    raise SystemExit(main())
