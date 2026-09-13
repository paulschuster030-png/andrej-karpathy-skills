# DEEP RUSH — Design-Dokument

Warum dieses Spiel so gebaut ist. Jede Zahl hier steht auch im Code; wenn du
etwas änderst, ändere beides.

---

## 1. Die Ausgangslage: was auf Roblox tatsächlich funktioniert

Roblox ist kein Genre-Markt, sondern ein **Mechanik-Markt**. Die Spiele, die
oben stehen, teilen sich nicht das Thema, sondern denselben Satz von
Mechaniken. Aus der Beobachtung der Erfolge der letzten Jahre — Sammel- und
Zuchtspiele, Steal-Spiele, Angel- und Grind-Spiele, Survival-Runden — fallen
sechs Bausteine immer wieder auf:

| Baustein | Warum er zieht | In DEEP RUSH |
|---|---|---|
| **Zahl steigt** | Fortschritt ohne Lesen verständlich | Tiefe, Cash, Multiplikatoren |
| **RNG mit Multiplikator-Stapel** | erzeugt teilbare Extremwerte | 8 Stufen × 5 Mutationen |
| **Soziale Reibung** | erzeugt Geschichten, nicht nur Punkte | Gier-Markierung + Snatch |
| **Kurzer Entscheidungszyklus** | passt in eine Bushaltestelle | 60–90 s pro Tauchgang |
| **Sammlung** | gibt Identität über den Grind hinaus | Codex (32 Erze) + Drohnen |
| **Prestige-Reset** | verlängert die Kurve um Größenordnungen | Rebirth mit Schicht-Gating |

Was diese Spiele **nicht** teilen: Grafikqualität, Story, Steuerungstiefe. Das
ist die eigentliche Lektion. Ein neues Spiel gewinnt nicht durch bessere
Assets, sondern durch einen Loop, der in den ersten 60 Sekunden funktioniert.

**Die Zielgruppe realistisch:** überwiegend mobil, oft im Querformat auf einem
Telefon, häufig mit Ton aus, in Sessions von wenigen Minuten, fast immer
parallel zu einem Discord- oder YouTube-Fenster. Daraus folgt hart:

- Ein Knopf muss mit dem Daumen treffbar sein (in `Ui.luau` sind alle
  Aktionsflächen ≥ 56 px hoch).
- Nichts Wichtiges darf nur über Text kommuniziert werden — die Frachtleiste
  wird rot, *bevor* jemand das Wort "MARKED" liest.
- Der erste Belohnungsmoment muss vor Sekunde 30 liegen.

---

## 2. Warum ein Grab-Spiel

"Tiefe" ist die seltene Progressionsachse, die vier Dinge gleichzeitig ist:

1. **Ein Fortschrittsbalken**, der niemand erklärt werden muss.
2. **Eine Risikokurve** — unten ist es objektiv gefährlicher.
3. **Ein Bestenlisten-Wert**, der sich in drei Zeichen ausdrücken lässt.
4. **Eine räumliche Wahrheit** — du *siehst*, wie weit du gekommen bist.

Kaum eine andere Achse leistet das. "Level 47" ist keine Bedrohung, "1.400 m"
schon.

### Der asymmetrische Weg

Der wichtigste einzelne Designgriff im Spiel:

> **Nach unten ist gratis. Nach oben kostet.**

Du steigst ab, indem du springst — Roblox hat keinen Fallschaden, ein Sturz
über 900 m ist reiner Nervenkitzel und dauert Sekunden. Hochzukommen geht nur
über Liftplattformen, die alle 100 m liegen und ohne Pass 4 Sekunden binden.

Das erzeugt die zentrale Spannung ohne eine einzige Textzeile: Jeder Meter
tiefer ist eine Wette darauf, dass du auch wieder hochkommst.

---

## 3. Die drei Loops

```
MICRO   3–8 s     zielen → schlagen → Erz-Pop → Zahl steigt
CORE    60–90 s   abspringen → Vorsprung leerräumen → tiefer oder Lift?
                  → Tresor → Cash → Upgrade
META    Tage      Upgrade-Leiter → Rebirth → tiefere Schicht → Codex
```

