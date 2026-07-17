import SwiftData
import XCTest
@testable import Wetterpilot_3_0

final class PhaseThreeFlexibleStartTests: XCTestCase {
    private var utc: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testExistingTripsDefaultToExact() {
        XCTAssertEqual(Trip(name: "Bestehend").startFlexibility, .exact)
        let trip = Trip(name: "Ungültiger Altwert")
        trip.startFlexibilityRawValue = "legacy"
        XCTAssertEqual(trip.startFlexibility, .exact)
    }

    func testExactCreatesOnlyOffsetZero() throws {
        XCTAssertEqual(try drafts(.exact).map(\.offset), [0])
    }

    func testPlusMinusOneCreatesThreeOffsets() throws {
        XCTAssertEqual(try drafts(.plusMinusOneDay).map(\.offset), [-1, 0, 1])
    }

    func testPlusMinusTwoCreatesFiveOffsets() throws {
        XCTAssertEqual(try drafts(.plusMinusTwoDays).map(\.offset), [-2, -1, 0, 1, 2])
    }

    func testWholeTripMovesTogether() throws {
        let candidate = try drafts(.plusMinusTwoDays).first { $0.offset == 2 }!
        XCTAssertEqual(candidate.shiftedSegments.map(\.startDate), [date(2026, 8, 3), date(2026, 8, 5)])
        XCTAssertEqual(candidate.shiftedSegments.map(\.endDate), [date(2026, 8, 4), date(2026, 8, 5)])
    }

    func testStayDurationRemainsUnchanged() throws {
        let original = segments()
        let shifted = try drafts(.plusMinusTwoDays).last!.shiftedSegments
        XCTAssertEqual(
            original.map { utc.dateComponents([.day], from: $0.startDate, to: $0.endDate).day },
            shifted.map { utc.dateComponents([.day], from: $0.startDate, to: $0.endDate).day }
        )
    }

