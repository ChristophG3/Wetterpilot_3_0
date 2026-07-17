import Foundation

enum ComparisonValidationError: LocalizedError, Equatable {
    case invalidDateRange
    case tooFewCandidates
    case tooManyCandidates
    case emptyPlace
    case duplicatePlace

    var errorDescription: String? {
        switch self {
        case .invalidDateRange: return String(localized: "comparison.error.dateRange")
        case .tooFewCandidates: return String(localized: "comparison.error.tooFew")
        case .tooManyCandidates: return String(localized: "comparison.error.tooMany")
        case .emptyPlace: return String(localized: "comparison.error.emptyPlace")
        case .duplicatePlace: return String(localized: "comparison.error.duplicatePlace")
        }
    }
}

struct ComparisonCandidateInput: Equatable, Sendable {
    let id: UUID
    let placeName: String
    let coordinateKey: String?
}

enum DestinationComparisonValidator {
    static let minimumCandidates = 2
    static let maximumCandidates = 6

    static func validate(startDate: Date, endDate: Date, candidates: [ComparisonCandidateInput]) throws {
        guard endDate >= startDate else { throw ComparisonValidationError.invalidDateRange }
        guard candidates.count >= minimumCandidates else { throw ComparisonValidationError.tooFewCandidates }
        guard candidates.count <= maximumCandidates else { throw ComparisonValidationError.tooManyCandidates }
        guard candidates.allSatisfy({ !$0.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ComparisonValidationError.emptyPlace
        }
        let resolvedKeys = candidates.compactMap(\.coordinateKey)
        guard Set(resolvedKeys).count == resolvedKeys.count else { throw ComparisonValidationError.duplicatePlace }
    }
}

struct CandidateForecastInput: Sendable {
    let candidateID: UUID
    let placeName: String
    let weatherByDate: [String: WeatherDay]
}

struct ComparisonCandidateMetrics: Identifiable, Equatable, Sendable {
    let candidateID: UUID
    let placeName: String
    let comparedDayCount: Int
    let dryDayCount: Int
    let precipitationSum: Double
    let maximumPrecipitationProbability: Int?
    let minimumTemperature: Double
    let maximumTemperature: Double
    let maximumWindSpeed: Double
    let maximumWindGust: Double?
    let advisories: [WeatherAdvisoryKind]
    var id: UUID { candidateID }
}

enum ComparisonTendencyKind: Equatable, Sendable {
    case moreDryDays(difference: Int)
    case lessPrecipitation(difference: Double)
    case lessWind(difference: Double)
}

struct ComparisonTendency: Identifiable, Equatable, Sendable {
    let candidateID: UUID
    let placeName: String
    let kind: ComparisonTendencyKind
    var id: String { "\(candidateID.uuidString)-\(String(describing: kind))" }
}

struct DestinationComparisonResult: Equatable, Sendable {
    let requestedDateKeys: [String]
    let sharedAvailableDateKeys: [String]
    let anyAvailableDateKeys: Set<String>
    let metrics: [ComparisonCandidateMetrics]
    let tendencies: [ComparisonTendency]
    let hasSufficientSharedData: Bool
}

enum DestinationComparisonEngine {
    /// A day is "expected to be dry" only when the forecast contains a rain
    /// probability below 50 percent AND less than 1.0 mm precipitation.
    /// A missing probability never counts as a dry day.
    static let dryProbabilityThreshold = 50
    static let dryPrecipitationThreshold = 1.0

    static func isExpectedDry(_ weather: WeatherDay) -> Bool {
        guard let probability = weather.precipitationProbability else { return false }
        return probability < dryProbabilityThreshold
            && weather.precipitationAmount < dryPrecipitationThreshold
    }

