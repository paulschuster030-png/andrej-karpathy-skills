#!/usr/bin/env python3
"""
make-audio.py — synthesise the game's ambience and effects.

Why generate rather than link: a guessed Roblox catalogue id either fails to
load or plays something unrelated, and you only find out in a live place.
These are real files. You upload them once, paste the ids into
src/shared/Config/Audio.luau, and the audio is yours.

The looping trick that makes this work: every layer is built in the FREQUENCY
domain and converted back with an inverse FFT. A signal made that way is
exactly periodic over its buffer, so the end meets the beginning with no click
and no crossfade — which is very hard to achieve by editing recorded audio and
free if you generate it.

Usage:  python3 tools/make-audio.py
Output: audio/*.ogg  plus audio/README.md
"""

import os

import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio")
RATE = 44100

# Needs `pip install numpy soundfile`. soundfile bundles libsndfile, which
# writes Vorbis directly — no ffmpeg, no system packages.


def looping_noise(seconds, shape, seed, rate=RATE):
    """Noise with a shaped spectrum that loops seamlessly by construction."""
    n = int(seconds * rate)
    rng = np.random.default_rng(seed)
    freqs = np.fft.rfftfreq(n, 1 / rate)
    magnitude = shape(np.maximum(freqs, 1e-6))
    phase = rng.uniform(0, 2 * np.pi, freqs.shape)
    spectrum = magnitude * np.exp(1j * phase)
    spectrum[0] = 0.0
    return np.fft.irfft(spectrum, n)


def drone(seconds, partials, rate=RATE):
    """
    Sum of sines snapped to the loop's own harmonic grid.

    Snapping matters: a 41.7 Hz tone in a 20-second buffer does not complete a
    whole number of cycles, so the loop point clicks. Rounding each partial to
    the nearest multiple of 1/seconds costs a few cents of pitch and buys a
    perfect seam.
    """
    n = int(seconds * rate)
    t = np.arange(n) / rate
    out = np.zeros(n)
    for frequency, amplitude, drift in partials:
        cycles = max(1, round(frequency * seconds))
        snapped = cycles / seconds
        wobble = 1.0
        if drift:
            lfo_cycles = max(1, round(drift * seconds))
            wobble = 1.0 + 0.35 * np.sin(2 * np.pi * (lfo_cycles / seconds) * t)
        out += amplitude * wobble * np.sin(2 * np.pi * snapped * t)
    return out


def sprinkle(seconds, events, envelope, seed, rate=RATE):
    """
    Scatter short transients (drips, creaks) across the buffer, wrapping any
    that run past the end back to the start so the loop stays seamless.
    """
    n = int(seconds * rate)
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    for _ in range(events):
        start = rng.integers(0, n)
        grain = envelope(rng)
        end = start + len(grain)
        if end <= n:
            out[start:end] += grain
        else:
            split = n - start
            out[start:] += grain[:split]
            out[: end - n] += grain[split:]
    return out


def drip(rng, rate=RATE):
    length = int(rate * rng.uniform(0.05, 0.12))
    t = np.arange(length) / rate
    pitch = rng.uniform(700, 2200)
    body = np.sin(2 * np.pi * pitch * t) * np.exp(-t * rng.uniform(45, 90))
    return body * rng.uniform(0.25, 0.6)


def creak(rng, rate=RATE):
    length = int(rate * rng.uniform(0.3, 0.8))
    t = np.arange(length) / rate
    pitch = rng.uniform(70, 190)
    sweep = pitch * (1 + 0.25 * t / max(t[-1], 1e-6))
    body = np.sin(2 * np.pi * sweep * t) * np.sin(np.pi * t / max(t[-1], 1e-6))
    return body * rng.uniform(0.12, 0.3)


def normalise(signal, peak=0.85):
    highest = np.max(np.abs(signal))
    if highest < 1e-9:
        return signal
    return signal / highest * peak


def write_ogg(path, signal, rate=RATE):
    """
    Vorbis, mono. Roblox accepts .ogg and .mp3 for upload and nothing else,
    so a .wav here would be a file you cannot use.
    """
    data = np.clip(normalise(signal), -1, 1).astype("float32")
    sf.write(path, data, rate, format="OGG", subtype="VORBIS")


