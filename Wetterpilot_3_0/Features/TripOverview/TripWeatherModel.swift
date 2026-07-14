import Foundation
import SwiftData

struct WeatherCacheEntry: Codable, Equatable, Sendable {
    let coordinateKey: String
    let latitude: Double
    let longitude: Double
    let fetchedAt: Date
    let days: [WeatherDay]
}

enum WeatherCachePolicy {
    static let freshnessInterval: TimeInterval = 3 * 60 * 60
    static func isFresh(_ entry: WeatherCacheEntry, now: Date = .now) -> Bool {
        now.timeIntervalSince(entry.fetchedAt) >= 0 && now.timeIntervalSince(entry.fetchedAt) < freshnessInterval
    }
}

actor WeatherCacheStore {
    private let fileURL: URL
    private var entries: [String: WeatherCacheEntry]?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Wetterpilot", isDirectory: true)
            self.fileURL = directory.appendingPathComponent("weather-cache.json")
        }
    }

    func entry(for key: String) -> WeatherCacheEntry? {
        loadIfNeeded()
        return entries?[key]
    }

    func save(_ entry: WeatherCacheEntry) throws {
        loadIfNeeded()
        entries?[entry.coordinateKey] = entry
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let data = try JSONEncoder.weatherCache.encode(entries ?? [:])
        try data.write(to: fileURL, options: .atomic)
    }

    func removeAll() throws {
        entries = [:]
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }

    private func loadIfNeeded() {
        guard entries == nil else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder.weatherCache.decode([String: WeatherCacheEntry].self, from: data) else {
            entries = [:]
            return
        }
        entries = decoded
    }
}

private extension JSONEncoder {
    static var weatherCache: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var weatherCache: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
final class TripWeatherModel: ObservableObject {
    @Published private(set) var weatherByDay: [WeatherDayKey: WeatherDay] = [:]
    @Published private(set) var errorsBySegment: [UUID: String] = [:]
    @Published private(set) var state: ForecastState = .loading
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

    func load(trip: Trip, modelContext: ModelContext, force: Bool = false) async {
        guard !loadInProgress else { return }
        loadInProgress = true
        defer { loadInProgress = false }
        state = .loading
        errorsBySegment = [:]

        var coordinateGroups: [String: (latitude: Double, longitude: Double, segments: [TripSegment])] = [:]
        for segment in trip.sortedSegments {
            do {
                let place = try await coordinates(for: segment)
                let key = Self.coordinateKey(latitude: place.latitude, longitude: place.longitude)
                if coordinateGroups[key] == nil {
                    coordinateGroups[key] = (place.latitude, place.longitude, [])
                }
                coordinateGroups[key]?.segments.append(segment)
            } catch {
                errorsBySegment[segment.id] = error.localizedDescription
            }
        }

        var loaded: [WeatherDayKey: WeatherDay] = [:]
        var fetchDates: [Date] = []
        var usedExpiredCache = false

        for (key, group) in coordinateGroups {
            let cached = await cache.entry(for: key)
            let cachedIsFresh = cached.map { WeatherCachePolicy.isFresh($0) } ?? false
            var selectedEntry: WeatherCacheEntry?

            if let cached, cachedIsFresh, !force {
                selectedEntry = cached
            } else {
                do {
                    let days = try await weather.forecast(latitude: group.latitude, longitude: group.longitude)
                    let entry = WeatherCacheEntry(
                        coordinateKey: key, latitude: group.latitude, longitude: group.longitude,
                        fetchedAt: .now, days: days
                    )
                    try? await cache.save(entry)
                    selectedEntry = entry
                } catch {
                    if let cached, !cached.days.isEmpty {
                        selectedEntry = cached
                        usedExpiredCache = !cachedIsFresh
                    } else {
                        for segment in group.segments { errorsBySegment[segment.id] = error.localizedDescription }
                    }
                }
            }

            guard let entry = selectedEntry else { continue }
            fetchDates.append(entry.fetchedAt)
            let todayKey = WeatherDateKey.make(from: .now)
            for segment in group.segments {
                for day in entry.days where day.dateISO >= todayKey {
                    loaded[WeatherDayKey(segmentID: segment.id, dateISO: day.dateISO)] = day
                }
            }
        }

        weatherByDay = loaded
        // The trip-level timestamp is conservative when several places were
        // fetched at different times.
        lastUpdated = fetchDates.min()
        state = forecastState(trip: trip, loaded: loaded, stale: usedExpiredCache)
        try? modelContext.save()
    }

    func weather(for day: TripDay) -> WeatherDay? {
        guard day.date >= Calendar.autoupdatingCurrent.startOfDay(for: .now) else { return nil }
        return weatherByDay[WeatherDayKey(segmentID: day.segmentID, dateISO: WeatherDateKey.make(from: day.date))]
    }

    func isDateAvailable(_ day: TripDay) -> Bool { weather(for: day) != nil }

    func unavailableMessage(for day: TripDay) -> String {
        if day.date < Calendar.current.startOfDay(for: .now) { return String(localized: "forecast.noCurrentForecast") }
        if case .failed = state, let error = errorsBySegment[day.segmentID] { return error }
        return String(localized: "forecast.notYetAvailable")
    }

    nonisolated static func coordinateKey(latitude: Double, longitude: Double) -> String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }

    private func forecastState(trip: Trip, loaded: [WeatherDayKey: WeatherDay], stale: Bool) -> ForecastState {
        let segments = trip.sortedSegments.map {
            TimelineSegment(id: $0.id, placeName: $0.placeName, startDate: $0.startDate, endDate: $0.endDate)
        }
        let timeline = (try? BuildTripTimeline()(segments: segments)) ?? []
        let forecastDates = Set(loaded.keys.map(\.dateISO))
        let availability = ForecastAvailability.evaluate(travelDates: timeline.map(\.date), forecastDates: forecastDates)

        return ForecastState.resolve(availability: availability, lastUpdated: lastUpdated, usesStaleData: stale)
    }

    private func coordinates(for segment: TripSegment) async throws -> GeocodedPlace {
        if let latitude = segment.latitude, let longitude = segment.longitude {
            return GeocodedPlace(
                name: segment.placeName, regionName: segment.regionName, countryName: segment.countryName,
                latitude: latitude, longitude: longitude, timeZoneIdentifier: segment.timeZoneIdentifier
            )
        }
        let place = try await geocoding.geocode(segment.placeName)
        segment.placeName = place.name
        segment.regionName = place.regionName
        segment.countryName = place.countryName
        segment.latitude = place.latitude
        segment.longitude = place.longitude
        segment.timeZoneIdentifier = place.timeZoneIdentifier
        return place
    }
}
