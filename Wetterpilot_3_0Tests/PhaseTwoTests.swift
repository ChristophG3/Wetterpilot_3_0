import SwiftData
import XCTest
@testable import Wetterpilot_3_0

final class PhaseTwoTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testAllCandidatesUseOneSharedRequestedPeriod() {
        let result = DestinationComparisonEngine.compare(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 3),
            candidates: [input("A", days: [1, 2, 3]), input("B", days: [1, 2, 3])],
            calendar: calendar
        )
        XCTAssertEqual(result.requestedDateKeys, ["2026-08-01", "2026-08-02", "2026-08-03"])
        XCTAssertEqual(result.sharedAvailableDateKeys, result.requestedDateKeys)
        XCTAssertEqual(Set(result.metrics.map(\.comparedDayCount)), [3])
    }

    func testRequiresTwoValidAndAtMostSixPlaces() {
        XCTAssertThrowsError(try DestinationComparisonValidator.validate(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 2),
            candidates: [ComparisonCandidateInput(id: UUID(), placeName: "A", coordinateKey: "1,1")]
        )) { XCTAssertEqual($0 as? ComparisonValidationError, .tooFewCandidates) }

        XCTAssertNoThrow(try DestinationComparisonValidator.validate(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 2),
            candidates: [
                ComparisonCandidateInput(id: UUID(), placeName: "A", coordinateKey: "1,1"),
                ComparisonCandidateInput(id: UUID(), placeName: "B", coordinateKey: "2,2")
            ]
        ))

        XCTAssertThrowsError(try DestinationComparisonValidator.validate(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 2),
            candidates: (0..<7).map {
                ComparisonCandidateInput(id: UUID(), placeName: "Place \($0)", coordinateKey: "\($0),\($0)")
            }
        )) { XCTAssertEqual($0 as? ComparisonValidationError, .tooManyCandidates) }
    }

    @MainActor
    func testComparisonCandidatesWithIdenticalCoordinatesUseSingleNetworkRequest() async throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
        let loader = PhaseTwoCountingSuccessLoader()
        let model = ComparisonWeatherModel(
            weather: OpenMeteoWeatherService(client: loader),
            cache: WeatherCacheStore(fileURL: cacheURL)
        )
        let container = try ModelContainer(
            for: Trip.self, TripSegment.self, DestinationComparison.self, ComparisonCandidate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let comparison = DestinationComparison(
            name: "Gebündelt", startDate: date(2026, 8, 1), endDate: date(2026, 8, 1)
        )
        comparison.candidates = [
            ComparisonCandidate(placeName: "A", latitude: 47, longitude: 11, comparison: comparison),
            ComparisonCandidate(placeName: "B", latitude: 47, longitude: 11, comparison: comparison)
        ]
        container.mainContext.insert(comparison)

        await model.load(comparison: comparison, modelContext: container.mainContext)

        let requestCount = await loader.requestCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(model.weatherByCandidate.count, 2)
    }

    func testComparisonCompletelyOutsideForecastWindow() {
        let result = DestinationComparisonEngine.compare(
            startDate: date(2026, 10, 1), endDate: date(2026, 10, 3),
            candidates: [input("A", days: []), input("B", days: [])], calendar: calendar
        )
        let state = DestinationComparisonEngine.forecastState(
            result: result, startDate: date(2026, 10, 1), endDate: date(2026, 10, 3),
            lastUpdated: nil, usesStaleData: false, now: date(2026, 7, 1), calendar: calendar
        )
        if case .outsideForecastRange(let availableFrom) = state {
            XCTAssertEqual(availableFrom, date(2026, 9, 16))
        } else { XCTFail("Expected outsideForecastRange") }
    }

    func testPartiallyAvailableComparisonIsMarkedHonestly() {
        let result = DestinationComparisonEngine.compare(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 3),
            candidates: [input("A", days: [1, 2]), input("B", days: [1])], calendar: calendar
        )
        let state = DestinationComparisonEngine.forecastState(
            result: result, startDate: date(2026, 8, 1), endDate: date(2026, 8, 3),
            lastUpdated: date(2026, 7, 31), usesStaleData: false,
            now: date(2026, 7, 20), calendar: calendar
        )
        XCTAssertEqual(result.sharedAvailableDateKeys, ["2026-08-01"])
        if case .partiallyAvailable = state {} else { XCTFail("Expected partiallyAvailable") }
        XCTAssertFalse(result.hasSufficientSharedData)
        XCTAssertTrue(result.tendencies.isEmpty)
    }

    func testOnlyCommonAvailableDaysAreComparedWhenCandidateHasMissingValue() {
        let result = DestinationComparisonEngine.compare(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 3),
            candidates: [input("A", days: [1, 2, 3]), input("B", days: [1, 3])], calendar: calendar
        )
        XCTAssertEqual(result.sharedAvailableDateKeys, ["2026-08-01", "2026-08-03"])
        XCTAssertEqual(Set(result.metrics.map(\.comparedDayCount)), [2])
        XCTAssertTrue(result.hasSufficientSharedData)
    }

    func testDryDaysAndPrecipitationSumsUseDocumentedDefinition() {
        let a = UUID()
        let input = CandidateForecastInput(candidateID: a, placeName: "A", weatherByDate: [
            "2026-08-01": weather(day: 1, probability: 49, precipitation: 0.9),
            "2026-08-02": weather(day: 2, probability: 50, precipitation: 0.2),
            "2026-08-03": weather(day: 3, probability: 20, precipitation: 1.0)
        ])
        let result = DestinationComparisonEngine.compare(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 3),
            candidates: [input, self.input("B", days: [1, 2, 3])], calendar: calendar
        )
        let metrics = result.metrics.first { $0.candidateID == a }!
        XCTAssertEqual(metrics.dryDayCount, 1)
        XCTAssertEqual(metrics.precipitationSum, 2.1, accuracy: 0.001)
    }

    func testTendenciesContainConcreteExplainableDifferences() {
        let dryID = UUID()
        let wetID = UUID()
        let dry = CandidateForecastInput(candidateID: dryID, placeName: "Dry", weatherByDate: [
            "2026-08-01": weather(day: 1, probability: 10, precipitation: 0, wind: 10),
            "2026-08-02": weather(day: 2, probability: 10, precipitation: 0, wind: 12)
        ])
        let wet = CandidateForecastInput(candidateID: wetID, placeName: "Wet", weatherByDate: [
            "2026-08-01": weather(day: 1, probability: 90, precipitation: 4, wind: 25),
            "2026-08-02": weather(day: 2, probability: 80, precipitation: 3, wind: 24)
        ])
        let result = DestinationComparisonEngine.compare(
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 2), candidates: [dry, wet], calendar: calendar
        )
        XCTAssertTrue(result.tendencies.contains { $0.candidateID == dryID && $0.kind == .moreDryDays(difference: 2) })
        XCTAssertTrue(result.tendencies.contains { $0.candidateID == dryID && $0.kind == .lessPrecipitation(difference: 7) })
        XCTAssertTrue(result.tendencies.contains { $0.candidateID == dryID && $0.kind == .lessWind(difference: 13) })
    }

    func testResultsAreIndependentOfCandidateOrder() {
        let a = input("A", days: [1, 2, 3])
        let b = input("B", days: [1, 2, 3])
        let forward = DestinationComparisonEngine.compare(startDate: date(2026, 8, 1), endDate: date(2026, 8, 3), candidates: [a, b], calendar: calendar)
        let reverse = DestinationComparisonEngine.compare(startDate: date(2026, 8, 1), endDate: date(2026, 8, 3), candidates: [b, a], calendar: calendar)
        XCTAssertEqual(forward, reverse)
    }

    @MainActor
    func testComparisonUsesExpiredCacheOfflineWithoutErrors() async throws {
        let cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("cache.json")
        let cache = WeatherCacheStore(fileURL: cacheURL)
        let staleDate = Date(timeIntervalSinceNow: -(WeatherCachePolicy.freshnessInterval + 60))
        try await cache.save(cacheEntry(latitude: 47, longitude: 11, fetchedAt: staleDate))
        try await cache.save(cacheEntry(latitude: 48, longitude: 12, fetchedAt: staleDate))
        let model = ComparisonWeatherModel(weather: OpenMeteoWeatherService(client: PhaseTwoOfflineLoader()), cache: cache)
        let container = try ModelContainer(
            for: Trip.self, TripSegment.self, DestinationComparison.self, ComparisonCandidate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let comparison = DestinationComparison(name: "Offline", startDate: date(2026, 8, 1), endDate: date(2026, 8, 1))
        comparison.candidates = [
            ComparisonCandidate(placeName: "A", latitude: 47, longitude: 11, comparison: comparison),
            ComparisonCandidate(placeName: "B", latitude: 48, longitude: 12, comparison: comparison)
        ]
        container.mainContext.insert(comparison)
        await model.load(comparison: comparison, modelContext: container.mainContext)
        XCTAssertEqual(model.result?.sharedAvailableDateKeys, ["2026-08-01"])
        XCTAssertTrue(model.errorsByCandidate.isEmpty)
        if case .stale = model.state {} else { XCTFail("Expected stale state") }
    }

    func testCandidateConvertsToCompatibleNormalTrip() {
        let comparison = DestinationComparison(name: "A oder B", startDate: date(2026, 8, 1), endDate: date(2026, 8, 3))
        let candidate = ComparisonCandidate(placeName: "A", regionName: "Region", countryName: "DE", latitude: 47, longitude: 11, comparison: comparison)
        let trip = CandidateToTripConverter.makeTrip(candidate: candidate, comparison: comparison, now: date(2026, 7, 1), calendar: calendar)
        XCTAssertEqual(trip.name, "A")
        XCTAssertEqual(trip.segments.count, 1)
        XCTAssertEqual(trip.segments[0].startDate, date(2026, 8, 1))
        XCTAssertEqual(trip.segments[0].endDate, date(2026, 8, 3))
        XCTAssertEqual(trip.segments[0].latitude, 47)
    }

    func testComparisonNotificationHasDedicatedIdentifier() {
        let id = UUID()
        XCTAssertEqual(ForecastNotificationPlanner.comparisonIdentifier(for: id), "comparison-forecast-available-\(id.uuidString)")
    }

    private func input(_ name: String, days: [Int]) -> CandidateForecastInput {
        CandidateForecastInput(
            candidateID: UUID(), placeName: name,
            weatherByDate: Dictionary(uniqueKeysWithValues: days.map { (String(format: "2026-08-%02d", $0), weather(day: $0)) })
        )
    }

    private func weather(
        day: Int,
        probability: Int? = 20,
        precipitation: Double = 0.2,
        wind: Double = 15
    ) -> WeatherDay {
        WeatherDay(
            dateISO: String(format: "2026-08-%02d", day), weatherCode: 1,
            minimumTemperature: 15, maximumTemperature: 25,
            precipitationProbability: probability, precipitationAmount: precipitation,
            maximumWindSpeed: wind, maximumWindGust: wind + 10
        )
    }

    private func cacheEntry(latitude: Double, longitude: Double, fetchedAt: Date) -> WeatherCacheEntry {
        WeatherCacheEntry(
            coordinateKey: TripWeatherModel.coordinateKey(latitude: latitude, longitude: longitude),
            latitude: latitude, longitude: longitude, fetchedAt: fetchedAt, days: [weather(day: 1)]
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private struct PhaseTwoOfflineLoader: WeatherDataLoading {
    struct Offline: Error {}
    func data(from url: URL) async throws -> Data { throw Offline() }
}

private actor PhaseTwoCountingSuccessLoader: WeatherDataLoading {
    private(set) var requestCount = 0

    func data(from url: URL) async throws -> Data {
        requestCount += 1
        return Data("""
        {"daily":{"time":["2026-08-01"],"weather_code":[1],"temperature_2m_min":[10],"temperature_2m_max":[20],"precipitation_probability_max":[10],"precipitation_sum":[0],"wind_speed_10m_max":[5]}}
        """.utf8)
    }
}
