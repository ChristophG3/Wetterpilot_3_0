import SwiftData
import XCTest
@testable import Wetterpilot_3_0

final class PhaseOneTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testForecastAvailabilityCompletePartialAndOutsideRange() {
        let dates = [date(2026, 8, 1), date(2026, 8, 2), date(2026, 8, 3)]
        let complete = ForecastAvailability.evaluate(
            travelDates: dates, forecastDates: ["2026-08-01", "2026-08-02", "2026-08-03"],
            now: date(2026, 7, 20), calendar: utcCalendar
        )
        XCTAssertEqual(complete.availableDates.count, 3)
        XCTAssertTrue(complete.unavailableDates.isEmpty)

        let partial = ForecastAvailability.evaluate(
            travelDates: dates, forecastDates: ["2026-08-01"],
            now: date(2026, 7, 20), calendar: utcCalendar
        )
        XCTAssertEqual(partial.availableDates, ["2026-08-01"])
        XCTAssertEqual(partial.unavailableDates, ["2026-08-02", "2026-08-03"])

        let outside = ForecastAvailability.evaluate(
            travelDates: [date(2026, 9, 1)], forecastDates: [],
            now: date(2026, 7, 20), calendar: utcCalendar
        )
        XCTAssertEqual(outside.expectedAvailabilityDate, date(2026, 8, 17))