Der CORE-Loop hat genau einen Entscheidungspunkt, und das ist der ganze Punkt
des Spiels: **bunkern oder weitergraben.** Alles andere im Design existiert,
um diese Entscheidung schwerer zu machen.

- Der Streak-Bonus (+4 % pro Fahrt, max. +40 %) belohnt *häufiges* Bunkern —
  aber nur, wenn die Fahrt tiefer als 150 m ging. Ohne diese Klausel wäre die
  optimale Strategie, bei 10 m einzelne Steine zu bunkern. Solche Exploits
  designt man weg, statt sie später zu patchen.
- Die Gier-Markierung bestraft *seltenes* Bunkern.
- Der Tiefen-Multiplikator belohnt Weitergraben.

Drei Kräfte, die sich widersprechen. Genau deshalb ist die Entscheidung
interessant.

---

## 4. Gier: die soziale Mechanik

Steal-Mechaniken sind auf Roblox extrem zugkräftig und extrem leicht
kaputtzumachen. Die Standardfehler: Neue werden von Veteranen ausgezogen, und
Diebstahl fühlt sich wie Belästigung an statt wie ein Spiel.

DEEP RUSH koppelt Bestehlbarkeit deshalb an **eine einzige, sichtbare,
selbstgewählte Größe**:

```
Gier = belegte Frachtslots / Kapazität
Ab 60 % bist du MARKIERT: du leuchtest, du erscheinst auf fremden Bildschirmen,
du kannst bestohlen werden.
```

Daraus folgt eine Regel, die man einem Neunjährigen in einem Satz erklärt:
**Wer viel trägt, ist ein Ziel.** Und daraus folgen die Eigenschaften, die die
Mechanik fair machen:

- Wer vorsichtig spielt, kann **nie** gegriffen werden. Kein Griefing möglich.
- Wer neu ist (< 10 Min Spielzeit **und** < 100 m Tiefe), ist beidseitig immun
  — kann weder bestohlen werden noch stehlen. Das blockt auch Alt-Account-Farming.
- Ein Snatch nimmt 15 % der Fracht, hat 45 s Abklingzeit und 18 Studs
  Reichweite. Er ruiniert niemanden, er erzeugt eine Geschichte.
- Das *Safe Pocket*-Upgrade reduziert den Verlust, verhindert den Snatch aber
  nie vollständig — sonst wäre das Leuchten eine Lüge.

Beim Tod gehen 30 % verloren, 70 % fallen als Kiste zu Boden: 6 Sekunden nur
für dich, danach für alle. Das ist der Clip-Generator des Spiels.

---

## 5. Die Mathematik der teilbaren Momente

Ein Spiel wird nicht weiterempfohlen, weil es ausgewogen ist, sondern weil
jemand einen Screenshot macht. Also ist der Raum der möglichen Extremwerte
ein **Design-Parameter**, kein Zufall.

**Zwei unabhängige Multiplikatoren:**

```
Wert = Basiswert × Tiefenmultiplikator × Mutationsmultiplikator
```

| Seltenheit | Gewicht | | Mutation | Faktor | Chance |
|---|---|---|---|---|---|
| Common | 1000 | | Glowing | ×2 | 8 % |
| Uncommon | 260 | | Frozen | ×3 | 3 % |
| Rare | 70 | | Cursed | ×5 | 1 % |
| Epic | 18 | | Golden | ×8 | 0,25 % |
| Legendary | 4,5 | | Rift-Touched | ×15 | nur im Rift |
| Mythic | 0,9 | | | | |
| Abyssal | 0,12 | | | | |
| Singularity | 0,0025 | | | | |

Singularity liegt bei Luck 1 in einer Schicht mit allen Stufen bei etwa
**1 zu 540.000** — und deutlich besser in den tiefsten Schichten, wo die
häufigen Stufen gar nicht mehr vorkommen. Genau dieses Gating macht das
Absteigen zum echten Fortschritt statt zum Farmen an derselben Stelle.

**Luck wirkt exponentiell, nicht additiv:**

```lua
effektivesGewicht = gewicht × luck^((stufe - 1) × 0.6)
```

