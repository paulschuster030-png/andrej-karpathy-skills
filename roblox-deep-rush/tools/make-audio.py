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


# A shared key: D minor pentatonic, rooted on D.
#
# This is the single biggest thing that made the old set unpleasant. The four
# ambience layers CROSSFADE by depth, so two of them are audible together for
# most of a descent — and their drones sat on 58, 48, 34 and 22 Hz, which are
# unrelated pitches. Two unrelated drones do not sound atmospheric, they beat
# against each other, and after ten minutes that is a headache rather than a
# mood. Every tone in the game now comes from this one scale, so any two
# layers heard at once are consonant by construction.
ROOT = 36.708  # D1
PENTATONIC = [0, 3, 5, 7, 10]  # minor pentatonic, in semitones


def note(degree, octave=0):
    """A pitch from the scale. `degree` may run past the end; it wraps up."""
    step = PENTATONIC[degree % len(PENTATONIC)] + 12 * (degree // len(PENTATONIC))
    return ROOT * 2 ** ((step + 12 * octave) / 12)


def breathe(seconds, period, depth, rate=RATE):
    """A slow amplitude swell whose period divides the loop exactly.

    Without it a bed is the same in second 2 and second 22, and a listener
    stops hearing it as sound and starts hearing it as a flaw. The cycle count
    is rounded so the swell meets itself at the seam.
    """
    n = int(seconds * rate)
    t = np.arange(n) / rate
    cycles = max(1, round(seconds / period))
    return 1.0 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * cycles / seconds * t))


def bell(rng, degrees, octave=1, rate=RATE):
    """A soft struck tone from the scale, for the motif grains.

    Two partials and a long decay: enough to read as a pitch and a room,
    little enough that twenty of them scattered over half a minute never add
    up to a melody the player has to listen to.
    """
    length = int(rate * rng.uniform(1.4, 2.6))
    t = np.arange(length) / rate
    pitch = note(int(rng.choice(degrees)), octave)
    decay = rng.uniform(1.6, 2.8)
    body = np.sin(2 * np.pi * pitch * t) * np.exp(-t * decay)
    shine = np.sin(2 * np.pi * pitch * 2 * t) * np.exp(-t * decay * 1.7) * 0.28
    # A slow attack, so nothing in the bed ever starts with a click.
    attack = np.clip(t / 0.05, 0, 1)
    return (body + shine) * attack * rng.uniform(0.10, 0.2)


def taper(signal, seconds=0.25, rate=RATE):
    """Fade the last moments to silence.

    A one-shot that still has amplitude at its final sample clicks when it
    stops, which on a reveal card is the last thing a player hears after a
    1-in-4-million pull. The chord rings for two seconds either way; this only
    takes the last fraction of it.
    """
    out = np.array(signal, copy=True)
    length = min(int(seconds * rate), len(out))
    if length > 1:
        out[-length:] *= np.linspace(1.0, 0.0, length) ** 1.6
    return out


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
#
# Everything is darker than it was. The old beds ran bright noise straight up
# to 5kHz, which is exciting for ten seconds and fatiguing for an hour — and
# this is audio a player has running the entire time they are in the game.
# The exponential rolloffs are steeper and lower, the tonal content carries
# the interest instead, and each layer breathes on its own slow cycle.

def surface(seconds=24):
    wind = looping_noise(seconds, lambda f: (f ** -1.25) * np.exp(-f / 2600), seed=1)
    gusts = looping_noise(seconds, lambda f: np.exp(-((f - 0.11) ** 2) / 0.004), seed=2)
    gusts = gusts / (np.max(np.abs(gusts)) + 1e-9)
    # Distant machinery, on the root and its fifth rather than on 58 Hz.
    machinery = drone(seconds, [(note(0, 1), 0.05, 0.07), (note(3, 1), 0.022, 0.11)])
    open_air = sprinkle(seconds, 5, lambda r: bell(r, [0, 2, 4], octave=2), seed=3)
    bed = wind * (0.55 + 0.45 * gusts) * breathe(seconds, 11.0, 0.22)
    return normalise(bed + machinery + open_air * 0.5, 0.7)


def shallow(seconds=26):
    air = looping_noise(seconds, lambda f: (f ** -1.5) * np.exp(-f / 1500), seed=11)
    body = drone(seconds, [(note(0, 1), 0.10, 0.05), (note(2, 1), 0.05, 0.08), (note(4, 1), 0.022, 0.13)])
    drips = sprinkle(seconds, 20, drip, seed=12)
    motif = sprinkle(seconds, 9, lambda r: bell(r, [0, 2, 3, 4], octave=2), seed=13)
    return normalise(air * 0.7 * breathe(seconds, 13.0, 0.26) + body + drips * 0.35 + motif, 0.74)


