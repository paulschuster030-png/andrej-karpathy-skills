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

## Was du im Spiel siehst

| | |
|---|---|
| **Das Erz steckt sichtbar im Fels** | Gold als Metallader, Diamant als Glaskristall, Nullstone frisst Licht. Ab *Rare* steht der Name darüber, ab *Epic* schießt eine Lichtsäule den Schacht hoch. Du entscheidest, wohin du läufst — vorher waren alle Steine graue Würfel. |
| **Die Spitzhacke in der Hand** | 5 Stufen, gebunden ans Pickaxe-Upgrade. Jede Stufe macht dich schneller *und* sieht anders aus, für dich und für alle anderen. |
| **Ranglistensystem** | 10 Ränge auf Lebenszeit-Einzahlungen — die einzige Zahl, die nie fällt. Über dem Kopf, im HUD, in der Spielerliste. Dazu zwei Boards an der Oberfläche: global für immer, und **dieser Server heute**. |
| **Glück ist ein Ereignis** | Der Stein ist eine Untergrenze. Glück würfelt ein zweites Mal und behält das Bessere — mit Blitz, Schockwelle und „⚡ LUCK BEAT THE VEIN". |
| **Future-Licht** | Echte Schatten von jedem Punktlicht, Bloom nur auf dem, was wirklich leuchtet, Tiefenschärfe, die den Schacht tief statt hoch aussehen lässt. |
| **Der Schacht ist beleuchtet** | Sechs Lampen pro Abschnitt an der Wand, tiefer brennen sie heller. Dazu doppelt so viel Grundlicht wie vorher — der Abstieg wird dunkler, aber nie unspielbar. |
| **Abbauen ist eine Animation** | Bis zu vier Hiebe pro Stein, jeder mit Ausholen, Schlag und Rückfederung. Der Stein federt zurück, die Erzader geht mit, Splitter fliegen — und jeder Hieb klingt. |
| **Alles in einer Tonart** | Die vier Ambience-Schichten überblenden ineinander; jetzt stehen sie alle auf D-Moll-Pentatonik statt auf zufälligen Frequenzen. Kein Reiben mehr. |

Warum genau diese Dinge: [`TRENDS.md`](TRENDS.md), dritte Runde.

---

## In 3 Minuten spielbar

1. **Roblox Studio öffnen** → `File ▸ Open from File…`
2. **`build/DeepRush.rbxlx`** auswählen (die Datei liegt fertig im Repo)
3. **Play (F5)** drücken — das ist der Schritt, der zählt

> **Im Bearbeitungsmodus siehst du nur eine graue Platte mit einem
> Spawn-Punkt, und das ist richtig so.** Der ganze Schacht — Oberfläche,
> Tresor, Schienen, Erz, Lifte, Gefahren — wird beim Serverstart erzeugt.
> Vor **Play** existiert nichts davon, weil es noch niemand gebaut hat.
> Die Platte verschwindet in der Sekunde, in der die echte Oberfläche steht.

### Hochladen

1. `File ▸ Publish to Roblox As…` → neuen Platz anlegen
2. Im Creator-Dashboard: **Game Settings ▸ Security ▸ Enable Studio Access to
   API Services = AN** (sonst speichert nichts — siehe Troubleshooting)
3. Platz auf **Public** stellen

> **Zum Testen musst du nichts umstellen.** Ohne DataStore-Zugriff (also
> bevor der Platz veröffentlicht ist) läuft das Spiel automatisch im
> Speicher: alles spielbar, nichts wird gespeichert, und der Server sagt es
> einmal im Output. Sobald **Game Settings ▸ Security ▸ Enable Studio Access
> to API Services** an ist, wird auch im Studio gespeichert.

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
    Ores.luau        8 Seltenheitsstufen, 32 Erze, Tiefen-Gating,
                     und wie jedes davon im Fels aussieht
    Layers.luau      9 Schichten von Topsoil bis Singularity
    Mutations.luau   die Multiplikatoren, die Screenshots erzeugen
    Upgrades.luau    7 Upgrade-Linien mit Kostenkurven
    Quests.luau      Onboarding-Kette, Daily-Pool, Meilensteine
    Contracts.luau   Wochen-Leiter und 28-Tage-Log (Langzeitbindung)
    Season.luau      das Wochenend-Fenster mit dem exklusiven Badge
    Hazards.luau     die sichtbaren Gefahrenzonen
    Audio.luau       alle Sounds — hier deine eigenen Asset-IDs eintragen
    Tools.luau       die 5 Spitzhacken-Stufen (folgen dem Pickaxe-Upgrade)
    Ranks.luau       die 10 Rangstufen auf Lebenszeit-Einzahlungen
    Crew.luau        Co-Play: Bonus, Pings, Rettung
    Cosmetics.luau   Lampen, Trails, Titel — die Status-Ebene
    Rebirth.luau     Prestige-Anforderungen und Boni
    Drones.luau      die Sammel-Ebene
    Products.luau    Gamepasses, Dev-Products, Daily Deals (IDs eintragen!)
  Net.luau           jedes Remote an einem Ort, mit Rate-Limit
  Rarity.luau        Knoten-Roll ohne Glück, Glück als zweiter Wurf,
                     exakte Gesamtquote für die Anzeige
  Format.luau        Zahlenformatierung (12.4K statt 12400)
  Signal.luau        minimaler Observer

