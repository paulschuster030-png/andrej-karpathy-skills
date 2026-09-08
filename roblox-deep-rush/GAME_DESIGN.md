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
| **Sammlung** | gibt Identität über den Grind hinaus | Codex (30 Erze) + Drohnen |
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

## 8. Ökonomie in Zahlen

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

## 9. Monetarisierung

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

---

## 10. Was bewusst fehlt

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

## 11. Wenn es zieht: der Erweiterungspfad

In dieser Reihenfolge, jeweils erst wenn die Metriken es rechtfertigen:

1. **Tiefen-Rekord-Rennen** (wöchentliches Leaderboard mit Reset) — nutzt alles,
   was schon da ist, und gibt dem Spiel einen Puls.
2. **Gilden/Crews** — geteilte Tiefenrekorde, gemeinsamer Tresor.
3. **Kistenschlüssel & Cosmetics** — der zweite Umsatzkanal.
4. **Zweiter Schacht mit eigener Physik** (Wasser, Vakuum) — echte
   Content-Erweiterung, nicht nur größere Zahlen.
5. **Handel** — zuletzt, mit Moderation, oder gar nicht.
