# Trend-Recherche → Änderungen am Spiel

**Stand: 8. September 2026.** Alles hier ist recherchiert, nicht erinnert.
Quellen stehen unten. Wo eine Quelle einer anderen widerspricht, steht das
ausdrücklich da — ich habe den Widerspruch nicht weggeglättet.

---

## Korrektur an meiner ersten Fassung

Im ersten `LAUNCH_PLAYBOOK.md` stand, der Algorithmus bewerte im Kern
**CTR, D1-Retention, Session-Länge und Gesamt-Playtime**. Das war für 2024/25
richtig und ist für 2026 **falsch**. Roblox hat den Empfehlungsalgorithmus
umgebaut und die tatsächlich verwendeten Signale veröffentlicht. Zwei davon
hatte ich nicht auf dem Schirm, und auf beiden stand DEEP RUSH bei null.

Das ist die wichtigste Erkenntnis dieser Runde, und sie hat mehr am Spiel
verändert als alles andere.

---

## Befund 1 — Die sechs echten Ranking-Signale

Roblox nennt sie inzwischen selbst, im Developer-Forum-Announcement zum
verbesserten „Recommended For You":

| # | Signal | Was es misst |
|---|---|---|
| 1 | **qPTR** (qualified play-through rate) | Anteil der Impressions, die zu einem „engaged play" werden |
| 2 | **7-Tage-Playtime pro Nutzer** | **gedeckelt bei 60 Min/Tag und Erlebnis** |
| 3 | **7-Tage-Spieltage pro Nutzer** | an wie vielen *verschiedenen Tagen* gespielt wird |
| 4 | **7-Tage-Ausgabetage pro Nutzer** | an wie vielen *Tagen* Robux ausgegeben wird |
| 5 | **7-Tage-Robux pro Nutzer** | Höhe der Ausgaben |
| 6 | **7-Tage-Co-Play-Tage pro Nutzer** | Freunde einladen, beitreten, private Server |

Roblox sagt dazu ausdrücklich: *„There is no one signal that is most
important. All of these signals work together."*

Dazu kommt: das Bewertungsfenster wurde von 7 auf **28 Tage** erweitert, mit
getrennten Phasen für Tag 1, Tag 2–7 und Tag 8–28. Erklärtes Ziel ist, Spiele
zu verdrängen, die „mit aufregenden Thumbnails Aufmerksamkeit gewinnen, aber
keinen langfristigen Wert liefern".

> **Widerspruch, ehrlich benannt:** Eine verbreitete Drittanbieter-Analyse
> beziffert die Gewichte mit „CCU 30–35 %, CCU-Velocity 20–25 %". Das steht im
> Gegensatz zu Roblox' eigener Aussage, dass nicht primär auf CCU oder
> Session-Länge gerankt wird. Ich habe im Zweifel der Primärquelle geglaubt und
> das Spiel danach gebaut. Die Drittanbieter-Zahlen sind Rückschlüsse aus
> Platzierungsmustern, keine offiziellen Gewichte.

### Was das für DEEP RUSH hieß

| Signal | Vorher | Jetzt |
|---|---|---|
| qPTR | kein Cover | 3 Thumbnails + Icon, auf Grid-Größe geprüft |
| Playtime | ok | ok — aber der 60-Min-Deckel heißt: Marathon-Design ist verschenkt |
| **Spieltage** | nur Dailies | **Descent Log über 28 Tage** |
| **Ausgabetage** | nur teure Pässe | **Daily Deal, 25–49 R$, täglich rotierend** |
| Robux/Nutzer | Pässe | unverändert |
| **Co-Play-Tage** | **null** | **Crew-System, Pings, Rettung, Invite-Prompt** |

---

## Befund 2 — Was gerade tatsächlich oben steht

Live-Charts vom 7./8. September 2026:

| Spiel | Gleichzeitige Spieler |
|---|---|
| Steal An Egg | ~1,4–1,9 Mio |
| Brookhaven 🏡RP | ~438.000 |
| Blox Fruits | ~348.000 |
| **+1 Speed Keyboard Escape** | ~267.000 |
| Murder Mystery 2 | ~256.000 |
| 99 Nights in the Forest | ~225.000 |

Zwei Sachen daran sind für uns relevant:

**Das Steal-Genre führt weiter.** Steal An Egg kombiniert Sammeln, passives
Einkommen und Diebstahl zwischen Spielern. Die Gier-Mechanik in DEEP RUSH
sitzt im selben Nerv — das war schon richtig und bleibt es.

**„+1 Speed Keyboard Escape" hat mit einem Ingame-Konzert 6,35 Mio
gleichzeitige Spieler erreicht** (25. Juli 2026). Live-Events sind der
größte einzelne Spike-Hebel auf der Plattform. Unser Rift Surge ist ein
12-Minuten-Mikro-Event; der Weekly Contract gibt dem Spiel jetzt zusätzlich
einen Wochenpuls.

---

## Befund 3 — Chat ist seit Januar 2026 altersverifiziert

Roblox verlangt weltweit eine Gesichts-Altersschätzung oder ID-Prüfung für
Chat-Zugang und sortiert Nutzer in sechs Altersklassen. Wer nicht verifiziert
ist, chattet nicht; wer verifiziert ist, chattet nur innerhalb passender
Altersgruppen.

**Konsequenz fürs Design:** Ein Koop-System, das Absprache per Text braucht,
schließt einen großen Teil der Spielerschaft aus. Deshalb ist die gesamte
Crew-Koordination in DEEP RUSH nonverbal:

- **Vier feste Pings** (Reiche Ader / Gefahr / Lift / Zu mir) — mehr Vokabular
  gibt es nicht, und mehr braucht es nicht.
- **Beacon statt Einladung**: du läufst zum Licht und drückst einen Knopf.
- **Nähe-Bonus statt Absprache**: zusammen graben zahlt sich aus, ohne dass
  jemand etwas erklären muss.

Roblox verlangt für vorgefertigte Kommunikationssysteme seit April 2026
Konformität mit eigenen Richtlinien — ein fester Ping-Satz ohne Freitext ist
genau die Form, die dort vorgesehen ist.

---

## Befund 4 — Das Doomscrolling-Verbot (August 2026)

Roblox hat Spiele aus den Kids- und Select-Katalogen verbannt, die **alle
drei** Merkmale erfüllen:

1. sie zeigen einen Medien-Feed (Kurzvideos, Bilder, Stories),
2. sie imitieren Autoplay, Endlos-Loop, Infinite Scroll oder Autoscroll,
3. sie koppeln Belohnungen an fortgesetztes Zuschauen.

Auslöser war Steal An Egg, das Spielern auf dem Laufband „Reels" vorspielte.

**Konsequenz:** Unsere Rewarded-Video-Integration ist bewusst die
Gegenform — ein einzelner, freiwilliger Knopf mit einer Stunde Abklingzeit,
kein Feed, kein Autoplay, keine Belohnung, die vom Weiterschauen abhängt. Das
steht so auch im Kopf von `src/server/Ads.luau`, damit es niemand später
versehentlich in die verbotene Richtung umbaut.

---

## Befund 5 — Rewarded Video ist seit Februar 2026 für alle offen

Für Spiele, die es gut platzieren, macht es **8–15 % des Umsatzes** aus,
bei eCPM von etwa 6–12 US-Dollar und Abschlussraten über 90 %.

**Aber:** Voraussetzung sind unter anderem 2FA, ein ID-verifizierter Inhaber
ab 13, ein öffentliches Erlebnis und **mindestens 2.000 eindeutige Besucher
pro Monat**. Ein frisches Spiel qualifiziert sich also nicht sofort.

Deshalb ist die Integration **abgeschaltet, bis du eine Produkt-ID einträgst**,
und der Knopf erscheint nur, wenn Roblox tatsächlich eine Anzeige liefert.
Belohnung ist ein Luck-Boost — Robux als Ad-Belohnung sind verboten.

---

## Befund 6 — Kosmetik schlägt Zeitersparnis

Die 2026er Ausgabenlage: Spieler geben mehr für **Kosmetik, Statussymbole und
Seltenheits-Flex** aus als für Time-Skips.

DEEP RUSH verkaufte ausschließlich Tempo und Komfort — genau die Kategorie,
die Anteile verliert. Neu ist deshalb eine Kosmetik-Ebene mit einer harten
Regel: **ein Kosmetikum muss für andere Spieler sichtbar sein.**