# --- The pieces ------------------------------------------------------------

def surface(seconds=24):
    wind = looping_noise(seconds, lambda f: (f ** -1.15) * np.exp(-f / 5200), seed=1)
    gusts = looping_noise(seconds, lambda f: np.exp(-((f - 0.11) ** 2) / 0.004), seed=2)
    gusts = gusts / (np.max(np.abs(gusts)) + 1e-9)
    machinery = drone(seconds, [(58, 0.05, 0.07), (116, 0.02, 0.11)])
    return normalise(wind * (0.55 + 0.45 * gusts) + machinery, 0.72)


def shallow(seconds=26):
    air = looping_noise(seconds, lambda f: (f ** -1.35) * np.exp(-f / 2600), seed=11)
    body = drone(seconds, [(48, 0.10, 0.05), (72, 0.05, 0.08), (96, 0.025, 0.13)])
    drips = sprinkle(seconds, 26, drip, seed=12)
    return normalise(air * 0.8 + body + drips * 0.5, 0.75)


def deep(seconds=28):
    pressure = looping_noise(seconds, lambda f: (f ** -1.7) * np.exp(-f / 900), seed=21)
    body = drone(seconds, [(34, 0.16, 0.03), (51, 0.07, 0.045), (68, 0.035, 0.07)])
    groans = sprinkle(seconds, 12, creak, seed=22)
    return normalise(pressure * 0.9 + body + groans * 0.7, 0.78)


def abyss(seconds=30):
    sub = drone(seconds, [(22, 0.22, 0.017), (33, 0.09, 0.026), (44, 0.05, 0.04)])
    void = looping_noise(seconds, lambda f: (f ** -1.9) * np.exp(-f / 500), seed=31)
    # A high shimmer that is only just audible: the layer should feel wrong
    # rather than loud.
    shimmer = looping_noise(seconds, lambda f: np.exp(-((f - 3400) ** 2) / 400000), seed=32)
    groans = sprinkle(seconds, 18, creak, seed=33)
    return normalise(sub + void * 0.85 + shimmer * 0.10 + groans * 0.8, 0.8)


def gas(seconds=8):
    hiss = looping_noise(seconds, lambda f: np.exp(-((f - 2600) ** 2) / 3.0e6) * (f ** -0.25), seed=41)
    return normalise(hiss, 0.6)


def vent(seconds=10):
    roar = looping_noise(seconds, lambda f: (f ** -1.25) * np.exp(-f / 1600), seed=51)
    rumble = drone(seconds, [(41, 0.14, 0.09), (62, 0.06, 0.14)])
    return normalise(roar * 0.9 + rumble, 0.72)


def lift(seconds=6):
    motor = drone(seconds, [(96, 0.16, 0.0), (192, 0.07, 0.0), (288, 0.03, 0.0)])
    grind = looping_noise(seconds, lambda f: np.exp(-((f - 900) ** 2) / 3.0e5), seed=61)
    return normalise(motor + grind * 0.35, 0.7)


def pick_hit(seconds=0.35):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    crack = np.random.default_rng(71).normal(0, 1, n) * np.exp(-t * 90)
    tone = np.sin(2 * np.pi * 240 * t) * np.exp(-t * 26) * 0.6
    thud = np.sin(2 * np.pi * 70 * t) * np.exp(-t * 16) * 0.5
    return normalise(crack * 0.5 + tone + thud, 0.9)


def reveal(seconds=2.2):
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    # A rising fifth with a shimmer tail: the sound a screenshot is taken to.
    sweep = np.sin(2 * np.pi * (330 + 330 * (t / seconds) ** 1.6) * t) * np.exp(-t * 1.6)
    fifth = np.sin(2 * np.pi * (495 + 495 * (t / seconds) ** 1.6) * t) * np.exp(-t * 1.9) * 0.6
    air = np.random.default_rng(81).normal(0, 1, n) * np.exp(-t * 5) * 0.12
    return normalise(sweep + fifth + air, 0.9)