Bei Luck 2 wird Mythic 8× wahrscheinlicher, Singularity 18× — Common bleibt
unverändert. Deshalb fühlt sich ein Luck-Trank anders an als ein Cash-Trank,
und deshalb ist Luck bei 30 hart gedeckelt: ohne Deckel macht ein gestapelter
Buff aus Singularity einen Münzwurf.

**Die Quote wird angezeigt.** Die Reveal-Karte druckt die echte
Wahrscheinlichkeit ("1 in 250K"). Die Quote *ist* der Flex — sie zu verstecken
verschenkt den halben Wert des Moments.

---

## 6. Rift Surge: das Live-Event

Alle ~12 Minuten öffnet sich für 90 Sekunden in einer zufälligen Schicht ein
Riss: 5× Luck und die Rift-Touched-Mutation, die es sonst nirgends gibt.

Ein Event leistet drei Dinge auf einmal, sonst wäre der Aufwand nicht
gerechtfertigt:

1. Es **verdichtet** einen verstreuten Server auf einen Ort — und Dichte ist
   auf Roblox praktisch die Definition von "der Server lebt".
2. Es gibt einem gelangweilten Spieler einen Grund, **zwei Minuten länger** zu
   bleiben. Der sichtbare Countdown ist der eigentliche Mechanismus.
3. Es zieht Veteranen aus den tiefen Schichten **zurück nach oben** unter neue
   Spieler. Ohne das segregiert ein Tiefenspiel seine Population.

Die Schicht wird gewichtet nach dem, was die aktuell anwesenden Spieler
erreichen können — ein Event, zu dem niemand hingehen kann, ist schlechter als
gar kein Event.

---

## 7. Aufgaben: das Rückgrat der Bindung

Roblox entscheidet über den Erfolg eines Spiels im Wesentlichen über
**D1-Retention**, und D1 fällt, bevor ein neuer Spieler drei Minuten drin war.
Deshalb hat das Aufgabensystem drei Ebenen mit unterschiedlichen Jobs:

**Onboarding (6 Schritte, erste ~5 Minuten).** Jeder Schritt ist nebenbei
erfüllbar: 5 Steine schlagen, einmal bunkern, ein Upgrade kaufen, 50 m
erreichen, ein Rare finden, 5.000 in einer Fahrt bunkern. Sie lehren die
Mechanik, ohne sie zu erklären. Auf dem Bildschirm steht immer genau **ein**
Ziel, und in der Welt schwebt ein Wegpunkt darauf zu. Ist die Kette durch,
verschwindet beides restlos — ein Tutorial, das bleibt, ist schlimmer als keins.

**Daily (3 aus 12, Reset um Mitternacht UTC, ein Reroll).** Der Grund für
morgen. UTC statt lokaler Zeit, weil ein lokaler Reset das Farmen der
Zeitzonengrenze erlaubt.

**Meilensteine (8, permanent).** Der immer sichtbare nächste Berg: 1.000 m,
2.000 m, 100M gebunkert, Codex komplett.

Dazu die zwei klassischen Tropfen: Login-Streak (Tag 7 = 150.000, Streak-Bruch
setzt auf Tag 1 zurück) und alle 10 Minuten eine Spielzeit-Kiste. Beides ist
geschenkt — eine Bindungsmechanik, die Robux kostet, bindet niemanden.

---

## 8. Crew: warum Alleinspielen jetzt teurer ist

Diese Ebene kam nach der Trendrecherche dazu, und zwar aus einem harten Grund:
Roblox zählt **Co-Play-Tage** als eigenes Ranking-Signal, und DEEP RUSH hatte
darauf exakt null zu bieten. Nichts am Spiel war mit einer zweiten Person
besser.

Zwei Randbedingungen haben das Design bestimmt:

**Kein Text.** Seit der Alterprüfung für den Chat (Januar 2026) können viele
Spielerpaare gar nicht miteinander schreiben. Ein Koop-System, das Absprache
braucht, schließt sie aus. Also besteht das gesamte Vokabular aus **vier
Pings** — Reiche Ader, Gefahr, Lift, Zu mir — und einem Näheeffekt. Niemand
muss etwas tippen, und nichts bricht, wenn zwei Crewmates in Altersklassen
sitzen, die nicht miteinander reden dürfen.

