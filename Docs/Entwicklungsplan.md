# Wetterpilot 3.0 – Produkt- und Entwicklungsplan

Status: Produktentscheidungen bestätigt, Eingabe-Prototyp noch zu validieren  
Stand: 13. Juli 2026

## 1. Produktidee

Wetterpilot 3.0 ist kein Starttermin-Optimierer mehr, sondern ein Wetterbegleiter für mehrtägige Reisen mit wechselnden Orten.

Der Hauptnutzen lautet:

> Eine Reise einmal einfach eingeben und danach alle Reisetage, Orte und das jeweils relevante Wetter auf einen Blick sehen.

Typische Reisen:

- Kreuzfahrt: Barcelona → Ibiza → Palermo → Rom
- Rundreise: Bangkok → Chiang Mai → Krabi → Phuket
- Roadtrip mit täglich wechselnden oder wiederholten Orten
- Städtereise mit täglich wechselnden oder wiederholten festen Orten

Die Suche nach dem besten Startdatum bleibt ein optionales Werkzeug. Sie bestimmt nicht mehr den Hauptablauf und wird erst nach dem MVP ergänzt.

## 2. Produktprinzipien

1. **Reise zuerst:** Der Nutzer arbeitet mit einer benannten Reise, nicht mit einer abstrakten Analyse.
2. **Ein Tag, ein Blick:** Datum, Ort, Wetterlage, Temperatur, Regen und Wind müssen direkt erfassbar sein.
3. **Einfache Eingabe:** Möglichst wenige Pflichtfelder; wiederkehrende Orte und mehrere Tage an einem Ort dürfen keine Mehrarbeit verursachen.
4. **Ehrliche Wetterdaten:** Vorhersage, noch nicht verfügbare Tage und vergangene Tage werden klar unterschieden.
5. **Optionale Tiefe:** Detailwerte, Präferenzen und Starttermin-Vergleich sind erreichbar, aber nicht im Weg.
6. **Offline-freundlich:** Die zuletzt geladenen Reisedaten bleiben sichtbar und werden mit Aktualisierungszeitpunkt gekennzeichnet.

## 3. Vorgeschlagener Hauptablauf

### 3.1 Startseite „Meine Reisen“

- Liste gespeicherter Reisen
- Pro Reise: Name, Zeitraum, nächste Station und kompakter Wetterhinweis
- Primäre Aktion: „Neue Reise“
- Optional später: Reise duplizieren, archivieren, teilen und löschen

### 3.2 Neue Reise anlegen

Minimaler Ablauf:

1. Reisename, optional mit automatisch erzeugtem Vorschlag
2. Startdatum
3. Reisetage/Stationen hinzufügen
4. Speichern und Wetter anzeigen

Vorgeschlagene Eingabe pro Abschnitt:

- Ort über Autovervollständigung auswählen
- Ankunfts- und Abreisedatum oder Anzahl der Nächte/Tage festlegen
- App erzeugt daraus automatisch die einzelnen Tageszeilen
- Weitere Station mit „+ Ort hinzufügen“

Damit muss ein Nutzer bei vier Tagen in Bangkok den Ort nicht viermal eingeben. In der Tagesübersicht bleibt intern trotzdem jeder Kalendertag eindeutig einem Reiseabschnitt zugeordnet.

### 3.3 Reiseübersicht

Die wichtigste Ansicht der App:

- Kopfbereich mit Reisename, Zeitraum und letztem Datenupdate
- Vertikale Timeline oder kompakte Tageskarten
- Jede Tageskarte zeigt mindestens:
  - Wochentag und Datum
  - Ort des Reisetags
  - Wetterzustand
  - Tiefst-/Höchsttemperatur
  - Regenwahrscheinlichkeit und/oder Niederschlagsmenge
  - Wind, besonders relevant für Kreuzfahrten
- Auffällige Bedingungen als verständliche Hinweise, zum Beispiel „Gewitter möglich“ oder „Starker Wind“
- Tippen auf einen Tag öffnet die Detailansicht

