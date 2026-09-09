# Cover

Fertige Bilder für die Roblox-Store-Seite. Alles hier ist gerendert, nicht
gezeichnet — Quelle ist HTML/SVG, damit du Text und Zahlen ändern kannst,
ohne einen Grafikeditor zu öffnen.

## Was du hochlädst

| Datei | Größe | Wohin |
|---|---|---|
| `out/deeprush-icon-512.png` | 512×512 | Game Icon |
| `out/deeprush-thumbnail-1-depth.png` | 1920×1080 | Thumbnail 1 (Haupt) |
| `out/deeprush-thumbnail-2-rarity.png` | 1920×1080 | Thumbnail 2 |
| `out/deeprush-thumbnail-3-steal.png` | 1920×1080 | Thumbnail 3 |

Die beiden `*-check.png` sind **Prüfbilder, keine Uploads**: Sie zeigen das
Icon bei 150 px und das Thumbnail bei 384 px — die Größen, in denen sie
tatsächlich angeklickt werden. Wenn eine Änderung dort nicht mehr lesbar ist,
ist sie keine Verbesserung.

## Warum drei Thumbnails

Sie verkaufen drei verschiedene Spiele an drei verschiedene Leute:

1. **DIG OR LOSE IT** — der Risiko-Hook. Für Spieler, die den Loop wollen.
2. **1 IN 540,000** — der Seltenheits-Hook. Für RNG-Jäger.
3. **THEY CAN TAKE IT** — der Diebstahl-Hook. Der mit der höchsten Chance,
   weitergeschickt zu werden, weil ein zweiter Mensch drauf ist.

Roblox lässt mehrere Thumbnails zu. Lade alle drei hoch, warte eine Woche und
sieh im Dashboard nach, welches die beste qPTR hat. Der Unterschied zwischen
zwei Bildern desselben Spiels liegt regelmäßig beim Faktor zwei bis drei —
das ist der größte einzelne Hebel, den du auf die Reichweite hast.

## Ändern und neu bauen

```bash
node cover/render.mjs
```

Braucht nur Node und Chromium (Pfad über `CHROME_BIN` überschreibbar). Keine
npm-Installation: der PNG-Zuschnitt und das Herunterskalieren stecken in
`png.mjs` und laufen auf Node's eingebautem zlib.

- **Text ändern:** direkt in `thumb-*.html`.
- **Farben:** `assets/base.css`, oben in `:root`.
- **Tunnel:** `assets/shaft.js` — Mündung, Kern, Ringzahl, Farbton.
- **Figur:** `assets/figures.js`.

### Deinen echten Avatar einsetzen

```bash
node cover/avatar.mjs DEIN_ROBLOX_NAME
node cover/render.mjs
```

Holt einen transparenten Ganzkörper-Render deines aktuellen Avatars über die
offizielle Roblox-Thumbnails-API nach `assets/avatar.png`. Richte das nur auf
einen Account, der dir gehört.

**Warum trotzdem eine gezeichnete Figur die Voreinstellung ist:** sie
funktioniert immer, braucht keinen Account, kann nicht versehentlich die
Ähnlichkeit einer fremden Person sein — und sie lässt sich posen. Ein
API-Render kommt in fester Standardpose; der gezeichnete R6-Miner hier hält
eine Spitzhacke, fällt, und guckt erschrocken.

Der Vorteil deines echten Avatars ist **Wiedererkennung**: dasselbe Outfit auf
jedem Thumbnail, das du je machst, so wie Roblox-Kanäle aufgebaut werden. Wenn
du regelmäßig postest, ist das den Tausch wert.

## Was beim Bauen gelernt wurde

Zwei Dinge, die nicht offensichtlich waren und beide im Code kommentiert sind:

**Headless Chromium schneidet unten ab.** `--window-size` schließt die
Browser-Chrome ein, der gemalte Viewport ist ~87 px kürzer als angefordert.
`render.mjs` misst diesen Versatz beim Start mit einer Probe-Seite, statt 87
fest zu verdrahten — es ist ein Implementierungsdetail und ändert sich ohne
Ankündigung.

**Zwei SVGs auf einer Seite teilen sich ihre `id`s.** Beide Figuren im
Diebstahl-Thumbnail definierten `<filter id="rimlight">`; die erste Definition
gewann für beide, und der magenta markierte Spieler bekam die amber Kontur des
Diebs. Jede Instanz hängt jetzt einen Zähler an ihre IDs.

**Gelenkwinkel sind leicht zu spiegeln.** In `robloxian.js` hängt ein Glied vom
Gelenk mit Offset (0,−1,0); eine Z-Drehung um θ schwingt sein Ende nach
(sin θ, −cos θ). 0 hängt nach unten, 180 zeigt nach oben. Beim ersten Versuch
hatte ich das umgekehrt im Kopf — beide Arme lagen vor der Brust und die Beine
verschmolzen zu einem Klotz.