**Keine Lobby.** Der Bonus wird fürs Nebeneinander-Graben gezahlt (120 Studs),
nicht fürs Auf-einer-Liste-Stehen. Eine Crew, mit der du nie gräbst, ist nichts
wert. Das hält das Signal ehrlich statt farmbar.

Konkret: +12 % Cash und +0,25 Luck pro zusätzlichem Mitglied in Reichweite,
maximal +36 % / +0,75 bei vier Leuten. Groß genug, um Verhalten zu ändern;
klein genug, dass Solospiel nie ausgeschlossen ist.

Dazu kommt die **Rettung** — einem Crewmate seine gefallene Kiste zurückgeben
statt sie zu plündern, gegen 10 % Finderlohn. In einem Spiel, das auf Diebstahl
gebaut ist, braucht es genau eine eindeutig kooperative Handlung, damit eine
Crew sich wie eine Crew anfühlt.

**Eine Regel, die wir nicht brechen:** Co-Play steht **nie** auf dem
Onboarding-Pfad. Crew-Aufgaben sind Dailies, niemals Teil der Einstiegskette —
sonst hängt ein neuer Spieler in einem leeren Server fest. Der Balance-Check
erzwingt das inzwischen als Assertion.

---

## 9. Contract und Descent Log: das Spiel bekommt eine zweite Zeitachse

Roblox bewertet ein Erlebnis inzwischen über **28 Tage** und zählt **Spieltage**
statt Spielstunden — mit einem Deckel von 60 Minuten pro Tag und Erlebnis. Der
längste Bogen in DEEP RUSH war eine Tagesaufgabe. Das Spiel hatte einem Spieler
an Tag 12 nichts zu sagen.

**Weekly Contract.** Eine Währung, sieben Stufen, Reset am Montag. Punkte
kommen aus dem, was man ohnehin tut: eine tiefe Fahrt bunkern, ein Rare ziehen,
ein neues Erz finden, einen Tiefenrekord aufstellen, mit der Crew graben.

Die entscheidende Zahl ist der **Tagesdeckel**: rund 26 Minuten Spielzeit, dann
ist die Leiter für heute voll. Das ist keine Monetarisierungsschranke, sondern
Taktung — und sie deckt sich exakt mit dem 60-Minuten-Deckel des Algorithmus.
Der Text sagt deshalb "heute erledigt", nicht "gesperrt": alles andere zahlt
weiter, nur diese eine Leiter ruht.

**Ein Fehler, den der Balance-Check gefangen hat:** Ursprünglich gab es Punkte
pro 1.000 gebunkertem Cash. Das sieht fair aus, bis man merkt, dass Auszahlungen
mit Tiefe und Rebirths exponentiell wachsen — ein Spätspiel-Spieler hätte das
Tagesbudget mit **einer** Einzahlung geleert, während ein neuer eine Stunde
gräbt. Punkte kommen jetzt aus **Aktionen**, die skaleninvariant sind. Eine
tiefe Fahrt ist an Tag 1 dasselbe wert wie nach zehn Rebirths.

**Descent Log.** Einmalige Belohnungen für die Anzahl **verschiedener Tage**,
an denen du gespielt hast — bis Tag 28. Bewusst nach hinten gewichtet: der
Tag-28-Preis existiert, um an Tag 2 gesehen zu werden.

---

## 10. Kosmetik: Status braucht Publikum

Die 2026er Ausgabenlage ist eindeutig: Spieler geben mehr für Kosmetik,
Statussymbole und Seltenheits-Flex aus als für Zeitersparnis. DEEP RUSH
verkaufte ausschließlich Zeitersparnis.

Die Regel, die diese Ebene funktionieren lässt: **ein Kosmetikum muss für
andere sichtbar sein.** Ein Skin, den nur du siehst, ist ein Screenshot; ein
Skin, den der Schacht sieht, ist Status. Deshalb rendern alle drei Arten am
Charakter — die Helmlampe färbt den Fels um dich, den Trail sieht man, wenn du
an jemandem vorbeifällst, und der Titel steht auf dem Namensschild über dir.