### 3.4 Tagesdetail

- Tagesverlauf, sofern die Datenquelle ihn liefert
- Gefühlt-Temperatur beziehungsweise Temperaturverlauf
- Regenwahrscheinlichkeit und -menge
- Wind und Böen
- Sonnenauf- und -untergang
- UV-Index optional
- Hinweis auf Datenstand und Prognosesicherheit

### 3.5 Reise bearbeiten

- Station verschieben
- Aufenthaltsdauer ändern
- Station austauschen oder löschen
- jedem Reisetag einen festen Ort zuordnen
- Änderungen lösen nur die nötigen Wetterabfragen neu aus

## 4. Informationsarchitektur

Empfohlene Hauptnavigation:

- **Reisen:** gespeicherte und kommende Reisen
- **Einstellungen:** Einheiten, Sprache, Hinweise und Datenschutz

Innerhalb einer Reise:

- Übersicht
- Bearbeiten
- Optional später: Startdatum vergleichen

Eine zusätzliche globale Wetter- oder Karten-Registerkarte ist für das MVP nicht nötig.

## 5. Fachliches Datenmodell

### Trip

- `id`
- `name`
- `startDate`
- `endDate` (aus Abschnitten ableitbar)
- `segments`
- `createdAt`, `updatedAt`
- optionale Nutzerpräferenzen

### TripSegment

- `id`
- `startDate`
- `endDate`
- `place`
- `title` optional, zum Beispiel für einen selbst gewählten Stationsnamen
- `notes` optional (nicht zwingend im MVP)
- `sortOrder`

### Place

- stabiler lokaler Bezeichner
- Anzeigename
- Region und Land
- Breiten-/Längengrad
- Zeitzone
- externer Provider-Bezeichner, sofern vorhanden

### TripDay

Eine aus den Reiseabschnitten erzeugte Lesedarstellung:

- `date`
- `segmentID`
- `place` optional
- `dayNumber`
- `forecastState`

`TripDay` sollte nicht zusätzlich persistent gespeichert werden, solange er zuverlässig aus `TripSegment` erzeugt werden kann.

### WeatherSnapshot

- Ort und lokales Datum
- Wettercode und Beschreibung
- Temperatur min/max
- Regenwahrscheinlichkeit
- Niederschlagsmenge
- Wind und Böen
- Sonnenstunden oder Bewölkung
- optional UV, Sonnenaufgang und Sonnenuntergang
- Abrufzeitpunkt und Datenquelle

### ForecastState

- `available`: belastbare Vorhersage vorhanden
- `outsideForecastRange`: Reisetag liegt noch außerhalb des Vorhersagefensters
- `loading`
- `stale`: nur ältere Cache-Daten vorhanden
- `failed`
- optional später `historicalClimate`: Klimaorientierung statt Vorhersage

## 6. Technische Architektur

Empfehlung: SwiftUI mit feature-orientierter Struktur und klarer Trennung von Domain, Datenzugriff und Darstellung. Keine Übernahme des großen `RouteVM` aus Version 2.

- SwiftUI und Swift Concurrency
- Observation (`@Observable`) bei passendem Mindest-iOS, sonst `ObservableObject`
- SwiftData für mehrere Reisen und bearbeitbare Abschnitte; alternativ Core Data, falls ein niedrigeres Plattformziel nötig ist
- Repository-Protokolle zwischen Domain und Provider-Implementierung
- Dependency Injection über einen kleinen App-Container
- Datumslogik immer kalender- und zeitzonenbewusst
- Wetterabfragen pro eindeutigem Ort bündeln; nicht einmal pro sichtbarer Tageszeile laden
- Tests mit austauschbarer Uhr (`Clock`/`DateProvider`) und Mock-Repositories

## 7. Vollständig neue Ordnerstruktur

Wetterpilot 3.0 sollte als separates Xcode-Projekt in einem eigenen Repository- oder Projektordner entstehen. Der Version-2-Quellordner wird nicht kopiert.