- **Helmlampen** färben den Fels um dich herum
- **Trails** sieht man, wenn du an jemandem vorbeifällst
- **Titel** stehen auf dem Namensschild über dir

Die meisten werden verdient, nicht gekauft, und die kaufbaren sind bewusst
nicht die schönsten.

---

## Befund 7 — Das Grab-Genre zieht, aber hält nicht

„Dig to Earth's CORE!" hat über **335 Millionen Visits** — und lag im April
2026 bei rund **1.100 gleichzeitigen Spielern**. Ein klassischer Spike mit
anschließendem Absturz.

Das ist zweierlei: eine Bestätigung, dass das Genre zieht, und ein sehr
konkreter Hinweis darauf, woran es scheitert. Unter dem neuen 28-Tage-Modell
ist genau dieses Muster das, was am härtesten bestraft wird — und damit die
Lücke, in die ein Grab-Spiel mit echter Langzeitstruktur stoßen kann.

---

## Was konkret ins Spiel kam

| Änderung | Befund | Dateien |
|---|---|---|
| **Crew-System** (Beacon, Nähe-Bonus +36 % Cash / +0,75 Luck) | 1, 3 | `server/Crew.luau`, `client/Crew.luau`, `Config/Crew.luau` |
| **Ping-System**, vier feste Signale, kein Freitext | 3 | dieselben |
| **Rettung**: Kiste eines Crewmates zurückgeben statt plündern | 1, 3 | `server/Steal.luau` |
| **Freunde-Einladen-Knopf** über `SocialService` | 1 | `client/Crew.luau` |
| **Weekly Contract**: 7 Stufen, Tagesdeckel ~26 Min | 1, 2 | `server/Contracts.luau`, `Config/Contracts.luau` |
| **Descent Log**: Meilensteine bis Tag 28 | 1 | dieselben |
| **Daily Deal**: 25–49 R$, täglich rotierend | 1 | `Config/Products.luau`, `server/Monetization.luau` |
| **Kosmetik**: Lampen, Trails, Titel + Namensschild | 6 | `server/Cosmetics.luau`, `Config/Cosmetics.luau` |
| **Rewarded Video**, gated und richtlinienkonform | 4, 5 | `server/Ads.luau` |
| **Cover**: 3 Thumbnails + Icon | 1 (qPTR) | `cover/` |

Dazu ein Fehler, den die neue Protokollprüfung gefunden hat: **heruntergefallene
Frachtkisten konnten gar nicht von Hand aufgehoben werden** — der Server hat
`GrabCrate` immer akzeptiert, aber kein Knopf im Client hat es je gesendet.
Eine Kernmechanik war seit dem ersten Tag tot.

---

## Was ich bewusst NICHT gebaut habe

- **Kein Ingame-Konzert.** Der 6,35-Mio-Spike von „+1 Speed" kam aus einer
  Künstlerkooperation, nicht aus Code. Das ist ein Marketingprojekt.
- **Kein Medien-Feed**, in keiner Form. Siehe Befund 4.
- **Kein Co-Play im Onboarding.** Die Crew-Aufgaben sind Dailies, nie Teil der
  Einstiegskette — sonst hängt ein neuer Spieler in einem leeren Server fest.
  Der Balance-Check erzwingt das inzwischen als Regel.
- **Kein Handel.** Unverändert die richtige Entscheidung: Scams und
  Moderationsaufwand lohnen sich erst ab einer Spielerbasis, die man erst haben muss.

---

## Zweite Runde (9. September 2026): Cover, Sog, Werbung

### Befund 8 — Thumbnails: der blockige Avatar ist Pflicht, nicht Geschmack

Die erste Cover-Fassung nutzte eine glatte Silhouette. Sie sah gut aus und war
plattformfremd. Was die Recherche zu 2026er Thumbnails ergibt:

- Ein Render des **eigenen Rigs** hält Outfit, Accessoires und Gesicht über
  alle Thumbnails konstant — so bauen Roblox-Kanäle Wiedererkennung auf.
- **Starke Emotionen im Gesicht schlagen neutrale um bis zu 40 %** in der
  Klickphase. "Erschrocken" ist die Standardmimik der Plattform.