    static func requestedDateKeys(
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [String] {
        guard endDate >= startDate else { return [] }
        var result: [String] = []
        var date = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        while date <= end {
            result.append(WeatherDateKey.make(from: date, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return result
    }

    static func compare(
        startDate: Date,
        endDate: Date,
        candidates: [CandidateForecastInput],
        calendar: Calendar = .autoupdatingCurrent
    ) -> DestinationComparisonResult {
        let requested = requestedDateKeys(from: startDate, through: endDate, calendar: calendar)
        let requestedSet = Set(requested)
        let shared: Set<String>
        if let first = candidates.first {
            shared = candidates.dropFirst().reduce(Set(first.weatherByDate.keys).intersection(requestedSet)) {
                $0.intersection($1.weatherByDate.keys)
            }
        } else {
            shared = []
        }
        let sharedKeys = requested.filter(shared.contains)
        let anyAvailable = candidates.reduce(into: Set<String>()) {
            $0.formUnion(Set($1.weatherByDate.keys).intersection(requestedSet))
        }
        let candidateMetrics = candidates.map { candidate in
            metrics(for: candidate, sharedDateKeys: sharedKeys)
        }
        .sorted { lhs, rhs in
            if lhs.placeName == rhs.placeName { return lhs.candidateID.uuidString < rhs.candidateID.uuidString }
            return lhs.placeName.localizedStandardCompare(rhs.placeName) == .orderedAscending
        }
        let minimumRequired = min(2, requested.count)
        let sufficient = candidates.count >= 2 && minimumRequired > 0 && sharedKeys.count >= minimumRequired
        return DestinationComparisonResult(
            requestedDateKeys: requested,
            sharedAvailableDateKeys: sharedKeys,
            anyAvailableDateKeys: anyAvailable,
            metrics: candidateMetrics,
            tendencies: sufficient ? tendencies(from: candidateMetrics) : [],
            hasSufficientSharedData: sufficient
        )
    }

    static func forecastState(
        result: DestinationComparisonResult,
        startDate: Date,
        endDate: Date,
        lastUpdated: Date?,
        usesStaleData: Bool,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ForecastState {
        let dates = dates(from: startDate, through: endDate, calendar: calendar)
        let availability = ForecastAvailability.evaluate(
            travelDates: dates,
            forecastDates: Set(result.sharedAvailableDateKeys),
            now: now,
            calendar: calendar
        )
        if result.sharedAvailableDateKeys.isEmpty, !result.anyAvailableDateKeys.isEmpty {
            return .partiallyAvailable(
                availableDates: [],
                availableFrom: availability.expectedAvailabilityDate ?? now,
                lastUpdated: lastUpdated
            )
        }
        return ForecastState.resolve(availability: availability, lastUpdated: lastUpdated, usesStaleData: usesStaleData)
    }

    private static func dates(from start: Date, through end: Date, calendar: Calendar) -> [Date] {
        requestedDateKeys(from: start, through: end, calendar: calendar).compactMap { key in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
    }

    private static func metrics(
        for candidate: CandidateForecastInput,
        sharedDateKeys: [String]
    ) -> ComparisonCandidateMetrics {
        let days = sharedDateKeys.compactMap { candidate.weatherByDate[$0] }
        let dryDays = days.filter(isExpectedDry).count
        let advisories = Set(days.flatMap { WeatherAdvisoryEvaluator.advisories(for: $0).map(\.kind) })
        return ComparisonCandidateMetrics(
            candidateID: candidate.candidateID,
            placeName: candidate.placeName,
            comparedDayCount: days.count,
            dryDayCount: dryDays,
            precipitationSum: days.reduce(0) { $0 + $1.precipitationAmount },
            maximumPrecipitationProbability: days.compactMap(\.precipitationProbability).max(),
            minimumTemperature: days.map(\.minimumTemperature).min() ?? 0,
            maximumTemperature: days.map(\.maximumTemperature).max() ?? 0,
            maximumWindSpeed: days.map(\.maximumWindSpeed).max() ?? 0,
            maximumWindGust: days.compactMap(\.maximumWindGust).max(),
            advisories: advisories.sorted { $0.rawValue < $1.rawValue }
        )
    }

    private static func tendencies(from metrics: [ComparisonCandidateMetrics]) -> [ComparisonTendency] {
        guard metrics.count >= 2 else { return [] }
        var result: [ComparisonTendency] = []

        let drySorted = metrics.sorted { lhs, rhs in
            lhs.dryDayCount == rhs.dryDayCount ? lhs.candidateID.uuidString < rhs.candidateID.uuidString : lhs.dryDayCount > rhs.dryDayCount
        }
        if drySorted[0].dryDayCount > drySorted[1].dryDayCount {
            result.append(ComparisonTendency(
                candidateID: drySorted[0].candidateID, placeName: drySorted[0].placeName,
                kind: .moreDryDays(difference: drySorted[0].dryDayCount - drySorted[1].dryDayCount)
            ))
        }

        let rainSorted = metrics.sorted { lhs, rhs in
            lhs.precipitationSum == rhs.precipitationSum ? lhs.candidateID.uuidString < rhs.candidateID.uuidString : lhs.precipitationSum < rhs.precipitationSum
        }
        let rainDifference = rainSorted[1].precipitationSum - rainSorted[0].precipitationSum
        if rainDifference >= 1.0 {
            result.append(ComparisonTendency(
                candidateID: rainSorted[0].candidateID, placeName: rainSorted[0].placeName,
                kind: .lessPrecipitation(difference: rainDifference)
            ))
        }

        let windSorted = metrics.sorted { lhs, rhs in
            lhs.maximumWindSpeed == rhs.maximumWindSpeed ? lhs.candidateID.uuidString < rhs.candidateID.uuidString : lhs.maximumWindSpeed < rhs.maximumWindSpeed
        }
        let windDifference = windSorted[1].maximumWindSpeed - windSorted[0].maximumWindSpeed
        if windDifference >= 5.0 {
            result.append(ComparisonTendency(
                candidateID: windSorted[0].candidateID, placeName: windSorted[0].placeName,
                kind: .lessWind(difference: windDifference)
            ))
        }
        return result
    }
}

enum CandidateToTripConverter {
    static func makeTrip(
        candidate: ComparisonCandidate,
        comparison: DestinationComparison,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Trip {
        let trip = Trip(name: candidate.placeName, createdAt: now, updatedAt: now)
        let segment = TripSegment(
            placeName: candidate.placeName,
            regionName: candidate.regionName,
            countryName: candidate.countryName,
            latitude: candidate.latitude,
            longitude: candidate.longitude,
            timeZoneIdentifier: candidate.timeZoneIdentifier,
            startDate: calendar.startOfDay(for: comparison.startDate),
            endDate: calendar.startOfDay(for: comparison.endDate),
            createdAt: now,
            trip: trip
        )
        trip.segments = [segment]
        return trip
    }
}