        XCTAssertEqual(ForecastState.resolve(availability: complete, lastUpdated: date(2026, 7, 20), usesStaleData: false), .available(lastUpdated: date(2026, 7, 20)))
        if case .partiallyAvailable(let dates, _, _) = ForecastState.resolve(availability: partial, lastUpdated: date(2026, 7, 20), usesStaleData: false) {
            XCTAssertEqual(dates, ["2026-08-01"])
        } else { XCTFail("Expected partiallyAvailable") }
        if case .outsideForecastRange(let availableFrom) = ForecastState.resolve(availability: outside, lastUpdated: nil, usesStaleData: false) {
            XCTAssertEqual(availableFrom, date(2026, 8, 17))
        } else { XCTFail("Expected outsideForecastRange") }
    }

    func testCacheFreshnessAndPersistence() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("cache.json")
        let store = WeatherCacheStore(fileURL: url)
        let fresh = cacheEntry(fetchedAt: .now)
        try await store.save(fresh)
        XCTAssertTrue(WeatherCachePolicy.isFresh(fresh))
        let storedEntry = await store.entry(for: fresh.coordinateKey)
        XCTAssertEqual(storedEntry, fresh)

        let stale = cacheEntry(fetchedAt: Date(timeIntervalSinceNow: -(WeatherCachePolicy.freshnessInterval + 1)))
        XCTAssertFalse(WeatherCachePolicy.isFresh(stale))
    }

    func testCacheReaderCanReloadUpdatesWrittenByAnotherInstance() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
        let reader = WeatherCacheStore(fileURL: url)
        let writer = WeatherCacheStore(fileURL: url)
        let stale = cacheEntry(
            fetchedAt: Date(timeIntervalSinceNow: -(WeatherCachePolicy.freshnessInterval + 60))
        )
        try await writer.save(stale)
        let initiallyRead = await reader.entry(for: stale.coordinateKey)
        XCTAssertEqual(
            try XCTUnwrap(initiallyRead).fetchedAt.timeIntervalSince1970,
            stale.fetchedAt.timeIntervalSince1970,
            accuracy: 1
        )

        let fresh = cacheEntry(fetchedAt: .now)
        try await writer.save(fresh)
        await reader.reloadFromDisk()

        let reloaded = await reader.entry(for: fresh.coordinateKey)
        XCTAssertEqual(
            try XCTUnwrap(reloaded).fetchedAt.timeIntervalSince1970,
            fresh.fetchedAt.timeIntervalSince1970,
            accuracy: 1
        )
    }

    @MainActor
    func testOfflineFallbackKeepsExpiredCachedWeather() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("cache.json")
        let cache = WeatherCacheStore(fileURL: url)
        let entry = cacheEntry(fetchedAt: Date(timeIntervalSinceNow: -(WeatherCachePolicy.freshnessInterval + 60)))
        try await cache.save(entry)
        let service = OpenMeteoWeatherService(client: FailingWeatherLoader())
        let model = TripWeatherModel(weather: service, cache: cache)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Trip.self, TripSegment.self, configurations: config)
        let trip = Trip(name: "Offline")
        let segment = TripSegment(
            placeName: "Test", latitude: 47.0, longitude: 11.0,
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 1), trip: trip
        )
        trip.segments = [segment]
        container.mainContext.insert(trip)
        container.mainContext.insert(segment)

        await model.load(trip: trip, modelContext: container.mainContext)

        XCTAssertNotNil(model.weatherByDay[WeatherDayKey(segmentID: segment.id, dateISO: "2026-08-01")])
        if case .stale = model.state {} else { XCTFail("Expected stale state, got \(model.state)") }
        XCTAssertTrue(model.errorsBySegment.isEmpty)
    }

    @MainActor
    func testValidCacheAvoidsNetworkRequest() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("cache.json")
        let cache = WeatherCacheStore(fileURL: url)
        try await cache.save(cacheEntry(fetchedAt: .now))
        let loader = CountingFailingWeatherLoader()
        let model = TripWeatherModel(weather: OpenMeteoWeatherService(client: loader), cache: cache)
        let container = try ModelContainer(for: Trip.self, TripSegment.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let trip = Trip(name: "Cached")
        let segment = TripSegment(placeName: "Test", latitude: 47, longitude: 11, startDate: date(2026, 8, 1), endDate: date(2026, 8, 1), trip: trip)
        trip.segments = [segment]
        container.mainContext.insert(trip)
        await model.load(trip: trip, modelContext: container.mainContext)
        let requestCount = await loader.requestCount
        XCTAssertEqual(requestCount, 0)
        if case .available = model.state {} else { XCTFail("Expected available state") }
    }

    @MainActor
    func testIdenticalCoordinatesUseSingleNetworkRequest() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("cache.json")
        let loader = CountingSuccessWeatherLoader()
        let model = TripWeatherModel(
            weather: OpenMeteoWeatherService(client: loader),
            cache: WeatherCacheStore(fileURL: url)
        )
        let container = try ModelContainer(for: Trip.self, TripSegment.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let trip = Trip(name: "Transfer")
        let first = TripSegment(placeName: "Hafen", latitude: 47, longitude: 11, startDate: date(2026, 8, 1), endDate: date(2026, 8, 1), trip: trip)
        let second = TripSegment(placeName: "Altstadt", latitude: 47, longitude: 11, startDate: date(2026, 8, 1), endDate: date(2026, 8, 1), trip: trip)
        trip.segments = [first, second]
        container.mainContext.insert(trip)
        await model.load(trip: trip, modelContext: container.mainContext)
        let requestCount = await loader.requestCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(model.weatherByDay.count, 2)
    }

    func testDecodesHourlyOpenMeteoValues() throws {
        let json = """
        {
          "daily": {
            "time": ["2026-08-01"], "weather_code": [2],
            "temperature_2m_min": [18], "temperature_2m_max": [27],
            "precipitation_probability_max": [70], "precipitation_sum": [1.2],
            "wind_speed_10m_max": [22]
          },
          "hourly": {
            "time": ["2026-08-01T16:00"], "temperature_2m": [24.1],
            "apparent_temperature": [25.3], "precipitation_probability": [72],
            "precipitation": [0.6], "weather_code": [80],
            "wind_speed_10m": [19.0], "wind_gusts_10m": [35.0]
          }
        }
        """
        let result = try OpenMeteoWeatherService.decodeForecast(Data(json.utf8))
        XCTAssertEqual(result.first?.hours.count, 1)
        XCTAssertEqual(result.first?.hours.first?.apparentTemperature, 25.3)
        XCTAssertEqual(result.first?.hours.first?.windGust, 35.0)
        XCTAssertEqual(HourlyWeatherSummary.evaluate(result[0].hours), .rainFrom(hour: 16))
    }

    func testWeatherDateKeyUsesLocalCalendarDay() {
        var bangkok = Calendar(identifier: .gregorian)
        bangkok.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        let instant = ISO8601DateFormatter().date(from: "2026-07-31T18:30:00Z")!
        XCTAssertEqual(WeatherDateKey.make(from: instant, calendar: bangkok), "2026-08-01")
        XCTAssertEqual(WeatherDateKey.make(from: instant, calendar: utcCalendar), "2026-07-31")
    }

    func testAdvisoryThresholdsAreInclusiveAndCentralized() {
        let weather = WeatherDay(
            dateISO: "2026-08-01", weatherCode: 95,
            minimumTemperature: 25, maximumTemperature: WeatherAdvisoryThresholds.heatCelsius,
            precipitationProbability: WeatherAdvisoryThresholds.rainProbability,
            precipitationAmount: WeatherAdvisoryThresholds.precipitationMillimeters,
            maximumWindSpeed: WeatherAdvisoryThresholds.windKilometersPerHour,
            maximumWindGust: WeatherAdvisoryThresholds.gustKilometersPerHour,
            maximumUVIndex: WeatherAdvisoryThresholds.uvIndex
        )
        XCTAssertEqual(Set(WeatherAdvisoryEvaluator.advisories(for: weather).map(\.kind)), Set(WeatherAdvisoryKind.allCases))
    }

    func testUnitConversions() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.value(fromCelsius: 0), 32, accuracy: 0.001)
        XCTAssertEqual(TemperatureUnit.fahrenheit.value(fromCelsius: 100), 212, accuracy: 0.001)
        XCTAssertEqual(WindSpeedUnit.milesPerHour.value(fromKilometersPerHour: 100), 62.1371, accuracy: 0.001)
    }

    func testNotificationPlanningAndIdentifier() {
        let fire = ForecastNotificationPlanner.notificationDate(
            firstTravelDate: date(2026, 9, 1), now: date(2026, 7, 1), calendar: utcCalendar
        )
        XCTAssertEqual(fire, date(2026, 8, 17, hour: 9))
        let id = UUID()
        XCTAssertEqual(ForecastNotificationPlanner.identifier(for: id), "forecast-available-\(id.uuidString)")
        XCTAssertNil(ForecastNotificationPlanner.notificationDate(
            firstTravelDate: date(2026, 7, 10), now: date(2026, 7, 1), calendar: utcCalendar
        ))
    }

    private func cacheEntry(fetchedAt: Date) -> WeatherCacheEntry {
        WeatherCacheEntry(
            coordinateKey: TripWeatherModel.coordinateKey(latitude: 47, longitude: 11), latitude: 47, longitude: 11,
            fetchedAt: fetchedAt,
            days: [WeatherDay(
                dateISO: "2026-08-01", weatherCode: 1, minimumTemperature: 10, maximumTemperature: 20,
                precipitationProbability: 10, precipitationAmount: 0, maximumWindSpeed: 5
            )]
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

private struct FailingWeatherLoader: WeatherDataLoading {
    struct Offline: Error {}
    func data(from url: URL) async throws -> Data { throw Offline() }
}

private actor CountingFailingWeatherLoader: WeatherDataLoading {
    private(set) var requestCount = 0
    func data(from url: URL) async throws -> Data {
        requestCount += 1
        throw FailingWeatherLoader.Offline()
    }
}

private actor CountingSuccessWeatherLoader: WeatherDataLoading {
    private(set) var requestCount = 0
    func data(from url: URL) async throws -> Data {
        requestCount += 1
        return Data("""
        {"daily":{"time":["2026-08-01"],"weather_code":[1],"temperature_2m_min":[10],"temperature_2m_max":[20],"precipitation_probability_max":[10],"precipitation_sum":[0],"wind_speed_10m_max":[5]}}
        """.utf8)
    }
}
