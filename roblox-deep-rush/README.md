# ⛏️ DEEP RUSH

Ein vollständiges, eigenständiges Roblox-Spiel. Kein Template, kein Fork —
Ökonomie, Weltgenerierung, Aufgabensystem, Live-Event, Diebstahl-Mechanik,
Speicherung und UI sind hier von Grund auf gebaut.

**Der Loop in einem Satz:** Du springst in einen Schacht, jeder Meter nach
unten multipliziert deine Beute *und* dein Risiko — bring sie hoch und bunkere
sie, oder verliere alles an die Tiefe oder an einen anderen Spieler.

Fertige Store-Grafiken liegen in [`cover/`](cover/). Was sich seit der ersten
Fassung geändert hat und warum, steht in [`TRENDS.md`](TRENDS.md). Wie man
bezahlte Reichweite kauft, ohne Geld zu verbrennen, in
[`ADS_PLAYBOOK.md`](ADS_PLAYBOOK.md).

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
    Contracts.luau   Wochen-Leiter und 28-Tage-Log (Langzeitbindung)
    Season.luau      das Wochenend-Fenster mit dem exklusiven Badge
    Hazards.luau     die sichtbaren Gefahrenzonen
    Audio.luau       alle Sounds — hier deine eigenen Asset-IDs eintragen
    Crew.luau        Co-Play: Bonus, Pings, Rettung
    Cosmetics.luau   Lampen, Trails, Titel — die Status-Ebene
    Rebirth.luau     Prestige-Anforderungen und Boni
    Drones.luau      die Sammel-Ebene
    Products.luau    Gamepasses, Dev-Products, Daily Deals (IDs eintragen!)
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
  Contracts.luau     Wochen-Contract und Descent Log
  Season.luau        Live-Fenster, Season-Core, permanentes Badge
  Hazards.luau       Sauerstoff und Zonenschaden
  Crew.luau          Crew-Bildung, Ping-Broadcast, Nähe-Bonus
  Cosmetics.luau     sichtbarer Status auf dem Charakter
  Ads.luau           Rewarded Video (aus, bis konfiguriert)
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
  Crew.luau          Crew-Leiste, Ping-Reihe, Einladen-Knopf
  Atmosphere.luau    Licht, Nebel und Ambient-Ton nach Tiefe
  Intro.luau         die Regelkarte beim ersten Start
  Effects.luau       Shake, Partikel, schwebende Zahlen
  Ui.luau            das kleinstmögliche UI-Kit

tools/
  build-rbxlx.mjs    Quellbaum → Place-Datei
  balance-check.py   fährt die Ökonomie außerhalb von Roblox
  balance-spec.luau  43 Design-Zusagen als Assertions
  protocol-check.py  prüft, ob Client und Server dieselben Remotes benutzen

cover/
  render.mjs         HTML → fertige PNGs (nur Node + Chromium)
  avatar.mjs         holt deinen echten Roblox-Avatar als PNG
  png.mjs            Zuschnitt und Verkleinerung, ohne Abhängigkeiten
  assets/robloxian.js  der blockige R6-Charakter, als echte 3D-Boxen
  out/               die Dateien, die du hochlädst
```

---

## Verifikation

Der Code ist nicht nur geschrieben, sondern geprüft:

```bash
# Syntax/Compile aller 49 Luau-Dateien (braucht die Luau-CLI)
find src -name '*.luau' -exec luau-compile --null -O2 {} \;

# Die Ökonomie tatsächlich ausrechnen, nicht schätzen
python3 tools/balance-check.py /pfad/zu/luau