src/server/          ServerScriptService/Server — autoritativ
  Bootstrap.server.luau   Startreihenfolge = Abhängigkeitsreihenfolge
  Data.luau          Profile, DataStore mit Session-Lock, Autosave
  Economy.luau       eine Quelle der Wahrheit für Luck/Cash/Kapazität
  World.luau         gechunkter 3.000-m-Schacht, sichtbare Erz-Nodes, Kisten
  Mining.luau        der Schwung, der Roll, der Zahlen-Pop
  Cargo.luau         ungebunkerte Beute + Gier-Messung
  Tools.luau         die Spitzhacke in der Hand, animiert per Motor6D
  Surface.luau       Lift nach oben, Bank an der Oberfläche, Notaufstieg
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
  Upgrades / Rebirth / Drones / Rewards
  Leaderboards.luau  Rang, globale Boards und das Live-Board des Servers
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
  Atmosphere.luau    Future-Licht, Bloom, Tiefenschärfe, Ton nach Tiefe
  Intro.luau         die Regelkarte beim ersten Start
  Effects.luau       Shake, Partikel, schwebende Zahlen
  Ui.luau            das kleinstmögliche UI-Kit

tools/
  build-rbxlx.mjs    Quellbaum → Place-Datei
  balance-check.py   fährt die Ökonomie außerhalb von Roblox
  balance-spec.luau  60 Design-Zusagen als Assertions
  protocol-check.py  prüft, ob Client und Server dieselben Remotes benutzen
  sim-check.py       startet den echten Server headless
  sim-spec.luau      44 Laufzeit-Checks: Mining, Bank, Lift, Werkzeug, Rang,
                     Gefahren, Crew, Notaufstieg, Rückweg vom Grund
  robloxstub.luau    genug Roblox-API, um den Server ohne Roblox laufen zu lassen
  make-audio.py      erzeugt die Sounds in audio/
  audio-check.py     misst, ob die Loops wirklich nahtlos sind
  api-check.py       prüft jede Eigenschaft gegen Roblox' echten API-Dump
  api-dump.json      Roblox' API-Beschreibung, auf das Nötige eingedampft

audio/
  *.ogg              9 fertige Sounds zum Hochladen (siehe audio/README.md)

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
# Syntax/Compile aller 58 Luau-Dateien (braucht die Luau-CLI)
find src -name '*.luau' -exec luau-compile --null -O2 {} \;

# Die Ökonomie tatsächlich ausrechnen, nicht schätzen
python3 tools/balance-check.py /pfad/zu/luau

# Benutzen Client und Server dieselben Remotes?
python3 tools/protocol-check.py

# Den echten Server headless starten und durchspielen
python3 tools/sim-check.py /pfad/zu/luau

# Sind die Audio-Loops nahtlos?
python3 tools/audio-check.py