PIECES = [
    ("ambience-surface", surface, "Ambience: the surface. Wind and distant machinery.", True),
    ("ambience-shallow", shallow, "Ambience: shallow layers. Moving air and dripping.", True),
    ("ambience-deep", deep, "Ambience: deep layers. Pressure and groaning rock.", True),
    ("ambience-abyss", abyss, "Ambience: the abyss. Sub drone and something wrong.", True),
    ("zone-gas", gas, "Positional loop for gas pockets.", True),
    ("zone-vent", vent, "Positional loop for magma vents and pressure wells.", True),
    ("lift-motor", lift, "Positional loop for lift pads.", True),
    ("pick-hit", pick_hit, "One-shot: pickaxe striking rock.", False),
    ("rare-reveal", reveal, "One-shot: a rare pull.", False),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []

    for name, builder, description, looping in PIECES:
        signal = builder()
        ogg_path = os.path.join(OUT, name + ".ogg")
        write_ogg(ogg_path, signal)
        size = os.path.getsize(ogg_path)
        seconds = len(signal) / RATE
        rows.append((name, seconds, size, description, looping))
        print(f"  {name+'.ogg':26s} {seconds:5.1f}s  {size/1024:6.1f} KB")

    with open(os.path.join(OUT, "README.md"), "w", encoding="utf-8") as handle:
        handle.write(build_readme(rows))
    print(f"\nwrote {len(rows)} files to audio/")


def build_readme(rows):
    lines = [
        "# Audio",
        "",
        "Fertige Sounds für DEEP RUSH. Alle Loops sind **nahtlos** — sie sind im",
        "Frequenzbereich erzeugt und damit exakt periodisch, es gibt also keinen",
        "Klick am Loop-Punkt.",
        "",
        "Erzeugt mit `python3 tools/make-audio.py`. Wenn dir etwas nicht gefällt:",
        "die Parameter stehen alle in dem Skript, neu erzeugen dauert Sekunden.",
        "",
        "## Hochladen (einmalig, ~5 Minuten)",
        "",
        "1. **Creator Dashboard ▸ Development Items ▸ Audio ▸ Upload Audio**",
        "2. Alle Dateien aus diesem Ordner hochladen",
        "3. Bei jeder Datei die **Asset-ID** kopieren (die Zahl in der URL)",
        "4. In `src/shared/Config/Audio.luau` eintragen:",
        "",
        "```lua",
        "Audio.Custom = {",
        '\tambienceSurface = "123456789",  -- nur die Zahl, ohne rbxassetid://',
        '\tambienceShallow = "...",',
        '\tambienceDeep    = "...",',
        '\tambienceAbyss   = "...",',
        "}",
        "```",
        "",
        "> **Hinweis:** Roblox prüft hochgeladene Audiodateien automatisch. Das",
        "> dauert meist Minuten. Vor Abschluss der Prüfung spielt die Datei nicht.",
        "",
        "## Die Dateien",
        "",
        "| Datei | Länge | Größe | Loop | Wofür |",
        "|---|---|---|---|---|",
    ]
    for name, seconds, size, description, looping in rows:
        lines.append(
            f"| `{name}.ogg` | {seconds:.1f}s | {size/1024:.0f} KB | "
            f"{'ja' if looping else 'nein'} | {description} |"
        )
    lines += [
        "",
        "## Wie sie im Spiel benutzt werden",
        "",
        "Die vier **ambience**-Dateien blenden nach Tiefe ineinander über — nichts",
        "schaltet um, alles läuft ineinander, damit die Tiefe gefühlt und nicht",
        "bemerkt wird. Siehe `src/client/Atmosphere.luau`.",
        "",
        "**zone-gas** und **zone-vent** hängen als 3D-Sound an den Gefahrenzonen:",
        "Du hörst sie, bevor du sie siehst, und die Lautstärke sagt dir, wie nah",
        "du dran bist. **lift-motor** macht dasselbe für Liftplattformen.",
        "",
        "Ohne eingetragene IDs fällt alles auf Roblox' eingebaute",
        "`rbxasset://`-Sounds zurück. Das Spiel ist dann nie stumm, klingt aber",
        "deutlich schlechter.",
        "",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    main()