Die meisten werden verdient. Die kaufbaren sind absichtlich nicht die schönsten.

---

## 10b. Season: die Belohnung, die nicht wiederkommt

Das größte Spiel der Plattform hat eine Mechanik, die sich in einem Satz
zusammenfassen lässt: **live-Events am Wochenende, deren Belohnung du schlicht
nicht bekommst, wenn du nicht da warst.** Knappheit plus Frist plus etwas, das
alle sehen können.

Bei uns heißt das so:

- Samstag und Sonntag (UTC) öffnet ein Fenster.
- Darin — und nirgends sonst — fällt der **Season Core**. Er ist aus jeder
  normalen Drop-Tabelle ausgeschlossen, kein Luck-Wert der Welt holt ihn
  außerhalb.
- Vierzig Stück bringen dir ein **Badge**: einen Titel und einen Trail mit dem
  Namen dieser Season, dauerhaft, und diese Season kommt nie zurück.

**Drei Regeln, die das sauber halten:**

1. **Es wird nie verkauft.** In dem Moment, in dem Knappheit kaufbar ist, ist
   sie keine Knappheit mehr, sondern ein Laden.
2. **Der Preis ist Anwesenheit, nicht Geld.** Wer keine Robux hat und zwei
   Stunden Zeit, bekommt exakt dasselbe wie ein zahlender Spieler.
3. **Es ist in einer Sitzung schaffbar** — rund 25 Minuten im Fenster. Eine
   Frist, die man nicht einhalten kann, ist keine Dringlichkeit, sondern nur
   ein verdorbener Abend. Der Balance-Check schlägt fehl, wenn das driftet.

Was wir aus demselben Werkzeugkasten **nicht** übernommen haben: bezahlte
Luck-Multiplikatoren an einem Glücksrad und Verlustmechaniken, die auf die
Tränen von Kindern hin optimiert sind. Beides funktioniert nachweislich. Beides
kommt hier nicht rein.

---

## 10c. Der beste Fund steht über deinem Kopf

Sammelspiele leben davon, dass Spieler sehen, was andere haben. Ohne das ist
ein seltener Fund eine private Zahl.

Deshalb trägt jeder Spieler sein **seltenstes Erz aller Zeiten** auf dem
Namensschild — mit Namen, Farbe der Seltenheitsstufe und der echten Quote:

```
◆ Golden Origin Shard · 1 in 4.3M
```

Das ist die billigste starke Idee im ganzen Spiel. An jemandem vorbeizulaufen,
der eine 1-zu-4,3-Millionen trägt, ist der Grund, weiterzugraben.

---

## 10d. Gefahren: von Würfel zu Ort

Die erste Fassung würfelte jede Sekunde und sagte bei einem Treffer eine
Sekunde vorher „die Decke knackt". Auf dem Papier fair — es gab ein Telegraph —
und es fühlte sich trotzdem willkürlich an. Der Grund: **die Gefahr hatte
keinen Ort.** Man konnte einen Raum ansehen und nicht wissen, wo man nicht
stehen sollte.

Jetzt ist jede Gefahr ein Objekt in der Welt, mit Namen und Schild:

| Zone | Verhalten | Gegenmittel |
|---|---|---|
| **Gaswolke** | Schaden, solange du drin bist | nicht drin sein |
| **Frostfeld** | bremst dich erst, dann Schaden | nicht drin sein |
| **The Hollow** | stärkster Dauerschaden | nicht drin sein |
| **Lose Decke** | Telegraph → Steinschlag | Timing |
| **Magma-Vent** | leuchtet auf → Feuersäule | Timing |
| **Druckschacht / Einsturz** | schneller Rhythmus, hoher Schaden | Timing |

Zwei Verhaltensweisen, und beide haben ein klares Gegenmittel. Bei den
pulsierenden ist die sichere Hälfte immer die längere — sonst wäre der
Rhythmus keine Lösung, sondern nur eine Wartezeit. Der Balance-Check erzwingt
das, ebenso wie: kein einzelner Ausbruch tötet aus voller Gesundheit, jede
Dauerzone lässt dir mindestens fünf Sekunden zum Rauslaufen, und **die erste
Schicht ist gefahrenfrei** — man lernt erst den Loop, dann das Ausweichen.

