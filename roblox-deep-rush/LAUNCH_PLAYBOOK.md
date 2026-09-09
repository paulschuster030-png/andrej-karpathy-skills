# DEEP RUSH — Launch-Playbook

Das Spiel ist der einfachere Teil. Das hier ist der schwierigere.

**Ehrlich vorweg:** Die überwältigende Mehrheit aller Roblox-Spiele findet nie
Spieler. Nicht wegen der Qualität, sondern weil Entdeckung ein Wettbewerb um
Klickrate und Verweildauer gegen Titel mit Millionenbudget ist. Was unten
steht, verbessert deine Chancen erheblich — es garantiert nichts. Plane in
Iterationen, nicht in einem großen Launch.

---

## 1. Wie Roblox entscheidet, wer dich sieht

> **Korrektur gegenüber der ersten Fassung dieses Dokuments.** Hier stand
> vorher, der Algorithmus bewerte CTR, D1-Retention, Session-Länge und
> Gesamt-Playtime. Das galt 2024/25. Roblox hat den Empfehlungsalgorithmus
> 2026 umgebaut und die tatsächlichen Signale veröffentlicht — die Liste unten
> ist die offizielle. Herleitung und Quellen: [`TRENDS.md`](TRENDS.md).

Der „Recommended For You"-Algorithmus nutzt **sechs** Signale:

| # | Signal | Dein Hebel |
|---|---|---|
| 1 | **qPTR** — engagierte Plays pro Impression | Thumbnail und Icon (siehe `cover/`) |
| 2 | **7-Tage-Playtime pro Nutzer**, gedeckelt bei 60 Min/Tag | Core Loop, Rift-Countdown |
| 3 | **7-Tage-Spieltage pro Nutzer** | Dailies, Login-Streak, Descent Log |
| 4 | **7-Tage-Ausgabetage pro Nutzer** | Daily Deal (billig, täglich neu) |
| 5 | **7-Tage-Robux pro Nutzer** | Pässe, Dev-Products |
| 6 | **7-Tage-Co-Play-Tage pro Nutzer** | Crew-System, Einladen-Knopf, private Server |

Roblox sagt dazu: *„There is no one signal that is most important. All of
these signals work together."* Es gibt also keinen Trick, nur mehrere Hebel.

**Drei Dinge daran ändern die Strategie grundlegend:**

**Der 60-Minuten-Deckel.** Playtime über eine Stunde pro Tag und Spieler zählt
für die Empfehlung schlicht nicht mehr. Ein Design, das auf Marathon-Sessions
zielt, verschenkt seinen Aufwand. Deshalb hat der Weekly Contract einen
Tagesdeckel bei etwa 26 Minuten Spielzeit und sagt dir danach ausdrücklich,
dass du für heute fertig bist.

**Spieltage schlagen Spielstunden.** Zweimal 20 Minuten an zwei Tagen ist mehr
wert als 40 Minuten an einem. Der gesamte Descent Log existiert nur dafür.

**Co-Play ist ein eigenes Signal.** Ein Spiel ohne Grund, jemanden mitzubringen,
bekommt hier eine Null — egal wie gut es sonst ist.

Und: Das Bewertungsfenster geht inzwischen über **28 Tage**, mit getrennten
Phasen für Tag 1, Tag 2–7 und Tag 8–28. Roblox' erklärtes Ziel ist, Spiele zu
verdrängen, die „mit aufregenden Thumbnails Aufmerksamkeit gewinnen, aber
keinen langfristigen Wert liefern". Ein starkes Thumbnail bringt dich also in
den Test — durchfallen kannst du trotzdem noch drei Wochen später.

## 2. Titel und Thumbnail

### Titel

Roblox-Suche ist buchstäblich Stringmatching. Der Titel ist ein Keyword-Feld,
kein Kunstwerk.

```
⛏️ Deep Rush — Dig, Bank & Steal!
```

- Emoji vorne: hebt die Zeile im Raster hervor.
- Der Eigenname zuerst, damit Wiedererkennung entstehen kann.
- Danach die drei Verben, nach denen tatsächlich gesucht wird.
- Bei Updates ein Präfix ergänzen (`[RIFT UPDATE]`) — Roblox-Spieler klicken
  nachweislich stärker auf sichtbar aktive Spiele. Der Eigenname bleibt.

### Thumbnail

Die eine Grafik, die über alles entscheidet. Regeln, die aus fast jedem
erfolgreichen Roblox-Thumbnail ablesbar sind:

1. **Ein Fokus.** Eine Figur, ein Objekt, eine Zahl. Keine Collage.
2. **Gesicht mit Emotion**, groß, in der linken Bildhälfte.
3. **Eine riesige Zahl oder ein Zustandswort** — hier: `2.000m` oder `1 in 540K`.
4. **Hoher Kontrast**, gesättigte Farben, klarer Rand — es wird auf einem
   6-cm-Display in einer Reihe von zwölf Kacheln betrachtet.
5. **Maximal drei Wörter Text.** Alles darüber ist bei dieser Größe unlesbar.

Konkret für dieses Spiel: Spielerfigur am oberen Bildrand, unter ihr der
schwarze Schacht mit leuchtendem Erz, rechts groß `1.400m`, links das erschrockene
Gesicht. Der Schacht liefert die Tiefenwirkung gratis.

**Teste mindestens drei Varianten.** Roblox erlaubt mehrere Thumbnails; die
Unterschiede zwischen zwei Bildern desselben Spiels liegen regelmäßig beim
Faktor zwei bis drei. Das ist der größte einzelne Hebel, den du hast.

Drei fertige Varianten liegen in [`cover/out/`](cover/) — je eine für den
Risiko-Hook, den Seltenheits-Hook und den Diebstahl-Hook. Sie ziehen
unterschiedliche Spielertypen an, und nur deine qPTR-Zahlen können dir sagen,
welcher deiner ist. Lade alle drei hoch und lass sie eine Woche laufen.

### Beschreibung

Erste Zeile ist die einzige, die viele lesen:

```
Grab dich tiefer, als du zurückkommst. Jeder Meter multipliziert deine Beute —
und macht dich zum Ziel. 30 Erze, 9 Schichten, 1 zu 540.000.

⛏️ 8 Seltenheitsstufen mit Mutationen bis ×15
⚡ RIFT SURGE alle 12 Minuten — 5× Luck für alle
🫳 Beklau gierige Miner. Oder werde beklaut.
🔥 Rebirth für dauerhafte Multiplikatoren

Tags: mining, tycoon, simulator, dig, steal, rng, incremental
```

---

## 3. Monetarisierung einrichten

Das Spiel läuft ohne diesen Schritt vollständig — nichts hier ist Pflicht.

**Gamepasses anlegen:** Creator-Dashboard ▸ dein Erlebnis ▸ *Associated Items*
▸ *Passes* ▸ *Create a Pass*. ID kopieren und in
`src/shared/Config/Products.luau` bei `assetId` eintragen.

| Pass | Vorschlag | Warum dieser Preis |
|---|---|---|
| 2x Cash | 199 R$ | klassischer Einstiegskauf |
| 2x Luck | 249 R$ | für Spieler, die den Codex jagen |
| +25 Cargo | 149 R$ | spürbar ab der ersten Minute |
| Auto Drill | 299 R$ | verkauft Komfort, nicht Macht |
| Express Lift | 99 R$ | verkauft 4 Sekunden — bewusst billig |
| VIP Miner | 499 R$ | Bündel + sichtbares Tag |

**Dev-Products:** dieselbe Seite ▸ *Developer Products*. Cash-Pakete skalieren
im Code automatisch mit dem bisherigen Fortschritt des Spielers, damit ein Kauf
in Stunde 1 und in Stunde 100 ungefähr gleich viele Runs wert ist.

**Daily Deals (wichtiger als sie aussehen).** Sechs kleine Produkte zu 25–49 R$
in `Products.DailyDeals`, von denen täglich eines im Shop steht. Der Grund ist
kein Preis-Trick, sondern ein Ranking-Signal: Roblox zählt **Ausgabetage**
getrennt von der Ausgabenhöhe. Fünf kleine Käufe an fünf Tagen sind für die
Empfehlung mehr wert als ein großer an einem — und für den Geldbeutel eines
13-Jährigen ohnehin freundlicher. Lege alle sechs an, sonst rotiert der Shop
ins Leere.

**Rewarded Video** (`Products.RewardedVideo.devProductId`): erst möglich mit
2FA, ID-verifiziertem Konto ab 13, öffentlichem Erlebnis und **2.000
eindeutigen Besuchern pro Monat**. Bis dahin bleibt der Knopf unsichtbar, das
ist so gebaut. Danach bringt es bei guter Platzierung 8–15 % des Umsatzes.
Belohnung darf niemals Robux sein — unsere ist ein Luck-Boost mit einer Stunde
Abklingzeit.