    func testSegmentOrderRemainsStable() throws {
        let input = segments()
        let originalIDs = input.map(\.id)
        let candidates = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusTwoDays
        )
        for candidate in candidates {
            XCTAssertEqual(candidate.shiftedSegments.map(\.id), originalIDs)
        }
    }

    func testTwoPlacesOnTransferDayRemainValid() throws {
        let shared = date(2026, 8, 2)
        let input = [
            FlexibleTripSegmentSnapshot(placeName: "A", startDate: date(2026, 8, 1), endDate: shared),
            FlexibleTripSegmentSnapshot(placeName: "B", startDate: shared, endDate: date(2026, 8, 3))
        ]
        let candidate = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )[2]
        let transfer = candidate.shiftedTimeline.filter {
            WeatherDateKey.make(from: $0.date, calendar: utc) == "2026-08-03"
        }
        XCTAssertEqual(transfer.map(\.placeName), ["A", "B"])
    }

    func testShiftAcrossMonthBoundary() throws {
        let input = [FlexibleTripSegmentSnapshot(
            placeName: "A", startDate: date(2026, 1, 31), endDate: date(2026, 1, 31)
        )]
        let result = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        XCTAssertEqual(result.last?.startDate, date(2026, 2, 1))
    }

    func testShiftAcrossYearBoundary() throws {
        let input = [FlexibleTripSegmentSnapshot(
            placeName: "A", startDate: date(2026, 12, 31), endDate: date(2026, 12, 31)
        )]
        let result = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        XCTAssertEqual(result.last?.startDate, date(2027, 1, 1))
    }

    func testShiftAcrossDaylightSavingUsesCalendarDays() throws {
        var berlin = Calendar(identifier: .gregorian)
        berlin.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let start = berlin.date(from: DateComponents(year: 2026, month: 3, day: 28))!
        let input = [FlexibleTripSegmentSnapshot(placeName: "A", startDate: start, endDate: start)]
        let result = try BuildFlexibleTripCandidates(calendar: berlin)(
            segments: input, flexibility: .plusMinusTwoDays
        )
        let plusTwo = result.first { $0.offset == 2 }!
        XCTAssertEqual(berlin.component(.day, from: plusTwo.startDate), 30)
        XCTAssertEqual(berlin.component(.hour, from: plusTwo.startDate), 0)
        XCTAssertNotEqual(plusTwo.startDate.timeIntervalSince(start), 2 * 86_400)
    }

    func testCandidatesDoNotMutateOriginalData() throws {
        let input = segments()
        let originalDates = input.map { ($0.startDate, $0.endDate) }
        _ = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusTwoDays
        )
        XCTAssertEqual(input.map(\.startDate), originalDates.map(\.0))
        XCTAssertEqual(input.map(\.endDate), originalDates.map(\.1))
    }

    func testFullyAssessableVariants() throws {
        let input = oneDaySegments()
        let drafts = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        let weather = weatherMap(for: drafts, segmentIDs: input.map(\.id))
        let result = FlexibleTripStartEngine.compare(
            segments: input, flexibility: .plusMinusOneDay,
            weatherByDay: weather, preferences: .standard,
            now: date(2026, 7, 1), calendar: utc
        )
        XCTAssertTrue(result.candidates.allSatisfy(\.isFullyAssessable))
        XCTAssertTrue(result.hasFairCommonBasis)
    }

    func testPartiallyAvailableVariant() throws {
        let input = [FlexibleTripSegmentSnapshot(
            placeName: "A", startDate: date(2026, 8, 1), endDate: date(2026, 8, 2)
        )]
        let draft = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .exact
        )[0]
        let firstDayOnly = [
            WeatherDayKey(segmentID: input[0].id, dateISO: "2026-08-01"):
                weather(dateISO: "2026-08-01")
        ]
        let result = EvaluateTripStartCandidate.callAsFunction(
            draft, weatherByDay: firstDayOnly, preferences: .standard,
            now: date(2026, 7, 1), calendar: utc
        )
        XCTAssertEqual(result.availableDayCount, 1)
        if case .partial(let available, let total, _) = result.forecastState {
            XCTAssertEqual(available, 1)
            XCTAssertEqual(total, 2)
        } else {
            XCTFail("Expected partial")
        }
    }

    func testVariantOutsideForecastWindowIncludesAvailabilityDate() throws {
        let input = [FlexibleTripSegmentSnapshot(
            placeName: "A", startDate: date(2026, 10, 1), endDate: date(2026, 10, 1)
        )]
        let draft = try BuildFlexibleTripCandidates(calendar: utc)(segments: input, flexibility: .exact)[0]
        let result = EvaluateTripStartCandidate.callAsFunction(
            draft, weatherByDay: [:], preferences: .standard,
            now: date(2026, 7, 1), calendar: utc
        )
        if case .unavailable(let expected) = result.forecastState {
            XCTAssertEqual(expected, date(2026, 9, 16))
        } else { XCTFail("Expected unavailable") }
    }

    func testNoRecommendationWithoutFairCommonBasis() throws {
        let input = oneDaySegments()
        let drafts = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        let onlyOriginal = weatherMap(for: drafts.filter { $0.offset == 0 }, segmentIDs: input.map(\.id))
        let result = FlexibleTripStartEngine.compare(
            segments: input, flexibility: .plusMinusOneDay,
            weatherByDay: onlyOriginal, preferences: .standard,
            now: date(2026, 7, 1), calendar: utc
        )
        XCTAssertFalse(result.hasFairCommonBasis)
        XCTAssertNil(result.recommendedOffset)
        XCTAssertEqual(result.preferredDisplayOffset, 0)
    }

    func testThunderstormPreference() throws {
        let candidate = try evaluated(weather: weather(code: 95))
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .thunderstorm })
    }

    func testRainProbabilityThreshold() throws {
        var preferences = TravelWeatherPreferences.standard
        preferences.maximumPrecipitationProbability = 60
        let candidate = try evaluated(weather: weather(probability: 60), preferences: preferences)
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .rainProbability })
    }

    func testPrecipitationAmountThreshold() throws {
        var preferences = TravelWeatherPreferences.standard
        preferences.maximumPrecipitationAmount = 5
        let candidate = try evaluated(weather: weather(precipitation: 5), preferences: preferences)
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .precipitationAmount })
    }

    func testWindAndGustThresholds() throws {
        var preferences = TravelWeatherPreferences.standard
        preferences.maximumWindSpeed = 30
        preferences.maximumWindGust = 50
        let candidate = try evaluated(weather: weather(wind: 30, gust: 50), preferences: preferences)
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .wind })
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .gust })
    }

    func testHeatAndColdThresholds() throws {
        var preferences = TravelWeatherPreferences.standard
        preferences.minimumComfortableTemperature = 5
        preferences.maximumComfortableTemperature = 30
        let candidate = try evaluated(
            weather: weather(minimum: 5, maximum: 30), preferences: preferences
        )
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .cold })
        XCTAssertTrue(candidate.assessment.violations.contains { $0.kind == .heat })
    }

    func testDisabledCriteriaDoNotInfluenceResult() throws {
        var preferences = TravelWeatherPreferences.standard
        preferences.avoidsThunderstorms = false
        preferences.considersRainProbability = false
        preferences.considersPrecipitationAmount = false
        preferences.considersWind = false
        preferences.considersGusts = false
        preferences.considersCold = false
        preferences.considersHeat = false
        let candidate = try evaluated(
            weather: weather(
                code: 95, probability: 100, precipitation: 50,
                wind: 100, gust: 150, minimum: -20, maximum: 50
            ),
            preferences: preferences
        )
        XCTAssertTrue(candidate.assessment.violations.isEmpty)
        XCTAssertEqual(candidate.assessment.level, .favorable)
    }

    func testGlobalPreferencesPersist() {
        let suite = "PhaseThreeFlexibleStartTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var preferences = TravelWeatherPreferences.standard
        preferences.maximumWindSpeed = 33
        TravelWeatherPreferencesStore.save(preferences, defaults: defaults)
        XCTAssertEqual(TravelWeatherPreferencesStore.load(defaults: defaults).maximumWindSpeed, 33)
    }

    func testPreferenceChangesReevaluateWithoutChangingWeather() throws {
        var strict = TravelWeatherPreferences.standard
        strict.maximumWindSpeed = 20
        var relaxed = strict
        relaxed.considersWind = false
        let strictCandidate = try evaluated(weather: weather(wind: 25), preferences: strict)
        let relaxedCandidate = try evaluated(weather: weather(wind: 25), preferences: relaxed)
        XCTAssertTrue(strictCandidate.assessment.violations.contains { $0.kind == .wind })
        XCTAssertFalse(relaxedCandidate.assessment.violations.contains { $0.kind == .wind })
    }

    func testStableTiePrefersOriginalForDisplayWithoutFalseRecommendation() throws {
        let input = oneDaySegments()
        let drafts = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        let result = FlexibleTripStartEngine.compare(
            segments: input, flexibility: .plusMinusOneDay,
            weatherByDay: weatherMap(for: drafts, segmentIDs: input.map(\.id)),
            preferences: .standard, now: date(2026, 7, 1), calendar: utc
        )
        XCTAssertEqual(result.preferredDisplayOffset, 0)
        XCTAssertNil(result.recommendedOffset)
        XCTAssertTrue(result.differencesAreSmall)
    }

    func testSimilarVariantsDoNotCreateWinner() throws {
        let input = oneDaySegments()
        let drafts = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        var map = weatherMap(for: drafts, segmentIDs: input.map(\.id))
        for (index, draft) in drafts.enumerated() {
            let key = WeatherDayKey(
                segmentID: input[0].id,
                dateISO: WeatherDateKey.make(from: draft.startDate, calendar: utc)
            )
            map[key] = weather(wind: 41 + Double(index))
        }
        let result = FlexibleTripStartEngine.compare(
            segments: input, flexibility: .plusMinusOneDay,
            weatherByDay: map, preferences: .standard,
            now: date(2026, 7, 1), calendar: utc
        )
        XCTAssertNil(result.recommendedOffset)
        XCTAssertTrue(result.differencesAreSmall)
    }

    func testChoosingAlternativeChangesOnlyDerivedTimeline() throws {
        let input = oneDaySegments()
        let drafts = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: input, flexibility: .plusMinusOneDay
        )
        XCTAssertNotEqual(drafts[0].shiftedTimeline[0].date, drafts[2].shiftedTimeline[0].date)
        XCTAssertEqual(input[0].startDate, date(2026, 8, 1))
    }

    @MainActor
    func testWeatherRequestsAreNotMultipliedByVariants() async throws {
        let loader = FlexibleCountingLoader()
        let model = TripWeatherModel(
            weather: OpenMeteoWeatherService(client: loader),
            cache: WeatherCacheStore(fileURL: temporaryCacheURL())
        )
        let container = try ModelContainer(
            for: Trip.self, TripSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let trip = Trip(name: "Flexibel", startFlexibility: .plusMinusTwoDays)
        let segment = TripSegment(
            placeName: "A", latitude: 47, longitude: 11,
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 1), trip: trip
        )
        trip.segments = [segment]
        container.mainContext.insert(trip)
        await model.load(trip: trip, modelContext: container.mainContext)
        let requestCount = await loader.requestCount
        XCTAssertEqual(requestCount, 1)
    }

    @MainActor
    func testFlexibleTripKeepsStaleCacheOffline() async throws {
        let cache = WeatherCacheStore(fileURL: temporaryCacheURL())
        let stale = WeatherCacheEntry(
            coordinateKey: TripWeatherModel.coordinateKey(latitude: 47, longitude: 11),
            latitude: 47, longitude: 11,
            fetchedAt: Date(timeIntervalSinceNow: -(WeatherCachePolicy.freshnessInterval + 60)),
            days: [weather()]
        )
        try await cache.save(stale)
        let model = TripWeatherModel(
            weather: OpenMeteoWeatherService(client: FlexibleOfflineLoader()), cache: cache
        )
        let container = try ModelContainer(
            for: Trip.self, TripSegment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let trip = Trip(name: "Offline", startFlexibility: .plusMinusOneDay)
        let segment = TripSegment(
            placeName: "A", latitude: 47, longitude: 11,
            startDate: date(2026, 8, 1), endDate: date(2026, 8, 1), trip: trip
        )
        trip.segments = [segment]
        container.mainContext.insert(trip)
        await model.load(trip: trip, modelContext: container.mainContext)
        XCTAssertFalse(model.weatherByDay.isEmpty)
        XCTAssertTrue(model.usesStaleData)
    }

    func testFlexibleNotificationDateChangesWithFlexibility() {
        let exact = ForecastNotificationPlanner.notificationDate(
            firstTravelDate: date(2026, 9, 1), now: date(2026, 7, 1), calendar: utc
        )
        let flexible = ForecastNotificationPlanner.flexibleComparisonNotificationDate(
            originalEndDate: date(2026, 9, 3), flexibility: .plusMinusTwoDays,
            now: date(2026, 7, 1), calendar: utc
        )
        XCTAssertEqual(exact, date(2026, 8, 17, hour: 9))
        XCTAssertEqual(flexible, date(2026, 8, 21, hour: 9))
    }

    private func drafts(_ flexibility: TripStartFlexibility) throws -> [TripStartCandidateDraft] {
        try BuildFlexibleTripCandidates(calendar: utc)(
            segments: segments(), flexibility: flexibility
        )
    }

    private func segments() -> [FlexibleTripSegmentSnapshot] {
        [
            FlexibleTripSegmentSnapshot(
                placeName: "A", startDate: date(2026, 8, 1), endDate: date(2026, 8, 2)
            ),
            FlexibleTripSegmentSnapshot(
                placeName: "B", startDate: date(2026, 8, 3), endDate: date(2026, 8, 3)
            )
        ]
    }

    private func oneDaySegments() -> [FlexibleTripSegmentSnapshot] {
        [FlexibleTripSegmentSnapshot(
            placeName: "A", startDate: date(2026, 8, 1), endDate: date(2026, 8, 1)
        )]
    }

    private func evaluated(
        weather: WeatherDay,
        preferences: TravelWeatherPreferences = .standard
    ) throws -> TripStartCandidate {
        let segment = oneDaySegments()[0]
        let draft = try BuildFlexibleTripCandidates(calendar: utc)(
            segments: [segment], flexibility: .exact
        )[0]
        return EvaluateTripStartCandidate.callAsFunction(
            draft,
            weatherByDay: [
                WeatherDayKey(segmentID: segment.id, dateISO: "2026-08-01"): weather
            ],
            preferences: preferences,
            now: date(2026, 7, 1),
            calendar: utc
        )
    }

    private func weatherMap(
        for drafts: [TripStartCandidateDraft],
        segmentIDs: [UUID]
    ) -> [WeatherDayKey: WeatherDay] {
        var result: [WeatherDayKey: WeatherDay] = [:]
        for draft in drafts {
            for day in draft.shiftedTimeline where segmentIDs.contains(day.segmentID) {
                let key = WeatherDateKey.make(from: day.date, calendar: utc)
                result[WeatherDayKey(segmentID: day.segmentID, dateISO: key)] = weather(dateISO: key)
            }
        }
        return result
    }

    private func weather(
        dateISO: String = "2026-08-01",
        code: Int = 1,
        probability: Int? = 10,
        precipitation: Double = 0,
        wind: Double = 10,
        gust: Double? = 20,
        minimum: Double = 12,
        maximum: Double = 24
    ) -> WeatherDay {
        WeatherDay(
            dateISO: dateISO, weatherCode: code,
            minimumTemperature: minimum, maximumTemperature: maximum,
            precipitationProbability: probability, precipitationAmount: precipitation,
            maximumWindSpeed: wind, maximumWindGust: gust
        )
    }

    private func temporaryCacheURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("cache.json")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}

private struct FlexibleOfflineLoader: WeatherDataLoading {
    struct Offline: Error {}
    func data(from url: URL) async throws -> Data { throw Offline() }
}

private actor FlexibleCountingLoader: WeatherDataLoading {
    private(set) var requestCount = 0

    func data(from url: URL) async throws -> Data {
        requestCount += 1
        return Data("""
        {"daily":{"time":["2026-08-01"],"weather_code":[1],"temperature_2m_min":[12],"temperature_2m_max":[24],"precipitation_probability_max":[10],"precipitation_sum":[0],"wind_speed_10m_max":[10],"wind_gusts_10m_max":[20]}}
        """.utf8)
    }
}