def deep(seconds=28):
    pressure = looping_noise(seconds, lambda f: (f ** -1.8) * np.exp(-f / 620), seed=21)
    body = drone(seconds, [(note(0), 0.17, 0.03), (note(2), 0.07, 0.045), (note(4), 0.03, 0.07)])
    groans = sprinkle(seconds, 10, creak, seed=22)
    # Lower and sparser than the shallow motif: the same instrument, further
    # away, which is what makes descending feel like one continuous place.
    motif = sprinkle(seconds, 6, lambda r: bell(r, [0, 3, 4], octave=1), seed=23)
    return normalise(pressure * 0.78 * breathe(seconds, 14.0, 0.3) + body + groans * 0.5 + motif * 0.9, 0.76)


def abyss(seconds=30):
    sub = drone(seconds, [(note(0), 0.24, 0.017), (note(2), 0.08, 0.026), (note(3), 0.04, 0.04)])
    void = looping_noise(seconds, lambda f: (f ** -2.0) * np.exp(-f / 380), seed=31)
    # Only just audible, and now on the minor third rather than on a flat
    # 3.4kHz hiss: the layer should feel wrong, not sharp.
    shimmer = drone(seconds, [(note(1, 3), 0.012, 0.009), (note(3, 3), 0.007, 0.013)])
    groans = sprinkle(seconds, 14, creak, seed=33)
    motif = sprinkle(seconds, 4, lambda r: bell(r, [1, 3], octave=1), seed=34)
    bed = void * 0.8 * breathe(seconds, 15.0, 0.34)
    return normalise(sub + bed + shimmer + groans * 0.6 + motif * 0.8, 0.78)


def gas(seconds=8):
    # Narrower and lower than before. A gas pocket you stand next to for ten
    # seconds should not be the brightest thing in the mix.
    hiss = looping_noise(seconds, lambda f: np.exp(-((f - 1500) ** 2) / 1.2e6) * (f ** -0.3), seed=41)
    return normalise(hiss * breathe(seconds, 4.0, 0.3), 0.52)


def vent(seconds=10):
    roar = looping_noise(seconds, lambda f: (f ** -1.45) * np.exp(-f / 1100), seed=51)
    rumble = drone(seconds, [(note(0, 1), 0.15, 0.09), (note(2, 1), 0.06, 0.14)])
    return normalise(roar * 0.8 * breathe(seconds, 5.0, 0.35) + rumble, 0.66)


def lift(seconds=6):
    # Tuned to the key too, so standing on a pad does not fight the ambience.
    motor = drone(seconds, [(note(2, 2), 0.16, 0.0), (note(2, 3), 0.07, 0.0), (note(4, 3), 0.025, 0.0)])
    grind = looping_noise(seconds, lambda f: np.exp(-((f - 700) ** 2) / 2.0e5), seed=61)
    return normalise(motor * breathe(seconds, 3.0, 0.18) + grind * 0.28, 0.66)


def pick_hit(seconds=0.26):
    """The sound of the whole game, heard thousands of times a session.

    Shorter than it was, because a swing now lands up to four chops and a
    350ms tail smeared them into mush. Less white noise and more pitched body:
    noise reads as static, a tuned knock reads as stone.
    """
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(71)

    # The transient. Band-limited rather than white, so it is a crack and not
    # a hiss.
    grit = rng.normal(0, 1, n)
    grit = np.convolve(grit, np.ones(12) / 12, mode="same") * np.exp(-t * 150)

    knock = np.sin(2 * np.pi * note(0, 4) * t) * np.exp(-t * 40) * 0.8
    body = np.sin(2 * np.pi * note(0, 3) * t) * np.exp(-t * 22) * 0.55
    thud = np.sin(2 * np.pi * note(0, 1) * t) * np.exp(-t * 18) * 0.45
    return normalise(taper(grit * 0.35 + knock + body + thud, 0.04), 0.88)


def reveal(seconds=2.4):
    """The sound a screenshot is taken to.

    Four notes of the scale, struck in sequence and left to ring together, so
    it lands as a chord rather than as a siren. It resolves upward — the last
    note is the highest and it is the root.
    """
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    out = np.zeros(n)

    for index, degree in enumerate([0, 2, 4, 5]):
        offset = int(index * 0.085 * RATE)
        span = n - offset
        local = t[:span]
        pitch = note(degree, 4)
        voice = (
            np.sin(2 * np.pi * pitch * local) * np.exp(-local * 1.5)
            + np.sin(2 * np.pi * pitch * 2 * local) * np.exp(-local * 2.6) * 0.3
            + np.sin(2 * np.pi * pitch * 3 * local) * np.exp(-local * 4.0) * 0.12
        )
        out[offset:] += voice * np.clip(local / 0.01, 0, 1) * (0.9 - index * 0.1)

    # A breath of air under it, so the chord has a room to be in.
    air = np.random.default_rng(81).normal(0, 1, n)
    air = np.convolve(air, np.ones(24) / 24, mode="same") * np.exp(-t * 3.2) * 0.10
    return normalise(taper(out + air, 0.35), 0.9)


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
