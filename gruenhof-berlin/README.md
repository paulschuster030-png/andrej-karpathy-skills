# Grünhof Berlin — Website

Statische, funktionsfähige Website für den Hausmeister- & Gartenservice
Grünhof Berlin (Inh. Paul Schuster). Reines HTML/CSS/JS, kein Build-Schritt.

## Lokal starten

```bash
cd gruenhof-berlin
python3 -m http.server 8000
# dann im Browser: http://localhost:8000
```

Oder die `index.html` direkt im Browser öffnen.

## Was echt funktioniert

- Navigation inkl. mobilem Menü (Hamburger-Button)
- Warenkorb: Produkte hinzufügen, Menge ändern, entfernen, Bundle "Alle in den
  Warenkorb", Gesamtsumme, bleibt über `localStorage` auch nach Neuladen erhalten
- Vorher/Nachher-Regler: per Maus/Touch ziehbar, auch per Pfeiltasten bedienbar
- Kontakt-/Angebotsformular (`#kontakt`) mit echter Validierung; ein Warenkorb-
  Checkout landet als vorausgefüllte Anfrage im selben Formular
- Alle "Angebot anfragen"/"Anrufen"-Buttons sind echte Anker- bzw. `tel:`-Links

## Bekannte Grenzen (bewusst nicht gebaut, siehe Absprache)

- **Kein Bezahlsystem.** Der Warenkorb endet in einer Bestellanfrage per
  E-Mail, nicht in einem echten Checkout/Zahlungsanbieter.
- **Kontaktformular nutzt `mailto:`.** Ohne eigenen Server/Formular-Backend
  öffnet das Absenden das E-Mail-Programm des Besuchers mit vorausgefüllter
  Nachricht an `hallo@gruenhof-berlin.de`; zusätzlich wird der Text zum
  Kopieren angezeigt, falls kein Mail-Programm konfiguriert ist. Für eine
  zuverlässigere Zustellung später z. B. Netlify Forms, Formspree oder ein
  eigenes Backend anbinden.
- **Kontaktdaten sind Platzhalter**, aus dem Entwurf übernommen (Telefon
  `+49 30 000000`, Adresse „Musterstraße 12“) — vor dem Livegang durch echte
  Daten ersetzen.
- **Impressum/Datenschutz/AGB/Widerruf fehlen inhaltlich** (nur als Text im
  Footer gelistet, ohne Seiten) — für ein deutsches Gewerbe rechtlich
  Pflicht vor Veröffentlichung.
- **"Alle Produkte"**, **"Meine ganze Geschichte"** u. ä. verweisen auf keine
  weiteren Unterseiten, da deren Inhalte nicht existieren.