**Danach unbedingt testen:** Kauf im veröffentlichten Platz durchführen (nicht
im Studio) und prüfen, dass die Belohnung genau einmal ankommt. Der
Receipt-Handler ist idempotent gebaut, aber ein falsch eingetragener
`assetId` fällt nur so auf.

---

## 4. Die ersten 30 Tage

**Woche 1 — messen, nicht bewerben.**
Veröffentlichen, drei Thumbnails testen, Analytics beobachten. Du suchst genau
eine Zahl: **D1-Retention**. Unter 10 % stimmt etwas mit den ersten drei
Minuten nicht — dann repariere das Onboarding, bevor du irgendwo Werbung machst.
Traffic auf ein undichtes Spiel zu leiten, verbrennt ihn.

**Woche 2 — die erste Reibung glätten.**
Sieh dir an, wo Spieler aufhören. Typische Kandidaten in diesem Genre: Fracht
zu früh voll, Lift zu weit weg, erstes Rebirth zu weit entfernt. Alles davon
ist in `src/shared/Config/Game.luau` eine Zeile.

**Woche 3 — erstes Update mit sichtbarem Titel-Präfix.**
Ein neues Erz, eine neue Drohne, ein neuer Daily. Klein ist in Ordnung; die
Botschaft "hier passiert etwas" ist der eigentliche Inhalt.

**Woche 4 — jetzt erst Reichweite.**
Kurzclips vom Rift-Moment und von Snatches. Vertikal, unter 20 Sekunden, die
Reveal-Karte in der ersten Sekunde. Der teilbare Moment ist bereits ins Spiel
gebaut — er ist der Grund, warum die Karte die echte Quote druckt.

---

## 5. Live-Ops-Kalender

Ein Spiel ohne Puls stirbt, auch wenn es gut ist.

| Rhythmus | Maßnahme | Aufwand |
|---|---|---|
| alle 12 Min | Rift Surge | 0 — automatisch |
| täglich | Daily Quests + Daily Deal | 0 — automatisch |
| montags | Weekly Contract rotiert | 0 — automatisch |
| laufend | Descent Log (Tag 2 bis 28) | 0 — automatisch |
| wöchentlich | ein neues Erz oder eine Drohne | ~30 Min |
| zweiwöchentlich | Doppel-Luck-Wochenende | 1 Zeile in `Game.luau` |
| monatlich | neue Schicht oder Kosmetik-Set | 1 Tag |

Die ersten vier Zeilen laufen ohne dich. Das ist Absicht: Live-Ops, die
tägliche Handarbeit brauchen, werden nach drei Wochen eingestellt — und dann
fällt genau das Signal weg, das dich in die Empfehlungen bringt.

---

## 6. Welche Zahlen wirklich zählen

Roblox liefert dir die Signale inzwischen selbst: **Creator-Dashboard ▸
Analytics ▸ Home Recommendations.** Dort stehen deine Werte für genau die
sechs Signale aus Abschnitt 1, plus Vergleichs-Benchmarks. Diese Seite ist
deine wichtigste, nicht die CCU-Anzeige.

Nach Priorität:

1. **qPTR** — deine einzige Kontrolle über die Verteilungsmenge. Teste
   Thumbnails, bis diese Zahl sich bewegt.
2. **Spieltage pro Nutzer** — die Zahl, die das 28-Tage-Fenster entscheidet.
   Wenn sie bei 1,x klebt, ist der Descent Log unsichtbar oder zu langsam.
3. **Co-Play-Tage** — wenn hier nichts passiert, findet niemand das
   Crew-System. Dann gehört der Beacon-Knopf prominenter ins HUD, nicht ein
   weiteres Feature daneben.
4. **D1-Retention** — bleibt der schnellste Frühindikator für kaputtes
   Onboarding.
5. **Ausgabetage** — misst, ob der Daily Deal seinen Job macht. Ein guter Wert
   ist hier mehr wert als ein teurerer Pass.

## 7. Moderation und Regeln

Bevor du öffentlich gehst, drei Dinge prüfen:

- **Alterskennzeichnung** korrekt setzen (dieses Spiel: keine unpassenden
  Inhalte, aber Spieler-gegen-Spieler-Diebstahl ehrlich angeben).
- **Kein Verhalten, das Roblox als betrügerisch wertet** — dazu gehören
  irreführende Thumbnails, die Inhalte zeigen, die es im Spiel nicht gibt. Das
  ist zusätzlich der schnellste Weg zu vernichtender Retention.
- **Keine externen Belohnungen** für Likes/Favoriten. Das ist ein Verstoß gegen
  die Community-Standards und kostet im Ernstfall das Erlebnis.