```text
Wetterpilot_3_0/
├── README.md
├── Docs/
│   ├── ProductVision.md
│   ├── Architecture.md
│   └── Decisions/
├── Wetterpilot.xcodeproj/
├── Wetterpilot/
│   ├── App/
│   │   ├── WetterpilotApp.swift
│   │   ├── AppContainer.swift
│   │   └── AppRouter.swift
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Trip.swift
│   │   │   ├── TripSegment.swift
│   │   │   ├── Place.swift
│   │   │   └── WeatherSnapshot.swift
│   │   ├── Repositories/
│   │   │   ├── TripRepository.swift
│   │   │   ├── PlaceRepository.swift
│   │   │   └── WeatherRepository.swift
│   │   └── UseCases/
│   │       ├── BuildTripTimeline.swift
│   │       ├── LoadTripWeather.swift
│   │       └── ValidateTrip.swift
│   ├── Features/
│   │   ├── TripList/
│   │   │   ├── TripListView.swift
│   │   │   └── TripListModel.swift
│   │   ├── TripEditor/
│   │   │   ├── TripEditorView.swift
│   │   │   ├── TripEditorModel.swift
│   │   │   └── Components/
│   │   ├── TripOverview/
│   │   │   ├── TripOverviewView.swift
│   │   │   ├── TripOverviewModel.swift
│   │   │   └── Components/
│   │   ├── DayDetail/
│   │   │   ├── DayDetailView.swift
│   │   │   └── DayDetailModel.swift
│   │   ├── StartDateComparison/
│   │   └── Settings/
│   ├── Data/
│   │   ├── Persistence/
│   │   │   ├── SwiftDataTripRepository.swift
│   │   │   └── PersistenceModels/
│   │   ├── Weather/
│   │   │   ├── OpenMeteoWeatherService.swift
│   │   │   ├── OpenMeteoDTOs.swift
│   │   │   └── WeatherCache.swift
│   │   ├── Geocoding/
│   │   │   ├── OpenMeteoGeocodingService.swift
│   │   │   └── GeocodingDTOs.swift
│   │   └── Networking/
│   │       ├── HTTPClient.swift
│   │       └── APIError.swift
│   ├── DesignSystem/
│   │   ├── Theme/
│   │   ├── Components/
│   │   └── WeatherSymbols/
│   ├── Shared/
│   │   ├── Extensions/
│   │   ├── Formatting/
│   │   └── Localization/
│   └── Resources/
│       ├── Assets.xcassets/
│       ├── Localizable.xcstrings
│       └── PrivacyInfo.xcprivacy
├── WetterpilotTests/
│   ├── Domain/
│   ├── Features/
│   └── Data/
└── WetterpilotUITests/
```

Die Ordner spiegeln Verantwortlichkeiten wider. Feature-Code liegt zusammen; Provider-Details gelangen nicht in Views oder Domain-Modelle.

## 8. Umgang mit Version 2

### Konzeptuell wiederverwendbar

- Open-Meteo als Wetterdatenquelle
- Open-Meteo-Geocoding
- Netzwerk-Grundideen und Cache-Konzept
- Wettercode-Zuordnung
- deutsche und englische Lokalisierung als Ausgangsmaterial
- Exportidee, falls Teilen später wieder gewünscht ist

### Bewusst neu entwickeln

- Navigation und sämtliche Hauptansichten
- Datenmodell und Persistenz
- Reiseeingabe
- Tages-Timeline
- Zustands- und Fehlerdarstellung
- View Models beziehungsweise Feature Models
- Datums- und Zeitzonenlogik
- Tests
- Designsystem und visuelle Identität

### Nicht Teil des MVP

- bisherige Liste möglicher Startdaten
- offener Wetterscore als primäre Anzeige
- globale Gewichtung „Regen/Wind/Hitze/Kälte vermeiden“
- PDF-Export

## 9. MVP-Umfang

Das erste veröffentlichbare Inkrement umfasst:

- mehrere Reisen lokal anlegen, bearbeiten und löschen
- Reisename und Reiseabschnitte mit Datum und Ort
- Ortsvorschläge mit eindeutiger Auswahl
- automatisch erzeugte Tages-Timeline
- Tagesvorhersage je Ort und Datum
- klare Darstellung für Tage außerhalb des Vorhersagefensters
- manuelles Aktualisieren und Cache-Anzeige
- Tagesdetail
- Deutsch und Englisch
- Dark Mode, Dynamic Type und grundlegende VoiceOver-Unterstützung
- Unit Tests für Timeline, Validierung, Zeitzonen und Wetter-Zuordnung

## 10. Spätere Ausbaustufen

### Phase 2

- Startdatum vergleichen als optionaler Modus
- Reise duplizieren
- Kartenansicht
- Wetterwarnungen
- Teilen als Bild, Link oder PDF
- Widgets für die nächste Station
- Import aus Kalender oder strukturierter Reiseliste

### Phase 3

- Klima-/Historikwerte für Reisen außerhalb des Vorhersagefensters
- Benachrichtigungen bei relevanten Wetteränderungen
- CloudKit-Synchronisierung
- gemeinsame Reisen
- spezielle Kreuzfahrtwerte wie Wellenhöhe, sofern eine geeignete Datenquelle eingebunden wird

## 11. Startdatum-Vergleich als optionales Feature

Der Vergleich wird aus einer bestehenden Reise heraus gestartet:

1. Nutzer legt einen Verschiebebereich fest, zum Beispiel ±3 Tage.
2. Die App verschiebt alle Reiseabschnitte gemeinsam.
3. Nur Varianten innerhalb verfügbarer Prognosedaten werden verglichen.
4. Ergebnis ist eine verständliche Rangfolge mit Begründung, nicht nur ein abstrakter Score.

Beispiel: „Zwei Tage später: weniger Regen an 3 von 7 Reisetagen, dafür mehr Wind in Palermo.“

So bleibt das Feature nützlich, ohne die Hauptansicht und die Erstanlage zu belasten.

## 12. Umsetzungsetappen

### Etappe 0 – Produktentscheidungen und Wireframes

- offene Fragen aus Abschnitt 14 entscheiden
- drei Kernansichten als Wireframe: Reiseliste, Reiseeditor, Reiseübersicht
- Eingabe-Prototyp für Aufenthalte mit Von-/Bis-Datum festlegen
- Akzeptanzkriterien des MVP bestätigen

Ergebnis: abgestimmter klickbarer oder statischer Ablauf.

### Etappe 1 – Technisches Fundament

- neues Projekt und neue Ordnerstruktur anlegen
- App-Container, Navigation und Design-Tokens
- Domain-Modelle, Repository-Protokolle und SwiftData-Persistenz
- Test-Targets und Mock-Implementierungen

Ergebnis: leere Reisen können angelegt, gespeichert und wieder geöffnet werden.

### Etappe 2 – Reiseeditor

- Abschnittseingabe mit Ortsautovervollständigung
- Datums- und Überschneidungsvalidierung
- Aufenthalte komfortabel verlängern und umsortieren
- Timeline aus Abschnitten erzeugen

Ergebnis: Kreuzfahrt und Thailand-Rundreise lassen sich ohne Wetter vollständig erfassen.

### Etappe 3 – Wetterdaten

- neue Open-Meteo-DTOs und Repository-Implementierung
- tägliche Werte plus benötigte Zusatzfelder
- gruppierte parallele Abfragen je Ort
- Cache, Datenalter und Teilfehler
- Zustände außerhalb des Prognosefensters

Ergebnis: jeder unterstützte Reisetag erhält die korrekten lokalen Wetterdaten.

### Etappe 4 – Reiseübersicht und Tagesdetail

- Tageskarten/Timeline
- Warnhinweise und verständliche leere Zustände
- Tagesdetail
- Aktualisieren, Offline-Verhalten und Fehlerbehandlung

Ergebnis: der Hauptnutzen „alle Orte und Tage auf einen Blick“ ist vollständig.

### Etappe 5 – Qualität und Veröffentlichung

