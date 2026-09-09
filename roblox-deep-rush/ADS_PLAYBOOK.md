# Werbung schalten: was es kostet und wann es sich lohnt

Ja, du kannst auf Roblox Werbung für dein Spiel kaufen. Alles läuft über den
**Ads Manager** im Creator-Dashboard, und die Einstiegshürde ist niedriger als
die meisten denken: **10 Ad Credits ≈ 2.850 Robux ≈ 35 US-Dollar** Mindestkauf,
und ab **1 Dollar Tagesbudget**.

Bevor der Rest: **Werbung verstärkt, sie repariert nicht.** Traffic auf ein
Spiel zu leiten, das Spieler nach zwei Minuten verlieren, verbrennt das Geld
zweimal — einmal an der Kasse und einmal in den Empfehlungssignalen, weil
Roblox jetzt misst, dass viele Leute reinkommen und keiner wiederkommt. Die
Einstiegsschwelle steht unten in Abschnitt 6, und sie ist ernst gemeint.

---

## 1. Die vier Formate

| Format | Was es ist | Abrechnung |
|---|---|---|
| **Sponsored Experiences** | dein Spiel erscheint als gesponsertes Ergebnis in Suche und Discover | pro Klick / pro Besuch |
| **Search Ads** | oben in den Suchergebnissen für bestimmte Keywords | pro Klick |
| **Immersive Ads** | 3D-Billboards in *anderen* Spielen | CPM (pro 1.000 Impressions) |
| **Portal Ads** | begehbare Portale in anderen Spielen, die direkt zu dir teleportieren | CPM |

Für ein neues Spiel ist **Sponsored Experiences** das richtige Format. Die
anderen brauchen entweder Markenbekanntheit (Search Ads funktionieren nur,
wenn jemand nach etwas sucht, das zu dir passt) oder größere Budgets.

---

## 2. Was es realistisch kostet

Stand September 2026, aus mehreren Quellen zusammengetragen:

| Kennzahl | Spanne |
|---|---|
| Sponsored Experiences, pro Besuch | **0,01–0,05 $** |
| Sponsored Experiences, pro Klick | 0,10–0,50 $ |
| Immersive Ads, CPM | 1–5 $ |
| Effektive Kosten pro *engagiertem* Spieler | 0,20–1,00 $ |

Daraus abgeleitet, was ein Budget ungefähr bringt:

| Budget | Erwartete neue Besuche |
|---|---|
| 100 $ | 2.000–10.000 |
| 500–2.000 $ | 10.000–40.000 |

Die Spanne ist so breit, weil sie fast vollständig von **einer** Sache
abhängt: wie oft dein Icon angeklickt wird, wenn es jemandem gezeigt wird. Das
ist derselbe Hebel wie bei der organischen Reichweite, und es ist der Grund,
warum das Cover in `cover/` vor dem ersten Werbe-Dollar kommt.

**Abrechnungsmodell:** Zweitpreis-Auktion. Bei Awareness-Kampagnen bietest du
einen maximalen CPM, bei Visits-Kampagnen einen maximalen Preis pro Play (CPP).
Fang mit automatischem Bieten an — manuell zu bieten, bevor du deine eigenen
Zahlen kennst, ist Raten mit Extraschritten.

---

## 3. Einrichten, konkret

1. **Creator Dashboard ▸ Advertising ▸ Ads Manager**
2. **Ad Credits kaufen.** Mindestens 10 Credits (≈ 35 $). Credits sind die
   Währung des Ads Managers, nicht Robux direkt.
3. **Kampagne anlegen**, Ziel = *Visits* (nicht Awareness — du willst Spieler,
   keine Sichtkontakte).
4. **Tagesbudget setzen.** Für den ersten Test: **10–20 $ pro Tag, 3–5 Tage.**
   Weniger liefert keine belastbaren Daten, mehr verbrennt Geld, bevor du
   weißt, ob das Creative trägt.
5. **Targeting:** Alter, Geschlecht, Gerät. Für DEEP RUSH: alle Geräte
   (das HUD ist mobil gebaut), Alter breit lassen. Zu enges Targeting am Anfang
   ist der häufigste Anfängerfehler — du nimmst dem Algorithmus die Chance,
   deine Zielgruppe selbst zu finden.
6. **Automatisches Bieten**, laufen lassen, nicht täglich daran drehen.

---

## 4. Was du testest — und in welcher Reihenfolge

Das Wichtigste zuerst, weil es alles andere multipliziert:

**Runde 1 — das Icon.** Nicht das Spiel, nicht das Targeting: das Icon. Lass
zwei Kampagnen mit identischen Einstellungen und unterschiedlichen Icons
laufen. Unterschiede um den Faktor zwei bis drei sind normal. Ein Icon, das
doppelt so oft geklickt wird, halbiert deine Kosten pro Spieler — das ist mehr,
als du je durch Gebotsoptimierung herausholst.

**Runde 2 — die drei Thumbnails.** Sie sind in `cover/out/` fertig und
verkaufen drei verschiedene Spiele: den Risiko-Loop, die Seltenheitsjagd, den
Diebstahl. Welcher zieht, sagen dir nur deine Zahlen.

**Runde 3 — Budget hochfahren.** Erst wenn du weißt, was die beste Kombination
kostet, skalierst du. Vorher ist Skalieren nur schnelleres Verlieren.

