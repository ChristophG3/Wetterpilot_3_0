import Foundation
import SwiftUI
import Combine

@MainActor
final class RouteVM: ObservableObject {
    // MARK: - Publizierte Zustände (UI)
    @Published var startDate: Date
    @Published var durationDays: Int
    @Published var stops: [StopSpec]                 // pro Tag: place + optional selected GeoPlace
    @Published var weights: Weights                  // neue Bool-Preferences
    @Published var hasSeenWelcome: Bool

    // Analyse-Ergebnisse
    @Published var summary: [SummaryItem] = []
    @Published var detailsByDate: [String: [DetailItem]] = [:]
    @Published var errorKey: String?

    // Autovervollständigung: pro Index eine optionale Trefferliste
    @Published var suggestions: [Int: [GeoPlace]?] = [:]
    private var suggestTasks: [Int: Task<Void, Never>] = [:]

    // MARK: - Dependencies
    let deps: AppDependencies

    // Vorhersagehorizont & Puffer
    private let horizonDays = 16
    private let minLeadDaysBeforeStart = 2   // mind. 2 Tage „Vorlauf“ bis zum Start

    // MARK: - Init
    init(deps: AppDependencies) {
        self.deps = deps

        let start = deps.store.startDate ?? Date()
        let persistedDuration = max(1, min(horizonDays, deps.store.durationDays))
        let persistedPlaces = deps.store.places
        let initialWeights = deps.store.weights
        let seenWelcome = deps.store.hasSeenWelcome

        // Stops aus Persistenz (auf Länge der Dauer bringen)
        var initialStops: [StopSpec]
        if persistedPlaces.isEmpty {
            initialStops = Array(repeating: StopSpec(place: "", selected: nil), count: persistedDuration)
        } else {
            var arr = persistedPlaces.prefix(persistedDuration).map { StopSpec(place: $0, selected: nil) }
            if arr.count < persistedDuration {
                arr += Array(repeating: StopSpec(place: "", selected: nil),
                             count: persistedDuration - arr.count)
            }
            initialStops = Array(arr)
        }

        self.startDate = start
        self.durationDays = persistedDuration
        self.stops = initialStops
        self.weights = initialWeights
        self.hasSeenWelcome = seenWelcome
    }

    // MARK: - Welcome / Reset
    func setHasSeenWelcome() {
        hasSeenWelcome = true
        deps.store.hasSeenWelcome = true
    }

    /// Voll-Reset gemäß Spezifikation
    func resetAll() {
        // laufende Suggest-Tasks beenden
        suggestTasks.values.forEach { $0.cancel() }
        suggestTasks.removeAll()
        suggestions.removeAll()

        // Persistenz zurücksetzen
        deps.store.resetAll()

        // State zurücksetzen
        startDate = Date()
        durationDays = 1
        stops = Array(repeating: StopSpec(place: "", selected: nil), count: durationDays)
        weights = Weights()
        summary = []
        detailsByDate = [:]
        errorKey = nil
    }

    // MARK: - Dauer / Stops
    func updateDuration(_ newVal: Int) {
        let clamped = max(1, min(horizonDays, newVal))
        let oldCount = stops.count
        durationDays = clamped

        if oldCount < durationDays {
            stops += Array(repeating: StopSpec(place: "", selected: nil), count: durationDays - oldCount)
        } else if oldCount > durationDays {
            // zuerst Aufräumen, dann kürzen (verhindert Race mit Tasks/Dictionary)
            let removedRange = durationDays..<oldCount
            for i in removedRange {
                suggestTasks[i]?.cancel()
                suggestTasks[i] = nil
                suggestions[i] = nil
            }
            stops = Array(stops.prefix(durationDays))
        }

        deps.store.durationDays = durationDays
        deps.store.places = stops.map { $0.place }

        // startDate an neue Spanne anpassen
        if startDate > maxStart { startDate = maxStart }
        if startDate < minStart { startDate = minStart }
    }