Nebenwirkung, die genauso viel wert ist: Der Schacht sah vorher leer aus.
Sichtbare Gefahren sind Deko, die weh tut.

---

## 10e. Werkzeug in der Hand und ein Weg zurück

Zwei Dinge, die das Spiel gebraucht hat und die erst der Laufzeit-Simulator
sichtbar gemacht hat.

**Die Spitzhacke.** Vorher hat man mit leeren Händen auf Stein eingeschlagen —
der Abbau war nur ein Fortschrittsbalken. Jetzt trägt jeder eine Spitzhacke,
die per `Motor6D` an der Hand hängt (nicht geschweißt, sonst ließe sie sich
nicht animieren) und bei jedem Schlag ausholt. Sie hat fünf Stufen, die dem
Drill-Upgrade folgen:

| Drill-Level | Spitzhacke |
|---|---|
| 0 | Rusted Pick |
| 5 | Steel Pick |
| 15 | Reinforced Pick |
| 30 | Gilded Pick |
| 50 | Abyssal Drill |

Das ist der billigste Statuskanal, den es gibt: Man sieht am Werkzeug des
anderen, wie weit er ist, ohne dass jemand etwas sagen muss — und seit
Roblox' Chat-Altersprüfung sagt sowieso kaum noch jemand etwas.

**Der Rückweg.** Der Simulator hat den Boden des Schachts als Falle entlarvt:
Die nächste Liftplattform lag 31 Studs *unter* dem Boden, die übernächsten 172
und 536 Studs darüber. Sprunghöhe: 7. Wer unten ankam, kam nicht mehr weg.
Drei Änderungen:

- **Ein Lift pro Chunk** statt jedem zweiten — der Abstand nach oben ist nie
  größer als ein Chunk.
- **Ein fester Lift am Grund**, auf einem eigenen Podest.
- **Notaufstieg** als letzte Sicherung: 12 Sekunden stillstehen, dann zurück
  an die Oberfläche. Wer sich dabei mehr als 22 Studs bewegt, bricht ab — es
  ist eine Rettung, keine Abkürzung.

Der Simulator prüft alle drei: Er misst den Abstand zur nächsten Plattform vom
tiefsten Punkt aus, fährt tatsächlich Lift und misst die Landeposition, und
startet den Notaufstieg einmal erfolgreich und einmal mit Bewegung.

---

## 10f. Der Stein zeigt, was drin ist

Die erste Fassung würfelte das Erz **beim Schlag**. Jeder Knoten war derselbe
graue Würfel, und was herauskam, erfuhr man erst danach. Das ist bequem zu
bauen und es nimmt dem Spiel seine einzige räumliche Entscheidung: Wenn alle
Steine gleich aussehen, ist es egal, zu welchem man läuft.

Jetzt würfelt ein Knoten sein Erz, **wenn er entsteht**, und der Fels zeigt es:

| Look | Material | Wer |
|---|---|---|
| **metal** | Metal, matter Glanz | Kupfer, Eisen, Silber, Gold, Magmasteel |
| **gem** | Glass, durchscheinend | Quarz, Amethyst, Smaragd, Diamant, Rubin |
| **crystal** | Neon, von innen beleuchtet | Prism, Ember, Frostcore, Abyssite, Origin |
| **stone** | Slate, kaum heller als der Fels | Dirtstone, Kohle, Obsidian, Hollow Bone |
| **void** | dunkler Körper, falsches Licht | Nullstone, Voidglass |

Dazu: ab **Rare** steht der Name über dem Knoten, ab **Epic** schießt eine
Lichtsäule den Schacht hoch. Man steht auf einer Schiene, sieht zweihundert
Studs weiter unten etwas grün leuchten, und trifft eine Entscheidung.

### Wo das Glück hin ist

Ein Knoten, den zwei Spieler sehen, kann nicht auf das Glück von einem
gewürfelt werden. Also würfelt er bei luck 1 — und **Luck wurde ein zweiter
Wurf beim Schlag**:

