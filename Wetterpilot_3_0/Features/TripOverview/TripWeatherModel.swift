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
        isFresh(fetchedAt: entry.fetchedAt, now: now)
    }

    static func isFresh(fetchedAt: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(fetchedAt) >= 0
            && now.timeIntervalSince(fetchedAt) < freshnessInterval
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

    func reloadFromDisk() {
        entries = nil
        loadIfNeeded()
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

struct TripCardSegmentSnapshot: Sendable {
    let id: UUID
    let placeName: String
    let startDate: Date
    let endDate: Date
    let latitude: Double?
    let longitude: Double?
}

enum TripCardForecastSummary: Equatable, Sendable {
    case predominantlyDry
    case mixed(affectedDays: Int)
    case rainPossible(days: Int)
    case complete
    case partial(availableDays: Int, totalDays: Int)
    case availableFrom(Date)
    case noCurrentData
}

struct TripCardWeatherSummary: Equatable, Sendable {
    let forecast: TripCardForecastSummary
    let isStale: Bool
    let recommendedStartDate: Date?

    var symbolName: String {
        if isStale { return "clock.arrow.circlepath" }
        switch forecast {
        case .predominantlyDry: return "sun.max"
        case .mixed: return "cloud.sun"
        case .rainPossible: return "cloud.rain"
        case .complete: return "checkmark.icloud"
        case .partial: return "rectangle.split.3x1"
        case .availableFrom: return "calendar.badge.clock"
        case .noCurrentData: return "cloud.slash"
        }
    }
}

enum TripCardWeatherSummaryEngine {
    static func evaluate(
        segments: [TripCardSegmentSnapshot],
        flexibility: TripStartFlexibility,
        weatherByDay: [WeatherDayKey: WeatherDay],
        fetchedAt: [Date],
        preferences: TravelWeatherPreferences,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TripCardWeatherSummary? {
        guard let endDate = segments.map(\.endDate).max(),
              endDate >= calendar.startOfDay(for: now) else {
            return nil
        }

        let flexibleSegments = segments.map {
            FlexibleTripSegmentSnapshot(
                id: $0.id,
                placeName: $0.placeName,
                startDate: $0.startDate,
                endDate: $0.endDate
            )
        }
        let comparison = FlexibleTripStartEngine.compare(
            segments: flexibleSegments,
            flexibility: flexibility,
            weatherByDay: weatherByDay,
            preferences: preferences,
            now: now,
            calendar: calendar
        )
        guard let candidate = comparison.candidate(
            offset: comparison.recommendedOffset ?? 0
        ) ?? comparison.candidates.first else {
            return TripCardWeatherSummary(
                forecast: .noCurrentData,
                isStale: false,
                recommendedStartDate: nil
            )
        }

        let isStale = !fetchedAt.isEmpty && fetchedAt.contains {
            !WeatherCachePolicy.isFresh(fetchedAt: $0, now: now)
        }
        let recommendedDate = flexibility != .exact
            && comparison.hasFairCommonBasis
            && comparison.recommendedOffset != nil
            ? candidate.startDate
            : nil

        let forecast: TripCardForecastSummary
        switch candidate.forecastState {
        case .complete:
            let rainDays = Set(candidate.assessment.violations.compactMap { violation -> String? in
                guard violation.kind == .rainProbability
                        || violation.kind == .precipitationAmount else {
                    return nil
                }
                return WeatherDateKey.make(from: violation.date, calendar: calendar)
            }).count
            if rainDays >= 2 {
                forecast = .rainPossible(days: rainDays)
            } else if candidate.assessment.affectedDayCount > 0 {
                forecast = .mixed(affectedDays: candidate.assessment.affectedDayCount)
            } else {
                let days = candidate.shiftedTimeline.compactMap {
                    weatherByDay[WeatherDayKey(
                        segmentID: $0.segmentID,
                        dateISO: WeatherDateKey.make(from: $0.date, calendar: calendar)
                    )]
                }
                forecast = !days.isEmpty && days.allSatisfy(DestinationComparisonEngine.isExpectedDry)
                    ? .predominantlyDry
                    : .complete
            }
        case .partial(let availableDays, let totalDays, _):
            forecast = .partial(availableDays: availableDays, totalDays: totalDays)
        case .unavailable(let expectedAvailabilityDate):
            if let expectedAvailabilityDate,
               expectedAvailabilityDate > calendar.startOfDay(for: now) {
                forecast = .availableFrom(expectedAvailabilityDate)
            } else {
                forecast = .noCurrentData
            }
        }

        return TripCardWeatherSummary(
            forecast: forecast,
            isStale: isStale,
            recommendedStartDate: recommendedDate
        )
    }
}

@MainActor
final class TripListWeatherSummaryModel: ObservableObject {
    @Published private(set) var summaries: [UUID: TripCardWeatherSummary] = [:]
    private let cache: WeatherCacheStore

    init(cache: WeatherCacheStore = WeatherCacheStore()) {
        self.cache = cache
    }

    func load(trips: [Trip], preferences: TravelWeatherPreferences) async {
        await cache.reloadFromDisk()
        var result: [UUID: TripCardWeatherSummary] = [:]

        for trip in trips {
            let snapshots = trip.sortedSegments.map {
                TripCardSegmentSnapshot(
                    id: $0.id,
                    placeName: $0.placeName,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
            var weatherByDay: [WeatherDayKey: WeatherDay] = [:]
            var fetchedAt: [Date] = []
            var loadedCoordinateKeys: Set<String> = []

            for segment in snapshots {
                guard let latitude = segment.latitude,
                      let longitude = segment.longitude else {
                    continue
                }
                let coordinateKey = TripWeatherModel.coordinateKey(
                    latitude: latitude,
                    longitude: longitude
                )
                guard let entry = await cache.entry(for: coordinateKey) else {
                    continue
                }
                if loadedCoordinateKeys.insert(coordinateKey).inserted {
                    fetchedAt.append(entry.fetchedAt)
                }
                for day in entry.days {
                    weatherByDay[WeatherDayKey(
                        segmentID: segment.id,
                        dateISO: day.dateISO
                    )] = day
                }
            }

            if let summary = TripCardWeatherSummaryEngine.evaluate(
                segments: snapshots,
                flexibility: trip.startFlexibility,
                weatherByDay: weatherByDay,
                fetchedAt: fetchedAt,
                preferences: preferences
            ) {
                result[trip.id] = summary
            }
        }

        summaries = result
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
    @Published private(set) var usesStaleData = false

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
        usesStaleData = usedExpiredCache
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
        let snapshots = trip.sortedSegments.map(FlexibleTripSegmentSnapshot.init)
        let timeline = ((try? BuildFlexibleTripCandidates()(
            segments: snapshots,
            flexibility: trip.startFlexibility
        )) ?? []).flatMap(\.shiftedTimeline)
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

    func flexibleComparison(
        trip: Trip,
        preferences: TravelWeatherPreferences,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> FlexibleTripStartComparison {
        FlexibleTripStartEngine.compare(
            segments: trip.sortedSegments.map(FlexibleTripSegmentSnapshot.init),
            flexibility: trip.startFlexibility,
            weatherByDay: weatherByDay,
            preferences: preferences,
            now: now,
            calendar: calendar
        )
    }
}