    func updatePlace(_ idx: Int, _ name: String) {
        guard idx >= 0 && idx < stops.count else { return }
        stops[idx].place = name
        stops[idx].selected = nil                   // sobald getippt wird, Auswahl zurücksetzen
        deps.store.places = stops.map { $0.place }
        onTypingSuggest(index: idx, text: name)
    }

    func selectSuggestion(_ idx: Int, _ place: GeoPlace) {
        guard idx >= 0 && idx < stops.count else { return }
        stops[idx].place = displayName(place)       // schöner Anzeigename ins Feld
        stops[idx].selected = place                 // Geometrie merken
        suggestions[idx] = nil
        deps.store.places = stops.map { $0.place }
    }

    // MARK: - Autocomplete (Debounce + Index-Safety)
    func onTypingSuggest(index: Int, text: String) {
        guard index >= 0 && index < stops.count else { return }

        // laufende Abfrage für diesen Index abbrechen
        suggestTasks[index]?.cancel()
        suggestions[index] = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }

        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms Debounce
            guard let self, !Task.isCancelled else { return }
            do {
                let hits = try await self.deps.geocoding.suggest(prefix: trimmed, language: lang, limit: 5)
                await MainActor.run {
                    if index < self.stops.count {
                        // leere Liste -> nil, damit die Box verschwindet
                        self.suggestions[index] = hits.isEmpty ? nil : hits
                    }
                }
            } catch {
                await MainActor.run {
                    if index < self.stops.count { self.suggestions[index] = nil }
                }
            }
        }
        suggestTasks[index] = task
    }

    private func displayName(_ g: GeoPlace) -> String { g.name }

    // MARK: - Datumslogik / Rahmen
    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }
    var minStart: Date { startOfToday }

    /// Spätest möglicher Start: heute + (Horizont - (Dauer + Vorlauf))
    var maxStart: Date {
        let latestOffset = max(0, horizonDays - (durationDays + minLeadDaysBeforeStart))
        return Calendar.current.date(byAdding: .day, value: latestOffset, to: startOfToday) ?? startOfToday
    }

    /// Dynamische Obergrenze für den Dauer-Stepper
    var maxDuration: Int {
        max(1, horizonDays - minLeadDaysBeforeStart)
    }

    /// Letzter Tag, für den Vorhersagen existieren (inkl. heute als Tag 0)
    private var forecastLastDay: Date {
        Calendar.current.date(byAdding: .day, value: horizonDays - 1, to: startOfToday) ?? startOfToday
    }

    // MARK: - Analyse (mit robustem Geocoding-Resolver)
    func analyze() async {
        let s = Calendar.current.startOfDay(for: startDate)

        // Validierungen
        if s < minStart || s > maxStart {
            errorKey = "error_start_out_of_range"; return
        }
        guard stops.filter({ !$0.place.trimmingCharacters(in: .whitespaces).isEmpty }).count == durationDays else {
            errorKey = "error_place_empty_for_day"; return
        }
        if let lastTravelDay = Calendar.current.date(byAdding: .day, value: durationDays - 1, to: s),
           lastTravelDay > forecastLastDay {
            errorKey = "error_horizon_too_short"; return
        }

        // Persistenz
        deps.store.startDate = s
        deps.store.weights = weights

        // Orte robust auflösen
        var geo: [GeoPlace] = []
        do {
            for (i, stop) in stops.prefix(durationDays).enumerated() {
                let g = try await resolveGeo(for: stop, index: i)
                geo.append(g)
            }
        } catch {
            errorKey = "error_geocoding_not_found"; return
        }

        // Forecasts laden
        var forecasts: [[ForecastDay]] = []
        do {
            for g in geo {
                var arr = try await deps.weather.fetchDaily(lat: g.latitude, lon: g.longitude)
                arr = arr.map {
                    ForecastDay(placeID: g.id, dateISO: $0.dateISO, tMin: $0.tMin, tMax: $0.tMax,
                                rainMM: $0.rainMM, sunHours: $0.sunHours,
                                windKmh: $0.windKmh, weatherCode: $0.weatherCode)
                }
                forecasts.append(arr)
            }
        } catch {
            errorKey = "error_network_generic"; return
        }

        // Index: dateISO -> [ForecastDay]
        var byDate: [String: [ForecastDay]] = [:]
        for arr in forecasts {
            for d in arr { byDate[d.dateISO, default: []].append(d) }
        }

        // Kandidaten erzeugen
        var items: [SummaryItem] = []
        var details: [String: [DetailItem]] = [:]

        let df = ISO8601DateFormatter.dateOnly
        var cur = max(s, minStart)
        let end = maxStart
        let cal = Calendar.current

        while cur <= end {
            var daysForScore: [ForecastDay] = []
            var detailItems: [DetailItem] = []
            var rainyCount = 0
            var tempSum = 0.0
            var windSum = 0.0
            var sunSum  = 0.0

            for i in 0..<durationDays {
                guard let d = cal.date(byAdding: .day, value: i, to: cur) else { continue }
                let key = df.string(from: d)
                let placeID = geo[i].id
                if let match = byDate[key]?.first(where: { $0.placeID == placeID }) {
                    daysForScore.append(match)
                    if match.rainMM >= 1 { rainyCount += 1 }
                    tempSum += (match.tMin + match.tMax) / 2.0
                    windSum += match.windKmh
                    sunSum  += match.sunHours

                    detailItems.append(
                        DetailItem(
                            dateISO: key,
                            placeName: geo[i].name,
                            emoji: WeatherEmoji.emoji(for: match.weatherCode),
                            tRange: String(format: "%.0f–%.0f°C", match.tMin, match.tMax),
                            rain: String(format: "%.1f mm", match.rainMM),
                            sun: String(format: "%.1f h", match.sunHours),
                            wind: String(format: "%.0f km/h", match.windKmh)
                        )
                    )
                }
            }

            if daysForScore.count == durationDays {
                // Offene Skala + 0–100 berechnen
                let res = OpenScoring.score(days: daysForScore, weights: weights)

                let avgTemp = tempSum / Double(durationDays)
                let avgWind = windSum / Double(durationDays)

                let item = SummaryItem(
                    key: df.string(from: cur),
                    scoreOpen: res.openScore,        // offene Skala
                    scoreDisplay: res.display100,    // 0–100 Anzeige
                    rainyDays: rainyCount,
                    avgTemp: avgTemp,
                    sunHours: sunSum,
                    avgWind: avgWind
                )
                items.append(item)
                details[item.key] = detailItems
            }

            guard let next = cal.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = next
        }

        if items.isEmpty { errorKey = "error_no_forecast_for_date" }
        summary = items.sorted { $0.key < $1.key }
        detailsByDate = details
    }

    // MARK: - Robuster Orts-Resolver (selected > suggestions > geocode > suggest-Varianten)
    private func resolveGeo(for stop: StopSpec, index: Int) async throws -> GeoPlace {
        // 1) Auswahl aus der UI hat Vorrang
        if let sel = stop.selected { return sel }

        let raw = stop.place.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw GeocodingError.notFound }

        // 2) vorhandene Vorschläge für diesen Index nutzen
        if let hitsOpt = suggestions[index], let hits = hitsOpt, !hits.isEmpty {
            if let exact = hits.first(where: { $0.name.caseInsensitiveCompare(raw) == .orderedSame }) {
                return exact
            }
            return hits[0]
        }

        // 3) direktes Geocoding
        if let g = try? await deps.geocoding.geocode(raw) { return g }

        // 4) suggest-Fallback mit Varianten (Komma/erstes Wort/normalisiert)
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        let firstComma = raw.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstWord  = raw.components(separatedBy: .whitespaces).first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = raw.folding(options: .diacriticInsensitive, locale: .current)
        let candidates = Array([raw, firstComma, firstWord, normalized].compactMap { $0 }.uniqued())

        for q in candidates {
            if let hit = try? await deps.geocoding.suggest(prefix: q, language: lang, limit: 1).first {
                return hit
            }
        }

        throw GeocodingError.notFound
    }
}

// MARK: - Helpers

enum GeocodingError: Error { case notFound }

extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