- Lokalisierung Deutsch/Englisch
- Accessibility und verschiedene Displaygrößen
- Unit-, UI- und Integrationsprüfungen
- Datenschutzangaben, App-Store-Texte und Screenshots
- Migration ausdrücklich nur dann, wenn sie einen echten Nutzwert hat

Ergebnis: MVP ist TestFlight-fähig.

### Etappe 6 – Optionaler Startdatum-Vergleich

- Varianten-Generator
- erklärbares Bewertungsmodell
- Ergebnisvergleich und Grenzen des Vorhersagefensters
- Tests gegen Datums- und Zeitzonenfehler

## 13. Qualitäts- und Akzeptanzkriterien

- Eine Reise Barcelona → Ibiza → Palermo → Rom kann in wenigen Schritten angelegt werden.
- Mehrere Tage am selben Ort benötigen nur eine Ortseingabe.
- Jeder Reisetag zeigt genau die Wetterdaten für das lokale Datum des jeweiligen Orts.
- Reiseabschnitte dürfen sich nicht unbemerkt überschneiden oder Lücken erzeugen.
- Ein Ausfall für einen Ort macht nicht die gesamte Reise unbrauchbar.
- Außerhalb des Prognosefensters wird keine scheinpräzise Vorhersage angezeigt.
- Die zuletzt erfolgreichen Daten bleiben bei Netzfehlern sichtbar und als älter markiert.
- Große Schrift und VoiceOver machen die Kerninformationen weiterhin verständlich.
- Domain- und Feature-Tests funktionieren ohne echte Netzwerkzugriffe.

## 14. Offene Produktentscheidungen

Folgende Entscheidungen wurden am 13. Juli 2026 bestätigt:

1. **Mehrere Reisen:** Die App verwaltet mehrere gespeicherte Reisen.
2. **Reisezeitraum:** Reisen dürfen weit im Voraus angelegt werden. Wetterdaten erscheinen automatisch, sobald sie verfügbar sind. Davor zeigt die App einen klaren Status ohne erfundene Prognosewerte.
3. **Eingabemodell:** Noch nicht endgültig entschieden. Der erste Prototyp verwendet Reiseabschnitte mit Ort und Von-/Bis-Datum und erzeugt daraus automatisch die Tageszeilen. Die Bedienbarkeit wird anschließend praktisch bewertet.
4. **Reisetage ohne Ort:** Seetage, Fahrtage und Marine-Wetter sind nicht Bestandteil der App. Jeder berücksichtigte Reisetag besitzt einen festen Ort.
5. **Plattform:** Wetterpilot 3.0 wird zunächst primär für das iPhone entwickelt.
6. **Daten und Konto:** Lokale Speicherung reicht für die erste Version. iCloud, Konten und gemeinsames Bearbeiten gehören nicht zum MVP.
7. **Projektablage:** Wetterpilot 3.0 entsteht als eigenständiger Nachbarordner `Wetterpilot_3_0` und nicht innerhalb der Version-2-Quellen.

Noch festzulegen:

- Mindest-iOS-Version
- reine Timeline oder zusätzliche Karte im MVP; Empfehlung bleibt Timeline ohne Karte
- konkrete Interaktion des Reiseeditors nach Bewertung des ersten Prototyps

## 15. Empfohlene Entscheidungen für ein schlankes MVP

Falls keine abweichenden Anforderungen bestehen:

- mehrere lokale Reisen
- Reisen beliebig weit im Voraus planbar, mit ehrlichem Status „Vorhersage noch nicht verfügbar“
- abschnittsbasierter Eingabe-Prototyp mit automatisch erzeugten Reisetagen
- ausschließlich Reisetage mit festem Ort; keine See- oder Fahrtage
- iPhone zuerst, iPad-Layout später
- Timeline als Hauptansicht, Karte später
- lokales SwiftData ohne Konto oder Cloud-Synchronisierung
- Startdatum-Vergleich nach dem stabilen MVP

## 16. Phase 2 – Vergleich alternativer Reiseorte