1. Der Knoten ist, was du siehst.
2. Mit Wahrscheinlichkeit `1 - 1/luck` würfelst du zusätzlich aus der
   glücksgewichteten Tabelle.
3. Du behältst das Seltenere von beidem.

Damit kann Glück nur **nach oben** wirken: Der sichtbare Stein ist eine
Untergrenze, und die Wand lügt nie. Der Simulator prüft genau das über 40
Schläge (`you never get less than the wall promised`).

Der Nebeneffekt ist der eigentliche Gewinn. Vorher war Luck eine unsichtbare
Kurve, die eine Tabelle bog, die niemand zu sehen bekam. Jetzt ist es ein
Ereignis: **⚡ LUCK BEAT THE VEIN**, Gold wird zu etwas Besserem, mit
Bildschirmblitz und Schockwelle. `Rarity.odds` rechnet die Gesamtverteilung
aus beiden Schritten **exakt** aus — die Quote auf der Karte ist die echte.

---

## 10g. Rang: die Zahl, die nie fällt

Cash gibt man aus. Tiefe endet mit jedem Run. Rebirth löscht die Upgrades.
Keine dieser Zahlen beantwortet „wie gut bin ich", und das ist die Frage, die
ein Spieler nach der dritten Sitzung stellt — und die ihn an Tag vier
zurückholt.

Der Rang beantwortet sie aus den **Lebenszeit-Einzahlungen**: die einzige
Zahl im Spiel, die nicht fällt. Nicht bei Tod, nicht bei Diebstahl, nicht bei
Rebirth.

| Rang | ab | Rang | ab |
|---|---|---|---|
| ◆ Dust | 0 | ❖ Emerald | 3M |
| ◆ Copper | 5K | ❖ Diamond | 15M |
| ◆ Iron | 25K | ✦ Obsidian | 80M |
| ◈ Silver | 120K | ✦ Abyssal | 450M |
| ◈ Gold | 600K | ✹ Singularity | 3B |

Zehn Stufen, grob Faktor 5–6 auseinander: Kupfer nach etwa **4 Minuten**, die
Spitze jenseits von 410M — dem, was *sämtliche* Upgrades zusammen kosten. Eine
Leiter mit zwanzig Sprossen ist ein Fortschrittsbalken, und niemand macht
einen Screenshot von einem Fortschrittsbalken.

Der Rang steht an vier Stellen: über dem Kopf, im HUD mit Fortschrittsbalken,
in der Roblox-Spielerliste (Tab) und auf dem Board an der Oberfläche.

**Kein Rang gibt einen Vorteil.** Kein Cash, keine Luck, kein Tempo, keine
Kapazität. Der Balance-Check erzwingt es, indem er jeden Rangeintrag auf
erlaubte Felder prüft. Sobald ein Rang etwas auszahlt, ist Zurückliegen nicht
mehr etwas, das man aufholen will, sondern etwas, das man ungerecht findet.

### Zwei Boards, und warum das zweite wichtiger ist

An der Oberfläche stehen jetzt zwei Wände. Links **DEEPEST DIVES** — global,
für immer, per OrderedDataStore. Rechts **THIS SERVER · TODAY** — was jeder,
der gerade hier ist, seit Serverstart eingezahlt hat.

Das zweite ist das, was Spieler tatsächlich jagen. Auf dem globalen Board
steht an einem Dienstagabend niemand aus diesem Server und wird auch nie
jemand stehen. Auf dem lokalen steht die Person, die zwei Schienen unter dir
gräbt, und sie ist in zwanzig Minuten einholbar.

---

## 11. Ökonomie in Zahlen

Aus `tools/balance-check.py`, nicht geschätzt:

```
Oberflächen-Einkommen         ≈ 21 / Sekunde
Erstes Drill-Upgrade          120 Cash    ≈ 6 Sekunden
Erstes Rebirth                800.000     ≈ 22 Minuten
Drill max (Lv 50)             ≈ 9,8M
Cargo Hold max (Lv 50)        ≈ 77M
Tiefenmultiplikator 0 → 2900m  1,0 → 15,4
```

