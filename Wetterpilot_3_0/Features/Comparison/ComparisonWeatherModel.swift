import Foundation
import SwiftData

@MainActor
final class ComparisonWeatherModel: ObservableObject {
    @Published private(set) var weatherByCandidate: [UUID: [String: WeatherDay]] = [:]
    @Published private(set) var errorsByCandidate: [UUID: String] = [:]
    @Published private(set) var state: ForecastState = .loading
    @Published private(set) var result: DestinationComparisonResult?
    @Published private(set) var lastUpdated: Date?

    var isLoading: Bool { if case .loading = state { return true }; return false }

    private let geocoding: OpenMeteoGeocodingService
    private let weather: OpenMeteoWeatherService
    private let cache: WeatherCacheStore
    private var loadInProgress = false

    init(
        geocoding: OpenMeteoGeocodingService = OpenMeteoGeocodingService(),
        weather: OpenMeteoWeatherService = OpenMeteoWeatherService(),
        cache: WeatherCacheStore = WeatherCacheStore()
    ) {
        self.geocoding = geocoding
        self.weather = weather
        self.cache = cache
    }

    func load(comparison: DestinationComparison, modelContext: ModelContext, force: Bool = false) async {
        guard !loadInProgress else { return }
        loadInProgress = true
        defer { loadInProgress = false }
        state = .loading
        errorsByCandidate = [:]

        var groups: [String: (latitude: Double, longitude: Double, candidates: [ComparisonCandidate])] = [:]
        for candidate in comparison.sortedCandidates {
            do {
                let place = try await coordinates(for: candidate)
                let key = TripWeatherModel.coordinateKey(latitude: place.latitude, longitude: place.longitude)
                var group = groups[key] ?? (place.latitude, place.longitude, [])
                group.candidates.append(candidate)
                groups[key] = group
            } catch {
                errorsByCandidate[candidate.id] = error.localizedDescription
            }
        }

        var loaded: [UUID: [String: WeatherDay]] = [:]
        var fetchDates: [Date] = []
        var usedStaleData = false
        let todayKey = WeatherDateKey.make(from: .now)

        for (key, group) in groups {
            let cached = await cache.entry(for: key)
            let fresh = cached.map { WeatherCachePolicy.isFresh($0) } ?? false
            var selected: WeatherCacheEntry?
            if let cached, fresh, !force {
                selected = cached
            } else {
                do {
                    let days = try await weather.forecast(latitude: group.latitude, longitude: group.longitude)
                    let entry = WeatherCacheEntry(
                        coordinateKey: key, latitude: group.latitude, longitude: group.longitude,
                        fetchedAt: .now, days: days
                    )
                    try? await cache.save(entry)
                    selected = entry
                } catch {
                    if let cached, !cached.days.isEmpty {
                        selected = cached
                        usedStaleData = !fresh
                    } else {
                        for candidate in group.candidates { errorsByCandidate[candidate.id] = error.localizedDescription }
                    }
                }
            }
            guard let entry = selected else { continue }
            fetchDates.append(entry.fetchedAt)
            let days = Dictionary(uniqueKeysWithValues: entry.days.filter { $0.dateISO >= todayKey }.map { ($0.dateISO, $0) })
            for candidate in group.candidates { loaded[candidate.id] = days }
        }

        weatherByCandidate = loaded
        lastUpdated = fetchDates.min()
        let inputs = comparison.sortedCandidates.map {
            CandidateForecastInput(candidateID: $0.id, placeName: $0.placeName, weatherByDate: loaded[$0.id] ?? [:])
        }
        let comparisonResult = DestinationComparisonEngine.compare(
            startDate: comparison.startDate, endDate: comparison.endDate, candidates: inputs
        )
        result = comparisonResult
        state = DestinationComparisonEngine.forecastState(
            result: comparisonResult,
            startDate: comparison.startDate,
            endDate: comparison.endDate,
            lastUpdated: lastUpdated,
            usesStaleData: usedStaleData
        )
        try? modelContext.save()
    }

    func weather(candidateID: UUID, dateKey: String) -> WeatherDay? {
        weatherByCandidate[candidateID]?[dateKey]
    }

    func unavailableMessage(candidateID: UUID, dateKey: String) -> String {
        if let error = errorsByCandidate[candidateID] { return error }
        if dateKey < WeatherDateKey.make(from: .now) { return String(localized: "forecast.noCurrentForecast") }
        return String(localized: "forecast.notYetAvailable")
    }

    private func coordinates(for candidate: ComparisonCandidate) async throws -> GeocodedPlace {
        if let latitude = candidate.latitude, let longitude = candidate.longitude {
            return GeocodedPlace(
                name: candidate.placeName, regionName: candidate.regionName, countryName: candidate.countryName,
                latitude: latitude, longitude: longitude, timeZoneIdentifier: candidate.timeZoneIdentifier
            )
        }
        let place = try await geocoding.geocode(candidate.placeName)
        candidate.placeName = place.name
        candidate.regionName = place.regionName
        candidate.countryName = place.countryName
        candidate.latitude = place.latitude
        candidate.longitude = place.longitude
        candidate.timeZoneIdentifier = place.timeZoneIdentifier
        return place
    }
}
