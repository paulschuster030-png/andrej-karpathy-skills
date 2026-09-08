# ⛏️ DEEP RUSH

Ein vollständiges, eigenständiges Roblox-Spiel. Kein Template, kein Fork —
Ökonomie, Weltgenerierung, Aufgabensystem, Live-Event, Diebstahl-Mechanik,
Speicherung und UI sind hier von Grund auf gebaut.

**Der Loop in einem Satz:** Du springst in einen Schacht, jeder Meter nach
unten multipliziert deine Beute *und* dein Risiko — bring sie hoch und bunkere
sie, oder verliere alles an die Tiefe oder an einen anderen Spieler.

---

## In 3 Minuten spielbar

1. **Roblox Studio öffnen** → `File ▸ Open from File…`
2. **`build/DeepRush.rbxlx`** auswählen (die Datei liegt fertig im Repo)
3. **Play (F5)** drücken

Das war's. Die Welt wird zur Laufzeit generiert, es gibt nichts zu importieren.

### Hochladen

1. `File ▸ Publish to Roblox As…` → neuen Platz anlegen
2. Im Creator-Dashboard: **Game Settings ▸ Security ▸ Enable Studio Access to
   API Services = AN** (sonst speichert nichts — siehe Troubleshooting)
3. Platz auf **Public** stellen

> **Wichtig zum Testen:** DataStores funktionieren nicht im lokalen
> Studio-Playtest, bevor der Platz einmal veröffentlicht wurde. Bis dahin
> kannst du in `src/shared/Config/Game.luau` `UseDataStores = false` setzen —
> dann läuft alles im Speicher und du testest ohne Fehler im Output.

---

## Wenn du mit Rojo arbeitest

`default.project.json` bildet exakt dieselbe Struktur ab wie der Builder:

```bash
rojo serve            # live-sync nach Studio
rojo build -o build/DeepRush.rbxlx
```

Ohne Rojo erzeugst du die Place-Datei mit dem mitgelieferten Builder:

```bash
node tools/build-rbxlx.mjs
```

---

## Projektstruktur

```
src/shared/          ReplicatedStorage/Shared — von Server UND Client genutzt
  Config/            das gesamte Balancing als reine Daten
    Game.luau        globale Stellschrauben (Tempo, Risiko, Timer)
    Ores.luau        8 Seltenheitsstufen, 30 Erze, Tiefen-Gating
    Layers.luau      9 Schichten von Topsoil bis Singularity
    Mutations.luau   die Multiplikatoren, die Screenshots erzeugen
    Upgrades.luau    7 Upgrade-Linien mit Kostenkurven
    Quests.luau      Onboarding-Kette, Daily-Pool, Meilensteine
    Rebirth.luau     Prestige-Anforderungen und Boni
    Drones.luau      die Sammel-Ebene
    Products.luau    Gamepasses und Dev-Products (IDs eintragen!)
  Net.luau           jedes Remote an einem Ort, mit Rate-Limit
  Rarity.luau        gewichteter Roll + ehrliche Quotenanzeige
  Format.luau        Zahlenformatierung (12.4K statt 12400)
  Signal.luau        minimaler Observer

src/server/          ServerScriptService/Server — autoritativ
  Bootstrap.server.luau   Startreihenfolge = Abhängigkeitsreihenfolge
  Data.luau          Profile, DataStore mit Session-Lock, Autosave
  Economy.luau       eine Quelle der Wahrheit für Luck/Cash/Kapazität
  World.luau         gechunkter 3.000-m-Schacht, Erz-Nodes, Kisten
  Mining.luau        der Schwung, der Roll, der Zahlen-Pop
  Cargo.luau         ungebunkerte Beute + Gier-Messung
  Surface.luau       Lift nach oben, Bank an der Oberfläche
  Steal.luau         Kisten und Snatch — die soziale Mechanik
  Quests.luau        alle Aufgaben, ein Eintrittspunkt
  Rift.luau          das serverweite Live-Event
  Hazards.luau       Sauerstoff und Schichtgefahren
  Upgrades / Rebirth / Drones / Rewards / Leaderboards
  Monetization.luau  Gamepasses + idempotenter Receipt-Handler
  AntiCheat.luau     Bewegungsplausibilität

src/client/          StarterPlayerScripts/Client — nur Darstellung + Absicht
  Client.client.luau  Startreihenfolge
  State.luau         eine lokale Kopie des Spielerzustands
  Hud.luau           Tiefe, Fracht, kontextuelle Aktionsknöpfe
  Mining.luau        Zielerfassung nach Kamerablick
  Panels.luau        Shop, Aufgaben, Codex, Drohnen, Boards, Rebirth
  Notify.luau        Toasts und die Rare-Pull-Karte
  Onboarding.luau    die ersten zwei Minuten
  Effects.luau       Shake, Partikel, schwebende Zahlen
  Ui.luau            das kleinstmögliche UI-Kit

tools/
  build-rbxlx.mjs    Quellbaum → Place-Datei
  balance-check.py   fährt die Ökonomie außerhalb von Roblox
  balance-spec.luau  25 Design-Zusagen als Assertions
```