Die Form ist Absicht: **das erste Upgrade in Sekunden, das erste Rebirth in
einer halben Stunde.** Die frühe Kurve muss fast peinlich großzügig sein, weil
sie gegen den Zurück-Knopf antritt; die späte muss steil sein, weil sie gegen
Langeweile antritt.

Der Balance-Check erzwingt außerdem Zusagen, die man beim Tunen leicht bricht:
tiefer graben lohnt sich **immer** (monoton über acht Stichtiefen), Luck erhöht
seltene Quoten **streng monoton**, jede Tiefe hat abbaubares Erz, und Rebirth
bleibt im Fenster von 15–90 Minuten.

---

## 12. Monetarisierung

Eine Regel, an die wir uns halten: **Passes verkaufen Tempo und Komfort, nie
exklusive Inhalte und nie Schutz vor Spieleraktionen.**

Konkret heißt das: Der Express-Lift verkauft 4 Sekunden Wartezeit — nicht
Zugang zu einer Schicht. Es gibt bewusst *keinen* Pass, der vor Snatches
schützt; Schutz gibt es nur über das erspielbare Safe Pocket. Ein Spiel, in
dem man sich aus der sozialen Mechanik herauskaufen kann, hat keine soziale
Mechanik mehr, sondern eine Steuer.

Der Receipt-Handler ist idempotent (Roblox liefert Quittungen erneut aus) und
gibt bei Fehlern `NotProcessedYet` zurück statt zu schlucken — das ist die
einzige Funktion im Spiel, in der ein Bug echtes Geld kostet.

**Daily Deals** kamen aus einem Ranking-Detail: Roblox zählt **Ausgabetage**
getrennt von der Ausgabenhöhe. Fünf kleine Käufe an fünf Tagen sind für die
Empfehlung mehr wert als ein großer an einem — und für den Geldbeutel eines
Dreizehnjährigen ohnehin freundlicher. Sechs Produkte zu 25–49 R$, täglich
eines im Shop, deterministisch nach UTC-Datum, damit sichtbar ist, dass es eine
Rotation ist und kein gezielter Preis.

**Rewarded Video** ist bewusst die Gegenform zu dem, was Roblox im August 2026
verboten hat: ein einzelner freiwilliger Knopf mit einer Stunde Abklingzeit —
kein Feed, kein Autoplay, keine Belohnung, die vom Weiterschauen abhängt.

---

## 13. Was bewusst fehlt

Genauso wichtig wie das, was drin ist:

- **Kein Handel.** Handel bringt Scams, Bots und Support-Aufwand mit sich, und
  das lohnt sich erst bei einer Spielerbasis, die man erst haben muss.
- **Kein Kampf zwischen Spielern.** Der Snatch ersetzt ihn: gleiche Dramatik,
  kein Waffen-Balancing, keine Moderationslast.
- **Keine zerstörbare Voxel-Welt.** Sieht in einem Trailer besser aus, kostet
  aber Server-Performance und Netzwerk-Bandbreite, die direkt vom
  Spielerlimit abgehen. Vorsprünge mit Erz-Nodes geben denselben Rhythmus.
- **Keine Skins/Cosmetics-Ökonomie.** Später ein starker zweiter Umsatzkanal,
  aber ohne Spieler ist ein Shop nur ein leerer Raum.

---

## 14. Wenn es zieht: der Erweiterungspfad

In dieser Reihenfolge, jeweils erst wenn die Metriken es rechtfertigen:

1. **Tiefen-Rekord-Rennen** (wöchentliches Leaderboard mit Reset) — nutzt alles,
   was schon da ist, und gibt dem Spiel einen Puls.
2. **Gilden/Crews** — geteilte Tiefenrekorde, gemeinsamer Tresor.
3. **Kistenschlüssel & Cosmetics** — der zweite Umsatzkanal.
4. **Zweiter Schacht mit eigener Physik** (Wasser, Vakuum) — echte
   Content-Erweiterung, nicht nur größere Zahlen.
5. **Handel** — zuletzt, mit Moderation, oder gar nicht.