Phase 2 ergänzt einen eigenständigen Ortsvergleich für einen gemeinsamen
Von-/Bis-Zeitraum. Ein Vergleich enthält zwei bis sechs Kandidaten. Für alle
Kennzahlen werden ausschließlich Kalendertage berücksichtigt, für die bei
jedem Kandidaten eine Prognose vorliegt. Damit werden keine unterschiedlich
langen oder unvollständigen Datenreihen gegeneinander gestellt.

Die Übersicht zeigt je Kandidat die Anzahl gemeinsamer Tage, voraussichtlich
trockene Tage, Niederschlagssumme, höchste Regenwahrscheinlichkeit,
Temperaturbereich, Wind, Böen und Wetterhinweise. Regelbasierte Tendenzen
benennen konkrete Unterschiede bei trockenen Tagen, Niederschlag oder Wind.
Es gibt keinen Gesamtscore und bei unzureichender gemeinsamer Datenbasis keine
Rangfolge.

Ein Tag gilt als **voraussichtlich trocken**, wenn seine prognostizierte
Regenwahrscheinlichkeit unter 50 Prozent liegt und die Niederschlagsmenge
zugleich unter 1,0 mm bleibt. Fehlt die Regenwahrscheinlichkeit, zählt der Tag
nicht als trocken. Diese Definition ist zentral in der Vergleichslogik
hinterlegt und durch Unit-Tests abgesichert.

Vergleiche verwenden denselben persistenten Wettercache und Offline-Fallback
wie Reisen. Prognosen außerhalb des Open-Meteo-Fensters bleiben ausdrücklich
nicht verfügbar. Ein Kandidat kann ohne Modell-Sonderweg in eine normale Reise
mit einem Aufenthalt für den vollständigen Vergleichszeitraum umgewandelt
werden.

## 17. Phase 3 – Flexible Starttage normaler Reisen

Flexible Starttage sind eine optionale Eigenschaft einer normalen Reise.
Neben dem exakten Originalzeitraum kann eine Reise um ±1 oder ±2 Kalendertage
verschoben dargestellt werden. Persistiert wird nur die gewählte
Flexibilität; Varianten und verschobene Aufenthalte bleiben vollständig
abgeleitet. Bestehende Reisen verwenden ohne Nutzereingriff den exakten
Start.

Die gesamte Reise wird für jede Variante um denselben Offset verschoben.
Aufenthaltsdauern, Reihenfolge und gemeinsame Transferdaten bleiben erhalten.
Die Verschiebung verwendet Kalenderoperationen statt fester
Sekundenintervalle und funktioniert dadurch auch über Monats-, Jahres- und
Sommerzeitgrenzen.

Die Bewertung berücksichtigt ausschließlich aktivierte globale
Wetterpräferenzen:

- Gewitter vermeiden
- Regenwahrscheinlichkeit höchstens 70 Prozent
- Niederschlagsmenge höchstens 10 mm
- Wind höchstens 40 km/h
- Böen höchstens 60 km/h
- Mindesttemperatur 5 °C
- Höchsttemperatur 32 °C

Diese Standardwerte können in der Reiseübersicht geändert oder
zurückgesetzt werden. Intern vergleicht die App zuerst die Anzahl der
Grenzwertverletzungen, danach die Anzahl betroffener Reisetage und zuletzt
die relative Überschreitung. In der Oberfläche wird keine Punktzahl gezeigt,
sondern eine konkrete Begründung mit Datum, Ort und Wetterwert.

Eine endgültige Empfehlung ist nur möglich, wenn sämtliche Varianten für
alle Reisetage vollständig und mit denselben aktivierten Datenarten
bewertbar sind. Bei fehlender fairer Datenbasis oder praktisch gleichen
Ergebnissen bleibt die Originalvariante vorausgewählt und die App formuliert
keinen künstlichen Gewinner. Wetter wird weiterhin einmal pro eindeutigem
Ort geladen; alle Startvarianten werden lokal aus Cache und Vorhersagetagen
gebildet.
