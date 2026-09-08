# DEEP RUSH — Launch-Playbook

Das Spiel ist der einfachere Teil. Das hier ist der schwierigere.

**Ehrlich vorweg:** Die überwältigende Mehrheit aller Roblox-Spiele findet nie
Spieler. Nicht wegen der Qualität, sondern weil Entdeckung ein Wettbewerb um
Klickrate und Verweildauer gegen Titel mit Millionenbudget ist. Was unten
steht, verbessert deine Chancen erheblich — es garantiert nichts. Plane in
Iterationen, nicht in einem großen Launch.

---

## 1. Wie Roblox entscheidet, wer dich sieht

Die Empfehlungsleiste bewertet im Kern vier Signale. Alle vier sind
beeinflussbar:

| Signal | Was es misst | Dein Hebel |
|---|---|---|
| **CTR** | Klicks pro Impression | Thumbnail und Titel — mit Abstand am wichtigsten |
| **D1-Retention** | kommt jemand morgen wieder | Onboarding + Daily Quests |
| **Session-Länge** | wie lange am Stück | Rift-Countdown, Streak-Bonus |
| **Playtime gesamt** | Summe über alle | Meta-Loop, Rebirth |

Der entscheidende Punkt: **CTR entscheidet, ob du überhaupt getestet wirst;
Retention entscheidet, ob der Test wiederholt wird.** Ein grandioses Spiel mit
schlechtem Thumbnail wird nie gemessen.

---

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
CTR-Unterschiede zwischen zwei Bildern desselben Spiels liegen regelmäßig beim
Faktor zwei bis drei. Das ist der größte einzelne Hebel, den du hast.

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
| täglich | Daily Quests (automatisch) | 0 |
| alle 12 Min | Rift Surge (automatisch) | 0 |
| wöchentlich | ein neues Erz oder eine Drohne | ~30 Min |
| zweiwöchentlich | Doppel-Luck-Wochenende | 1 Zeile in `Game.luau` |
| monatlich | neue Schicht oder Mechanik | 1 Tag |

Die ersten beiden Zeilen laufen ohne dich. Das ist Absicht: Live-Ops, die
tägliche Handarbeit brauchen, werden nach drei Wochen eingestellt.

---

## 6. Welche Zahlen wirklich zählen

Nach Priorität:

1. **D1-Retention** — alles andere ist ohne sie egal.
2. **CTR** — deine einzige Kontrolle über die Verteilungsmenge.
3. **Median-Session** — Ziel > 8 Minuten. Darunter greift der Meta-Loop nicht.
4. **Anteil, der Rebirth 1 erreicht** — misst, ob der Mittelteil trägt.
5. **Umsatz pro Spieler** — zuletzt. Monetarisierung ohne Bindung ist eine
   Zahl, die man nicht vergrößern kann.

---

## 7. Moderation und Regeln

Bevor du öffentlich gehst, drei Dinge prüfen:

- **Alterskennzeichnung** korrekt setzen (dieses Spiel: keine unpassenden
  Inhalte, aber Spieler-gegen-Spieler-Diebstahl ehrlich angeben).
- **Kein Verhalten, das Roblox als betrügerisch wertet** — dazu gehören
  irreführende Thumbnails, die Inhalte zeigen, die es im Spiel nicht gibt. Das
  ist zusätzlich der schnellste Weg zu vernichtender Retention.
- **Keine externen Belohnungen** für Likes/Favoriten. Das ist ein Verstoß gegen
  die Community-Standards und kostet im Ernstfall das Erlebnis.
