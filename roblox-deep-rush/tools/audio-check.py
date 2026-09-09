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

    print(f"\n{len(LOOPS) + len(ONE_SHOTS) - problems}/{len(LOOPS) + len(ONE_SHOTS)} files good")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