# Benutzen Client und Server dieselben Remotes?
python3 tools/protocol-check.py
```

`balance-spec.luau` prüft Zusagen, keine Implementierungsdetails — z. B.
"tiefer graben lohnt sich immer", "Luck erhöht seltene Quoten streng monoton",
"das erste Rebirth dauert 15–90 Minuten", "Co-Play steht nie auf dem
Onboarding-Pfad".

Die Prüfungen haben bisher vier echte Fehler gefunden, die sonst live gegangen
wären:

- `Format.short` hat runde Zahlen um den Faktor 10 verkleinert
  (`250000` → `"25K"`) — das betraf jede runde Zahl im HUD.
- Rebirth war für 25.000 Cash zu haben, während die Upgrade-Leiter bis 77M reicht.
- Contract-Punkte pro Cash-Betrag hätten einem Spätspiel-Spieler die
  Tagesgrenze mit **einer** Einzahlung gefüllt.
- **Heruntergefallene Frachtkisten konnten gar nicht aufgehoben werden**: der
  Server akzeptierte `GrabCrate`, aber kein Knopf im Client hat es je gesendet.

---

## Bevor du live gehst

| Schritt | Wo |
|---|---|
| Gamepass-, Product- und Daily-Deal-IDs eintragen | `src/shared/Config/Products.luau` |
| Icon und Thumbnails hochladen | `cover/out/` — siehe [`cover/README.md`](cover/README.md) |
| Titel und Beschreibung | Creator-Dashboard — siehe `LAUNCH_PLAYBOOK.md` |
| API-Zugriff für DataStores aktivieren | Game Settings ▸ Security |
| **Private Server aktivieren** | Game Settings — zahlt aufs Co-Play-Signal ein |
| Balancing anpassen | `src/shared/Config/Game.luau` |
| Season-Fenster verschieben | `src/shared/Config/Season.luau` |
| **Eigene Sounds eintragen** | `src/shared/Config/Audio.luau` |
| Werbung schalten | [`ADS_PLAYBOOK.md`](ADS_PLAYBOOK.md) |

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

**"Ich sterbe und weiß nicht warum"** — sollte nicht mehr passieren. Jede
Gefahr ist ein sichtbares, benanntes Objekt: leuchtende Zonen mit Schild
darüber. Grüne Wolken und Frostfelder tun weh, solange du drinstehst; die
pulsierenden (Vents, Druck, Einsturz) leuchten erst auf und feuern dann — die
haben einen festen Rhythmus, durch den man laufen kann. Die erste Schicht hat
gar keine Gefahren, damit man erst das Spiel lernt und dann das Ausweichen.

**"Der Crew-Bonus kommt nicht an"** — er wird fürs Zusammengraben gezahlt, nicht
fürs Zusammensein auf einer Liste: ihr müsst innerhalb von 120 Studs
voneinander sein. Die Crew-Leiste sagt "too far apart", wenn es nicht zählt.

**"Der Werbe-Knopf erscheint nie"** — das ist so gebaut. Er kommt erst, wenn du
eine Produkt-ID in `Products.RewardedVideo` einträgst *und* Roblox tatsächlich
eine Anzeige liefert. Voraussetzung sind u. a. 2.000 eindeutige Besucher/Monat.

**"Der Sound ist okay, aber nicht toll"** — stimmt. Das Spiel ist komplett mit
Roblox' eingebauten `rbxasset://`-Sounds vertont, damit es überall sofort läuft,
ohne dass du etwas hochladen musst. Ich habe bewusst **keine Asset-IDs
geraten** — eine erfundene ID lädt entweder nicht oder spielt irgendwas
Fremdes ab, und das merkst du erst im Livebetrieb. Drei eigene Ambient-Loops in
`src/shared/Config/Audio.luau` eintragen ist der größte einzelne Sprung, den du
beim Spielgefühl machen kannst.

**"Ich finde den Season Core nicht"** — der existiert nur im Live-Fenster
(Samstag und Sonntag UTC) und ist aus allen normalen Drop-Tabellen
ausgeschlossen. Außerhalb des Fensters kann er mit keinem Luck-Wert fallen. Der
HUD-Chip oben rechts zeigt, wann das nächste Fenster öffnet.

---

Design-Begründungen: [`GAME_DESIGN.md`](GAME_DESIGN.md) ·
Launch und Monetarisierung: [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md)
