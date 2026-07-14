# Wetterpilot 3.0

Wetterpilot 3.0 ist ein iPhone-Wetterbegleiter für Rundreisen mit mehreren festen Orten.

## Aktueller Stand

- mehrere Reisen lokal mit SwiftData speichern
- Aufenthalte mit Ort und Von-/Bis-Datum erfassen
- automatisch eine Tages-Timeline erzeugen
- Reisen öffnen, bearbeiten und löschen
- vollständige, teilweise, veraltete und noch nicht verfügbare Prognosen klar unterscheiden
- tägliche und stündliche Open-Meteo-Prognosen mit Wetterhinweisen anzeigen
- Wetterdaten persistent zwischenspeichern und offline weiter anzeigen
- optional an die Verfügbarkeit einer Reiseprognose erinnern
- Ein-Tages-Ausflüge mit Ort und Datum schnell anlegen
- deutsche und englische Oberfläche sowie °C/°F und km/h/mph
- Dark Mode, Dynamic Type, VoiceOver und SF-Symbol-basierte Wetterdarstellung
- zwei bis sechs alternative Reiseorte für einen gemeinsamen Zeitraum vergleichen
- Vergleichswerte ausschließlich aus den gemeinsam verfügbaren Prognosetagen bilden
- erklärbare Tendenzen zu trockenen Tagen, Niederschlag und Wind ohne Gesamtscore
- einen Vergleichsort direkt als normale Reise übernehmen

Tage außerhalb des 16-Tage-Vorhersagefensters zeigen bewusst keine erfundenen oder historischen Werte. Der vollständige Produktplan liegt unter `Docs/Entwicklungsplan.md`.

Ein Tag gilt im Ortsvergleich als **voraussichtlich trocken**, wenn die
prognostizierte Regenwahrscheinlichkeit unter 50 Prozent liegt und zugleich
weniger als 1,0 mm Niederschlag vorhergesagt werden. Fehlt die
Regenwahrscheinlichkeit, wird der Tag nicht als trocken gezählt.

## Projekt öffnen

`Wetterpilot_3_0.xcodeproj` mit Xcode öffnen und das Scheme `Wetterpilot_3_0` starten.
