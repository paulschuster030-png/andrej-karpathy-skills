# Audio

Fertige Sounds für DEEP RUSH. Alle Loops sind **nahtlos** — sie sind im
Frequenzbereich erzeugt und damit exakt periodisch, es gibt also keinen
Klick am Loop-Punkt.

Erzeugt mit `python3 tools/make-audio.py`. Wenn dir etwas nicht gefällt:
die Parameter stehen alle in dem Skript, neu erzeugen dauert Sekunden.

## Hochladen (einmalig, ~5 Minuten)

1. **Creator Dashboard ▸ Development Items ▸ Audio ▸ Upload Audio**
2. Alle Dateien aus diesem Ordner hochladen
3. Bei jeder Datei die **Asset-ID** kopieren (die Zahl in der URL)
4. In `src/shared/Config/Audio.luau` eintragen:

```lua
Audio.Custom = {
	ambienceSurface = "123456789",  -- nur die Zahl, ohne rbxassetid://
	ambienceShallow = "...",
	ambienceDeep    = "...",
	ambienceAbyss   = "...",
}
```

> **Hinweis:** Roblox prüft hochgeladene Audiodateien automatisch. Das
> dauert meist Minuten. Vor Abschluss der Prüfung spielt die Datei nicht.

## Die Dateien

| Datei | Länge | Größe | Loop | Wofür |
|---|---|---|---|---|
| `ambience-surface.ogg` | 24.0s | 37 KB | ja | Ambience: the surface. Wind and distant machinery. |
| `ambience-shallow.ogg` | 26.0s | 49 KB | ja | Ambience: shallow layers. Moving air and dripping. |
| `ambience-deep.ogg` | 28.0s | 43 KB | ja | Ambience: deep layers. Pressure and groaning rock. |
| `ambience-abyss.ogg` | 30.0s | 51 KB | ja | Ambience: the abyss. Sub drone and something wrong. |
| `zone-gas.ogg` | 8.0s | 33 KB | ja | Positional loop for gas pockets. |
| `zone-vent.ogg` | 10.0s | 17 KB | ja | Positional loop for magma vents and pressure wells. |
| `lift-motor.ogg` | 6.0s | 14 KB | ja | Positional loop for lift pads. |
| `pick-hit.ogg` | 0.3s | 4 KB | nein | One-shot: pickaxe striking rock. |
| `rare-reveal.ogg` | 2.4s | 19 KB | nein | One-shot: a rare pull. |
| `music.ogg` | 210.0s | 428 KB | ja | The score. Long, sparse, and quieter the deeper you are. |

## Wie sie im Spiel benutzt werden

Die vier **ambience**-Dateien blenden nach Tiefe ineinander über — nichts
schaltet um, alles läuft ineinander, damit die Tiefe gefühlt und nicht
bemerkt wird. Siehe `src/client/Atmosphere.luau`.

**zone-gas** und **zone-vent** hängen als 3D-Sound an den Gefahrenzonen:
Du hörst sie, bevor du sie siehst, und die Lautstärke sagt dir, wie nah
du dran bist. **lift-motor** macht dasselbe für Liftplattformen.

Ohne eingetragene IDs fällt alles auf Roblox' eingebaute
`rbxasset://`-Sounds zurück. Das Spiel ist dann nie stumm, klingt aber
deutlich schlechter.