---

## 5. Der erste 100-Dollar-Plan

Ein vollständiger Test, mit dem du am Ende echte Zahlen hast:

| Tag | Ausgabe | Was läuft |
|---|---|---|
| 1–2 | 2 × 15 $ | Icon A vs. Icon B, sonst identisch |
| 3 | — | auswerten: Kosten pro Play je Variante |
| 4–6 | 3 × 20 $ | Gewinner-Icon, drei Thumbnails im Wechsel |
| 7 | — | auswerten: welche Kombination ist am billigsten pro Spieler |

Was du danach weißt: deine echten Kosten pro Spieler, dein bestes Creative und
ob sich Skalieren überhaupt rechnet. Das ist 100 Dollar wert, auch wenn die
Antwort "noch nicht" lautet.

**Die Rechnung, die zählt:** Kosten pro Spieler geteilt durch das, was ein
Spieler dir im Schnitt einbringt. Wenn du 0,30 $ pro Spieler zahlst und im
Schnitt 0,05 $ pro Spieler verdienst, ist die Kampagne kein Wachstum, sondern
ein Zuschuss. Das ist völlig in Ordnung, solange du es *weißt* und es bewusst
als Reichweiten-Investition machst — nicht, wenn du denkst, es trägt sich.

---

## 6. Die Schwelle: wann du NICHT werben solltest

Nicht einen Cent ausgeben, solange eine dieser Aussagen stimmt:

- **D1-Retention unter 10 %.** Dann verlierst du neun von zehn gekauften
  Spielern sofort — und der Empfehlungsalgorithmus sieht genau das.
- **Median-Session unter 5 Minuten.** Das Spiel hält nicht, was das Thumbnail
  verspricht.
- **Keine Produkte eingerichtet.** Du kannst nicht messen, ob sich ein Spieler
  rechnet, wenn er nichts kaufen kann.
- **Du hast dein Icon noch nie getestet.** Das ist der billigste Test überhaupt
  und du machst ihn mit organischem Traffic umsonst.

Die Reihenfolge ist immer: **erst halten, dann kaufen.** Roblox' eigener
Algorithmus verschenkt Reichweite an Spiele mit guter Bindung — Werbung ist
dazu da, diesen Motor anzuwerfen, nicht ihn zu ersetzen.

---

## 7. Die kostenlosen Kanäle, die oft besser ziehen

Bevor du Geld ausgibst, hast du drei Hebel, die nichts kosten und im Spiel
bereits eingebaut sind:

**Clips vom Snatch-Moment.** Der emotionale Reaktions-Clip ist auf dieser
Plattform der wirksamste organische Kanal überhaupt — beim größten Steal-Spiel
haben Videos von Kindern, die ihre Beute verlieren, zweistellige Millionen
Views gemacht und wie Werbung gewirkt. Unsere Snatch- und Kisten-Mechanik
produziert genau solche Momente. Vertikal, unter 20 Sekunden, die Reaktion in
der ersten Sekunde.

**Die Reveal-Karte.** Sie druckt die echte Quote ("1 in 540.000"). Das ist
genau das Bild, das Leute posten.

**Das Season-Badge.** Ein Wochenend-Fenster mit einer Belohnung, die danach
nie wiederkommt, ist ein Grund, im Discord oder in Kommentaren zu schreiben
"das läuft nur bis Sonntag". Das ist Mundpropaganda mit eingebauter Deadline.

**Und ein Kanal, der Geld kostet, aber kein Ads-Budget ist:** kleine
Roblox-YouTuber und TikToker. Ein Creator mit 20–50k Abos ist oft für einen
niedrigen dreistelligen Betrag zu haben und liefert Zuschauer, die deinem
Genre schon zugeneigt sind. Achte darauf, dass er das Genre tatsächlich spielt
— ein Obby-Kanal bringt dir für ein Mining-Spiel nichts, egal wie groß er ist.

---

## 8. Die häufigsten Fehler

- **Budget zu klein für Daten.** 3 $ pro Tag erzeugt Rauschen, keine Erkenntnis.
- **Icon nicht getestet, bevor skaliert wird.** Der teuerste Fehler auf dieser Liste.
- **Werbung für ein Spiel mit schlechter Bindung.** Siehe Abschnitt 6.
- **Zu enges Targeting am Anfang.** Lass den Algorithmus arbeiten.
- **Kosten pro Spieler nicht sauber getrackt.** Ohne diese Zahl ist alles Gefühl.
- **Jeden Tag an den Geboten drehen.** Kampagnen brauchen Lernphasen.

---

## Quellen

- [Complete Guide to Roblox Advertising (2026)](https://bloxg.com/guides/roblox-ads-guide)
- [How Much Does Roblox Marketing Cost in 2026?](https://bloxg.com/how-much-does-roblox-marketing-cost)
- [Sponsored Experiences moving to Ads Manager](https://devforum.roblox.com/t/sponsored-experiences-moving-to-ads-manager/2661756) — Roblox DevForum
- [The Roblox Advertising Playbook](https://www.guptamedia.com/insights/roblox-advertising) — Gupta Media
- [The Algorithm Behind 'Steal a Brainrot'](https://freesystems.substack.com/p/the-algorithm-behind-steal-a-brainrot) — zur Wirkung der Reaktions-Clips