---

## Verifikation

Der Code ist nicht nur geschrieben, sondern geprüft:

```bash
# Syntax/Compile aller 41 Luau-Dateien (braucht die Luau-CLI)
find src -name '*.luau' -exec luau-compile --null -O2 {} \;

# Die Ökonomie tatsächlich ausrechnen, nicht schätzen
python3 tools/balance-check.py /pfad/zu/luau
```

`balance-spec.luau` prüft Zusagen, keine Implementierungsdetails — z. B.
"tiefer graben lohnt sich immer", "Luck erhöht seltene Quoten streng monoton",
"das erste Rebirth dauert 15–90 Minuten". Zwei echte Bugs sind dabei
aufgefallen: `Format.short` hat runde Zahlen um den Faktor 10 verkleinert
(`250000` → `"25K"`), und Rebirth war für 25.000 Cash zu haben, während die
Upgrade-Leiter bis 77M reicht.

---

## Bevor du live gehst

| Schritt | Wo |
|---|---|
| Gamepass- und Product-IDs eintragen | `src/shared/Config/Products.luau` |
| Titel, Thumbnail, Beschreibung | Creator-Dashboard — siehe `LAUNCH_PLAYBOOK.md` |
| API-Zugriff für DataStores aktivieren | Game Settings ▸ Security |
| Balancing anpassen | `src/shared/Config/Game.luau` |

Alle Produkte sind mit `assetId = 0` vorkonfiguriert und werden dann schlicht
nicht angezeigt. Das Spiel ist ohne einen einzigen Robux vollständig
durchspielbar — Passes verkaufen Zeit und Komfort, nie exklusive Inhalte.

---

## Troubleshooting

**"Nichts wird gespeichert"** — API-Zugriff im Dashboard aktivieren, oder
`UseDataStores = false` für lokale Tests setzen.

**"Ich sehe keine Erze"** — die Welt wird um Spieler herum generiert. Spring in
den Schacht; die ersten Vorsprünge liegen ab ca. 20 m.

**"Der Bank-Knopf fehlt"** — er erscheint nur, wenn du am Tresor stehst *und*
Fracht dabei hast. Das ist Absicht: sichtbare Knöpfe sind immer nutzbare Knöpfe.

**"Mein Freund kann mich nicht beklauen"** — Spieler unter 10 Minuten Spielzeit
und 100 m Tiefe sind vollständig immun, und stehlen kann man nur von Spielern,
deren Frachtraum über 60 % voll ist.

---

Design-Begründungen: [`GAME_DESIGN.md`](GAME_DESIGN.md) ·
Launch und Monetarisierung: [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md)