# Existiert jede Eigenschaft, die der Code setzt, in echtem Roblox?
python3 tools/api-check.py
```

**`api-check.py` schließt die Lücke, die alle anderen hatten.** Der Simulator
stubbt Roblox — und ein Stub ist eine Lua-Tabelle, die *jede* Eigenschaft
annimmt. Echtes Roblox nicht: Eine Eigenschaft, die es nicht gibt oder die die
Engine für sich reserviert, wirft zur Laufzeit. Weil jeder `start()` in einem
`pcall` steckt, wurde daraus ein `warn()`, das niemand sieht. Der Check liest
Roblox' eigenen API-Dump und prüft jede Zuweisung, jedes `Instance.new` und
jedes `Enum.X.Y` dagegen.

**`sim-check.py` ist der wichtigste davon.** Er stubbt die Roblox-API so weit,
dass die echten Server-Module wirklich laufen: ein Spieler tritt bei, stellt
sich an einen Stein, feuert `Mine`, und der Test prüft die Fracht. Der Lift
wird tatsächlich benutzt und die Landeposition gemessen. Zeit ist virtuell,
also dauert ein Node-Respawn von 9 Sekunden Millisekunden.

Grenzen, damit niemand mehr hineinliest als drin ist: CFrame trägt nur
Position, keine Rotation; es gibt keine Physik; Kollisionen werden geprüft,
nicht simuliert.

`balance-spec.luau` prüft Zusagen, keine Implementierungsdetails — z. B.
"tiefer graben lohnt sich immer", "Luck erhöht seltene Quoten streng monoton",
"das erste Rebirth dauert 15–90 Minuten", "Co-Play steht nie auf dem
Onboarding-Pfad".

Die Prüfungen haben bisher vierzehn echte Fehler gefunden, die sonst live gegangen
wären:

- `Format.short` hat runde Zahlen um den Faktor 10 verkleinert
  (`250000` → `"25K"`) — das betraf jede runde Zahl im HUD.
- Rebirth war für 25.000 Cash zu haben, während die Upgrade-Leiter bis 77M reicht.
- Contract-Punkte pro Cash-Betrag hätten einem Spätspiel-Spieler die
  Tagesgrenze mit **einer** Einzahlung gefüllt.
- **Heruntergefallene Frachtkisten konnten gar nicht aufgehoben werden**: der
  Server akzeptierte `GrabCrate`, aber kein Knopf im Client hat es je gesendet.
- **Am Grund des Schachts saß man fest.** Die nächste Liftplattform lag 31 Studs
  *unter* dem Boden, die übernächsten 172 und 536 Studs darüber — bei einer
  Sprunghöhe von 7. Jetzt gibt es einen Lift pro Chunk, einen fest am Grund und
  zusätzlich den Notaufstieg.
- **Roblox hätte zwei Drittel der Welt gelöscht.** `FallenPartsDestroyHeight`
  steht standardmäßig auf -500, der Schacht reicht bis -9.000: alles darunter —
  Spieler und Frachtkisten eingeschlossen — wäre bei Ankunft verschwunden.
- **Die Tiefe kam vom Client.** Wer aufhörte sie zu melden, ist nie erstickt; wer
  3000 meldete, bekam Tiefen-Meilensteine und das Rebirth-Tor geschenkt. Der
  Server misst sie jetzt selbst.
- **Einzahlen konnte stumm bleiben.** Der Leaderboard-Schreibvorgang lag zwischen
  Auszahlung und Rückmeldung; ein Fehler dort hat bezahlt, aber nichts angezeigt.
- **Man spawnte im Nichts.** Die Welt entsteht zur Laufzeit, der Spieler aber
  sofort — in Studio treten beide im selben Moment an. Ohne Boden fiel man
  10 Sekunden lang (siehe Punkt davor: der Löschboden liegt jetzt bei -9.400).
  Jetzt liegt eine Platte mit Spawn in der Place-Datei, und der Bootstrap hält
  `CharacterAutoLoads` zurück, bis die Welt steht.
- **Die Spitzhacke ließ tote Motoren zurück.** `equip` löschte die alte Hacke,
  aber nicht ihren `Motor6D`. Seit die Hacke bei jedem Drill-Level neu gebaut
  wird, wären das bis zu 50 tote Motoren an einer Hand.
- **`Lighting.Technology` darf kein Skript setzen.** Roblox reserviert die
  Eigenschaft für sich (`RobloxScriptSecurity`) — die Zuweisung wirft, und
  damit starb die gesamte Atmosphäre-Steuerung: kein Licht, kein Nebel, kein
  Ton nach Tiefe. Kompilierte sauber, lief im Simulator sauber, konnte in
  einem echten Platz nie funktionieren. `Future` steht jetzt in der
  Place-Datei, wo es erlaubt ist.
- **Zwei Enum-Werte gab es nicht.** `Enum.AdFormat.Rewarded` heißt
  `RewardedVideo`, `Enum.ShowAdResult.Succeeded` heißt `ShowCompleted`.
- **`FallenPartsDestroyHeight` darf auch kein Skript setzen** — nur ein Plugin.
  Die Zuweisung warf `lacking capability Plugin` und riss den kompletten
  Weltgenerator mit. Steht jetzt in der Place-Datei.
- **Ein `GetDataStore()` auf Modulebene hat 23 Dienste getötet.** In Studio
  wirft der Aufruf, solange der Platz nicht veröffentlicht ist. Weil er beim
  Laden von `Data` lief, schlug nicht eine Speicherung fehl, sondern das
  ganze Modul — und mit ihm alles, was `Data` braucht. Jetzt fällt es sauber
  auf Speicher-Betrieb zurück.

---

## Bevor du live gehst

| Schritt | Wo |
|---|---|
| Gamepass-, Product- und Daily-Deal-IDs eintragen | `src/shared/Config/Products.luau` |
| **Die 9 Sounds hochladen und IDs eintragen** | `audio/` → `src/shared/Config/Audio.luau` |
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

**"Der Sound ist okay, aber nicht toll"** — bis du hochlädst, ja. Ohne
eingetragene IDs läuft alles auf Roblox' eingebauten `rbxasset://`-Sounds,
damit das Spiel überall sofort funktioniert. Die **fertigen Dateien liegen in
[`audio/`](audio/)**: vier Ambient-Loops, drei positionale Loops für
Gefahrenzonen und Lifte, zwei One-Shots. Hochladen, IDs in
`src/shared/Config/Audio.luau` eintragen, fertig — Anleitung in
[`audio/README.md`](audio/README.md). Das ist der größte einzelne Sprung beim
Spielgefühl.

**"Ich finde den Season Core nicht"** — der existiert nur im Live-Fenster
(Samstag und Sonntag UTC) und ist aus allen normalen Drop-Tabellen
ausgeschlossen. Außerhalb des Fensters kann er mit keinem Luck-Wert fallen. Der
HUD-Chip oben rechts zeigt, wann das nächste Fenster öffnet.

---

Design-Begründungen: [`GAME_DESIGN.md`](GAME_DESIGN.md) ·
Launch und Monetarisierung: [`LAUNCH_PLAYBOOK.md`](LAUNCH_PLAYBOOK.md)