- **Action-Posen und klare Silhouetten** bekommen mehr Klicks.
- **Rohe Screenshots verlieren fast immer** gegen ein gestaltetes Bild.
- **Icon und Thumbnail lösen verschiedene Probleme**: das Icon entscheidet den
  Klick, die Thumbnails die Spiel-Entscheidung. Sie werden unterschiedlich
  gestaltet.
- Wachsendes Problem: **visuelle Ermüdung**, weil zu viele Thumbnails gleich
  aussehen.

**Umsetzung:** `cover/assets/robloxian.js` baut ein klassisches R6-Rig aus
echten 3D-Boxen — projiziert, tiefensortiert, pro Fläche schattiert, mit
echten Gelenkrotationen. Dazu erschrockenes Gesicht, Helm, Warnweste,
Spitzhacke. Es steckt jetzt in allen drei Thumbnails und im Icon.

Gegen die Ermüdung hilft der Schacht: der Tunnel-Hintergrund gehört keinem
anderen Spiel, und der Charakter davor liefert trotzdem die
Plattform-Zugehörigkeit.

**Dein echter Avatar:** `node cover/avatar.mjs <username>` holt einen
transparenten Render über die offizielle Thumbnails-API. Voreinstellung bleibt
die gezeichnete Figur, weil sie posierbar ist und keinem fremden Menschen
gehört.

### Befund 9 — Was Spieler "das brauche ich" denken lässt

Aus der Analyse der aktuell größten Spiele:

- **Live-Wochenend-Events mit Belohnungen, die man nur bekommt, wenn man da
  war.** Wer das Event verpasst, bekommt nichts. Das ist der Kern.
- **Sichtbare Sammlungen.** Spieler sehen die Gärten der anderen; der
  Wettbewerb dreht sich darum, die seltensten Sachen zu haben.
- **Emotionale Reaktions-Clips** wirken wie kostenlose Werbung — Videos von
  Kindern, die ihre Beute verlieren, haben zweistellige Millionen Views
  gemacht.

**Umsetzung:** das **Season-Fenster** (Sa/So UTC, exklusives Erz, permanentes
Badge, das nie wiederkommt) und der **beste Fund auf dem Namensschild**, mit
echter Quote, für jeden sichtbar.

**Was ausdrücklich nicht übernommen wurde.** Dieselbe Analyse beschreibt
Mechaniken, die klar Glücksspiel-Charakter haben: zeitgesperrte Spins mit
Kaufoption zum Überspringen, und **Robux ausgeben, um die Gewinnchancen zu
erhöhen** — vom Autor selbst als Kern-Glücksspieldynamik bezeichnet, gerichtet
an ein überwiegend minderjähriges Publikum. Das Season-Badge ist deshalb
unverkäuflich, in einer Sitzung erreichbar, und der Preis ist Anwesenheit,
nicht Geld. Der Balance-Check erzwingt alle drei Punkte.

### Befund 10 — Werbung: ja, ab etwa 35 Dollar

| Kennzahl | Wert |
|---|---|
| Mindestkauf | 10 Ad Credits ≈ 2.850 Robux ≈ **35 $** |
| Mindest-Tagesbudget | 1 $ (sinnvoll: 10–20 $) |
| Kosten pro Besuch | 0,01–0,05 $ |
| Kosten pro Klick | 0,10–0,50 $ |
| Kosten pro engagiertem Spieler | 0,20–1,00 $ |
| 100 $ Test | 2.000–10.000 Besuche |

Vollständiger Plan inklusive der Schwelle, ab der sich Werbung überhaupt
lohnt, in [`ADS_PLAYBOOK.md`](ADS_PLAYBOOK.md). Kurzfassung: **erst halten,
dann kaufen** — unter 10 % D1-Retention verbrennt bezahlter Traffic Geld
zweimal, weil der Empfehlungsalgorithmus genau mitzählt, dass niemand
wiederkommt.

---

## Dritte Runde (13. September 2026): Sichtbarkeit von Seltenheit

Diese Runde ging einer Frage nach: **warum explodieren gerade die Spiele, die
explodieren?** Nicht welche oben stehen, sondern was sie mechanisch gemeinsam
haben.

### Befund 8 — Seltenheit muss man sehen können

Das Muster über *Steal a Brainrot*, *Grow a Garden 2*, *Pet Simulator 99*,
*Adopt Me!* und die RNG-Welle (*Sol's RNG*) hinweg ist immer dasselbe: der
Kern ist eine Seltenheitsleiter, und **die Seltenheit ist sichtbar** — an der
Figur, im Inventar, über dem Kopf, in der Welt. Sammelspiele laufen darauf,
dass Spieler sehen können, was andere haben; ohne das ist ein seltener Fund
eine private Zahl.

DEEP RUSH hatte die Leiter (8 Stufen, 32 Erze) und zeigte sie an genau einer
Stelle: der Karte *nach* dem Abbau. Der Stein selbst war ein grauer Würfel.
Man konnte nicht auf eine Wand schauen und wissen, wo es sich lohnt.

**Was daraus wurde:** Ein Knoten würfelt sein Erz jetzt beim Entstehen, nicht
beim Schlag. Gold hat eine goldene Ader in Metall, Diamant wächst als
Glaskristall aus dem Fels, Nullstone frisst Licht. Ab *Rare* steht der Name
darüber, ab *Epic* schießt eine Lichtsäule den Schacht hoch. Das ändert das
Spiel von „schlag auf irgendwas" zu „lauf da hin".

### Befund 9 — Offene Quoten erhöhen die Zufriedenheit

Belegt, nicht vermutet: Als Overwatch detaillierte Wahrscheinlichkeitstabellen
veröffentlichte, stieg die Spielerzufriedenheit um 23 %. Moderne Studios
veröffentlichen inzwischen exakte Prozentwerte, und die RNG-Spiele auf Roblox
machen die Quote (*1 in 100.000.000*) zum eigentlichen Produkt.

DEEP RUSH zeigte die echte Quote schon auf der Reveal-Karte. Neu ist, dass
sie auch dann stimmt, wenn Glück im Spiel war: Luck ist jetzt ein zweiter
Wurf *über* dem, was der Stein zeigt, und `Rarity.odds` rechnet die
Gesamtverteilung exakt aus statt sie zu schätzen. Wenn Glück zuschlägt, sagt
die Karte es ausdrücklich („⚡ LUCK BEAT THE VEIN").

### Befund 10 — Glücksspiele boomen kurz, Systeme halten lang

Die Analysen sind hier einig und unangenehm deutlich: **luck-based
experiences** sind extrem gut für kurzfristige Sichtbarkeit und haben hohe
Churn-Raten und schnelle Ablösezyklen. Was bleibt — Brookhaven, Adopt Me!,
Blox Fruits, Pet Sim 99 — hält über langfristige Systeme, faire
Monetarisierung und Community.

**Was daraus wurde:** das Rangsystem. Zehn Stufen auf Lebenszeit-Einzahlungen
— die einzige Zahl im Spiel, die nie fällt, auch nicht bei Tod, Diebstahl
oder Rebirth. Kupfer nach ~4 Minuten, die Spitze jenseits von allem, was die
Upgrade-Leiter kostet. Der Rang steht über dem Kopf, in der Spielerliste und
auf einem zweiten Board an der Oberfläche.

Ausdrücklich **ohne Vorteil**: kein Rang gibt Cash, Luck, Tempo oder Kapazität.
Der Balance-Check erzwingt das (`no rank hands out an advantage`). Sobald ein
Rang etwas auszahlt, ist Zurückliegen nicht mehr etwas, das man aufholen
will, sondern etwas, das man ungerecht findet.

### Befund 11 — Future-Lighting ist der größte Grafik-Hebel

Roblox empfiehlt **Future** inzwischen für alle neuen Projekte: echte Schatten
von allen Lichtquellen, Specular-Highlights, Umgebungsreflexionen. Es ist
explizit dafür gebaut, mit PBR-Materialien zusammenzuarbeiten. Und: Bloom soll
einen **hohen Threshold** haben, sonst wird alles matschig und das Spiel sieht
aus wie durch Vaseline.

Ein Spiel, das zu 90 % aus Punktlichtern in Fels besteht, gewinnt daran mehr
als fast jedes andere. Unter Voxel ist eine Goldader ein gelber Kasten; unter
Future hat sie ein Glanzlicht, das mitwandert.

**Was daraus wurde:** `Technology = Future`, Bloom mit Threshold 1.35 (nur
Neon-Erz, Lifte und der Tresor leuchten), Depth of Field mit Fokus knapp
hinter Abbaureichweite, Sonnenstrahlen, die mit der Tiefe verschwinden — und
der ganze Post-Stack folgt derselben Tiefenkurve wie die Farbkorrektur.

---

## Quellen

**Dritte Runde (13. September 2026):**

- Roblox-Charts und Genre-Analysen zu den aktuell größten Titeln
  ([dualshockers](https://www.dualshockers.com/best-roblox-games-to-play-in-2026/),
  [studiokrew](https://studiokrew.com/blog/top-games-on-roblox-and-analysis-2026/))
- *Steal a Brainrot* — Tycoon-Progression + Diebstahl + Rebirth, erstes
  Roblox-Erlebnis über 25 Mio. gleichzeitige Nutzer
  ([Wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot))
- *Grow a Garden 2* (Juni 2026) — PVP-Diebstahl bei Nacht, Gilden mit
  Wochenbelohnungen ([Wikipedia](https://en.wikipedia.org/wiki/Grow_a_Garden))
- Wahrscheinlichkeits-Mechaniken und Quotentransparenz
  ([GameTyrant](https://gametyrant.com/news/probability-mechanics-in-game-design-2026),
  [KitsBlox zu RNG-Spielen](https://kitsblox.com/blog/how-to-make-an-rng-game-roblox))
- Future-Lighting und PBR
  ([Roblox Creator Hub](https://create.roblox.com/docs/art/modeling/surface-appearance),
  [Lighting-Technology-Guide](https://roblox-studio-lighting-technology.pages.dev/),
  [Simplified Media](https://simplified.media/guides/roblox-lighting-atmosphere))


- [Optimizing Discovery: How Great Games Reach Millions of Players on Roblox](https://about.roblox.com/newsroom/2026/06/optimizing-discovery-great-games-reach-millions-players-roblox) — Roblox Newsroom, Juni 2026
- [Boost Your Discovery with the Improved Recommended For You Algorithm](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441) — Roblox DevForum (die sechs Signale)
- [Rewarded Video ads are now available to all ads eligible creators](https://devforum.roblox.com/t/rewarded-video-ads-are-now-available-to-all-ads-eligible-creators/4063278) — Roblox DevForum, Februar 2026
- [Age Check Requirement to Chat Now Live Globally](https://devforum.roblox.com/t/age-check-requirement-to-chat-now-live-globally/4226101) — Roblox DevForum
- [Roblox Forces Its Biggest Game To Axe Doomscrolling Mechanic](https://kotaku.com/roblox-cracks-down-on-doomscrolling-games-like-steal-an-egg-that-forces-players-to-watch-reels-while-running-on-a-treadmill-2000727952) — Kotaku, August 2026
- [Most Played Roblox Games Right Now](https://rblxdb.com/charts/most-played) — rblxdb, Live-Charts
- [AdService](https://create.roblox.com/docs/reference/engine/classes/AdService) / [SocialService](https://create.roblox.com/docs/reference/engine/classes/SocialService) — Roblox Creator Docs
- [Roblox Monetization Trends 2026](https://rolearn.dev/trend-reports/roblox-monetization-trends-devex-creator-rewards/) — RoLearn (Drittanbieter)
- [How the Roblox Discovery Algorithm Works in 2026](https://rolearn.dev/insights/roblox-game-discovery-algorithm-2026/) — RoLearn (Drittanbieter; widerspricht der Primärquelle, siehe Befund 1)
- [How to Make a Roblox Thumbnail (With Your Real Avatar)](https://www.renderbux.com/guides/how-to-make-a-roblox-thumbnail)
- [How to Make a Roblox Thumbnail That Gets Clicks (2026)](https://vizzbees.com/blog/how-to-make-a-roblox-thumbnail)
- [Complete Guide to Roblox Advertising (2026)](https://bloxg.com/guides/roblox-ads-guide)
- [Roblox Avatar Thumbnails API](https://thumbnails.roblox.com/docs) — für `cover/avatar.mjs`
