import Combine
import Foundation

enum TripStartFlexibility: String, Codable, CaseIterable, Identifiable, Sendable {
    case exact
    case plusMinusOneDay
    case plusMinusTwoDays

    var id: String { rawValue }

    var offsets: [Int] {
        switch self {
        case .exact: return [0]
        case .plusMinusOneDay: return [-1, 0, 1]
        case .plusMinusTwoDays: return [-2, -1, 0, 1, 2]
        }
    }

    var maximumOffset: Int { offsets.map(abs).max() ?? 0 }
    var localizationKey: String { "trip.flexibility.\(rawValue)" }
}

struct FlexibleTripSegmentSnapshot: Equatable, Sendable {
    let id: UUID
    let placeName: String
    let startDate: Date
    let endDate: Date

    init(segment: TripSegment) {
        id = segment.id
        placeName = segment.placeName
        startDate = segment.startDate
        endDate = segment.endDate
    }

    init(id: UUID = UUID(), placeName: String, startDate: Date, endDate: Date) {
        self.id = id
        self.placeName = placeName
        self.startDate = startDate
        self.endDate = endDate
    }
}

struct TripStartCandidateDraft: Identifiable, Equatable, Sendable {
    let offset: Int
    let startDate: Date
    let shiftedSegments: [FlexibleTripSegmentSnapshot]
    let shiftedTimeline: [TripDay]
    var id: Int { offset }
}

struct BuildFlexibleTripCandidates {
    var calendar: Calendar = .autoupdatingCurrent

    func callAsFunction(
        segments: [FlexibleTripSegmentSnapshot],
        flexibility: TripStartFlexibility
    ) throws -> [TripStartCandidateDraft] {
        guard let originalStart = segments.map(\.startDate).min() else {
            throw TimelineError.emptyTrip
        }
        return try flexibility.offsets.map { offset in
            let shifted = try segments.map { segment in
                guard let start = calendar.date(byAdding: .day, value: offset, to: segment.startDate),
                      let end = calendar.date(byAdding: .day, value: offset, to: segment.endDate) else {
                    throw TimelineError.invalidDateRange
                }
                return FlexibleTripSegmentSnapshot(
                    id: segment.id, placeName: segment.placeName,
                    startDate: calendar.startOfDay(for: start),
                    endDate: calendar.startOfDay(for: end)
                )
            }
            let timeline = try BuildTripTimeline(calendar: calendar)(
                segments: shifted.map {
                    TimelineSegment(
                        id: $0.id, placeName: $0.placeName,
                        startDate: $0.startDate, endDate: $0.endDate
                    )
                }
            )
            guard let shiftedStart = calendar.date(byAdding: .day, value: offset, to: originalStart) else {
                throw TimelineError.invalidDateRange
            }
            return TripStartCandidateDraft(
                offset: offset,
                startDate: calendar.startOfDay(for: shiftedStart),
                shiftedSegments: shifted,
                shiftedTimeline: timeline
            )
        }
    }
}

struct TravelWeatherPreferences: Codable, Equatable, Sendable {
    var avoidsThunderstorms: Bool
    var considersRainProbability: Bool
    var maximumPrecipitationProbability: Int
    var considersPrecipitationAmount: Bool
    var maximumPrecipitationAmount: Double
    var considersWind: Bool
    var maximumWindSpeed: Double
    var considersGusts: Bool
    var maximumWindGust: Double
    var considersCold: Bool
    var minimumComfortableTemperature: Double
    var considersHeat: Bool
    var maximumComfortableTemperature: Double

    static let standard = TravelWeatherPreferences(
        avoidsThunderstorms: true,
        considersRainProbability: true,
        maximumPrecipitationProbability: WeatherAdvisoryThresholds.rainProbability,
        considersPrecipitationAmount: true,
        maximumPrecipitationAmount: WeatherAdvisoryThresholds.precipitationMillimeters,
        considersWind: true,
        maximumWindSpeed: WeatherAdvisoryThresholds.windKilometersPerHour,
        considersGusts: true,
        maximumWindGust: WeatherAdvisoryThresholds.gustKilometersPerHour,
        considersCold: true,
        minimumComfortableTemperature: 5,
        considersHeat: true,
        maximumComfortableTemperature: WeatherAdvisoryThresholds.heatCelsius
    )
}

enum TravelWeatherPreferencesStore {
    static let key = "travelWeatherPreferences.v1"

    static func load(defaults: UserDefaults = .standard) -> TravelWeatherPreferences {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(TravelWeatherPreferences.self, from: data) else {
            return .standard
        }
        return value
    }

    static func save(_ value: TravelWeatherPreferences, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
final class TravelWeatherPreferencesModel: ObservableObject {
    @Published var value: TravelWeatherPreferences {
        didSet { TravelWeatherPreferencesStore.save(value, defaults: defaults) }
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.value = TravelWeatherPreferencesStore.load(defaults: defaults)
    }

    func restoreDefaults() { value = .standard }
}

enum TripStartForecastState: Equatable, Sendable {
    case complete
    case partial(availableDays: Int, totalDays: Int, expectedAvailabilityDate: Date?)
    case unavailable(expectedAvailabilityDate: Date?)
}

enum TripStartAssessmentLevel: String, Equatable, Sendable {
    case recommended
    case favorable
    case mixed
    case unfavorable
    case unavailable

    var localizationKey: String { "trip.flexible.assessment.\(rawValue)" }
    var symbolName: String {
        switch self {
        case .recommended: return "star.fill"
        case .favorable: return "checkmark.circle.fill"
        case .mixed: return "cloud.sun.fill"
        case .unfavorable: return "exclamationmark.triangle.fill"
        case .unavailable: return "calendar.badge.clock"
        }
    }
}

enum TripWeatherViolationKind: String, CaseIterable, Sendable {
    case thunderstorm
    case rainProbability
    case precipitationAmount
    case wind
    case gust
    case cold
    case heat
}

struct TripWeatherViolation: Equatable, Sendable {
    let kind: TripWeatherViolationKind
    let date: Date
    let placeName: String
    let value: Double?
    let threshold: Double?
    let normalizedExcess: Double
}

enum TripRecommendationReason: Equatable, Sendable {
    case noThresholdExceeded
    case thunderstorm(dayCount: Int)
    case rainProbability(dayCount: Int, maximum: Int)
    case precipitation(dayCount: Int, maximum: Double)
    case wind(dayCount: Int, maximum: Double)
    case gust(dayCount: Int, maximum: Double)
    case cold(dayCount: Int, minimum: Double)
    case heat(dayCount: Int, maximum: Double)
    case incomplete(availableDays: Int, totalDays: Int)
}

struct TripStartCandidateAssessment: Equatable, Sendable {
    let level: TripStartAssessmentLevel
    let violations: [TripWeatherViolation]
    let affectedDayCount: Int
    let severity: Double
    let reasons: [TripRecommendationReason]
}

struct TripStartCandidate: Identifiable, Equatable, Sendable {
    let draft: TripStartCandidateDraft
    let forecastState: TripStartForecastState
    let availableDayCount: Int
    let assessment: TripStartCandidateAssessment

    var id: Int { draft.offset }
    var offset: Int { draft.offset }
    var startDate: Date { draft.startDate }
    var shiftedTimeline: [TripDay] { draft.shiftedTimeline }
    var isFullyAssessable: Bool {
        if case .complete = forecastState { return assessment.level != .unavailable }
        return false
    }
}

struct FlexibleTripStartComparison: Equatable, Sendable {
    let candidates: [TripStartCandidate]
    let recommendedOffset: Int?
    let preferredDisplayOffset: Int
    let hasFairCommonBasis: Bool
    let differencesAreSmall: Bool

    func candidate(offset: Int) -> TripStartCandidate? {
        candidates.first { $0.offset == offset }
    }
}

enum EvaluateTripStartCandidate {
    static func callAsFunction(
        _ draft: TripStartCandidateDraft,
        weatherByDay: [WeatherDayKey: WeatherDay],
        preferences: TravelWeatherPreferences,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TripStartCandidate {
        var detectedViolations: [TripWeatherViolation] = []
        var availableRows = 0
        var fullyEvaluableRows = 0

        for day in draft.shiftedTimeline {
            let key = WeatherDayKey(
                segmentID: day.segmentID,
                dateISO: WeatherDateKey.make(from: day.date, calendar: calendar)
            )
            guard let weather = weatherByDay[key] else { continue }
            availableRows += 1
            guard hasRequiredValues(weather, preferences: preferences) else { continue }
            fullyEvaluableRows += 1
            detectedViolations.append(contentsOf: violations(
                weather: weather, date: day.date, placeName: day.placeName,
                preferences: preferences
            ))
        }

        let totalRows = draft.shiftedTimeline.count
        let incompleteDates = draft.shiftedTimeline.compactMap { day -> Date? in
            let key = WeatherDayKey(
                segmentID: day.segmentID,
                dateISO: WeatherDateKey.make(from: day.date, calendar: calendar)
            )
            guard let weather = weatherByDay[key],
                  hasRequiredValues(weather, preferences: preferences) else {
                return day.date
            }
            return nil
        }
        let firstIncompleteFutureDate = incompleteDates
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 >= calendar.startOfDay(for: now) }
            .min()
        let expectedAvailabilityDate = firstIncompleteFutureDate.flatMap {
            calendar.date(
                byAdding: .day,
                value: -(ForecastAvailability.forecastDayCount - 1),
                to: $0
            )
        }.map { max(calendar.startOfDay(for: now), $0) }
        let forecastState: TripStartForecastState
        if availableRows == totalRows, fullyEvaluableRows == totalRows {
            forecastState = .complete
        } else if availableRows > 0 {
            forecastState = .partial(
                availableDays: availableRows,
                totalDays: totalRows,
                expectedAvailabilityDate: expectedAvailabilityDate
            )
        } else {
            forecastState = .unavailable(expectedAvailabilityDate: expectedAvailabilityDate)
        }

        guard case .complete = forecastState else {
            return TripStartCandidate(
                draft: draft,
                forecastState: forecastState,
                availableDayCount: availableRows,
                assessment: TripStartCandidateAssessment(
                    level: .unavailable, violations: [],
                    affectedDayCount: 0, severity: 0,
                    reasons: [.incomplete(availableDays: availableRows, totalDays: totalRows)]
                )
            )
        }

        let affectedDays = Set(detectedViolations.map {
            WeatherDateKey.make(from: $0.date, calendar: calendar)
        }).count
        let hasThunderstorm = detectedViolations.contains { $0.kind == .thunderstorm }
        let level: TripStartAssessmentLevel
        if detectedViolations.isEmpty {
            level = .favorable
        } else if hasThunderstorm || detectedViolations.count >= 3 || affectedDays >= 2 {
            level = .unfavorable
        } else {
            level = .mixed
        }
        return TripStartCandidate(
            draft: draft,
            forecastState: forecastState,
            availableDayCount: availableRows,
            assessment: TripStartCandidateAssessment(
                level: level,
                violations: detectedViolations,
                affectedDayCount: affectedDays,
                severity: detectedViolations.reduce(0) { $0 + $1.normalizedExcess },
                reasons: reasons(for: detectedViolations, calendar: calendar)
            )
        )
    }

    private static func hasRequiredValues(
        _ weather: WeatherDay,
        preferences: TravelWeatherPreferences
    ) -> Bool {
        if preferences.considersRainProbability, weather.precipitationProbability == nil { return false }
        if preferences.considersGusts, weather.maximumWindGust == nil { return false }
        return true
    }

    private static func violations(
        weather: WeatherDay,
        date: Date,
        placeName: String,
        preferences: TravelWeatherPreferences
    ) -> [TripWeatherViolation] {
        var result: [TripWeatherViolation] = []
        if preferences.avoidsThunderstorms, [95, 96, 99].contains(weather.weatherCode) {
            result.append(.init(
                kind: .thunderstorm, date: date, placeName: placeName,
                value: nil, threshold: nil, normalizedExcess: 1
            ))
        }
        if preferences.considersRainProbability,
           let value = weather.precipitationProbability,
           value >= preferences.maximumPrecipitationProbability {
            result.append(.init(
                kind: .rainProbability, date: date, placeName: placeName,
                value: Double(value), threshold: Double(preferences.maximumPrecipitationProbability),
                normalizedExcess: normalized(Double(value), threshold: Double(preferences.maximumPrecipitationProbability))
            ))
        }
        if preferences.considersPrecipitationAmount,
           weather.precipitationAmount >= preferences.maximumPrecipitationAmount {
            result.append(.init(
                kind: .precipitationAmount, date: date, placeName: placeName,
                value: weather.precipitationAmount, threshold: preferences.maximumPrecipitationAmount,
                normalizedExcess: normalized(weather.precipitationAmount, threshold: preferences.maximumPrecipitationAmount)
            ))
        }
        if preferences.considersWind, weather.maximumWindSpeed >= preferences.maximumWindSpeed {
            result.append(.init(
                kind: .wind, date: date, placeName: placeName,
                value: weather.maximumWindSpeed, threshold: preferences.maximumWindSpeed,
                normalizedExcess: normalized(weather.maximumWindSpeed, threshold: preferences.maximumWindSpeed)
            ))
        }
        if preferences.considersGusts,
           let value = weather.maximumWindGust,
           value >= preferences.maximumWindGust {
            result.append(.init(
                kind: .gust, date: date, placeName: placeName,
                value: value, threshold: preferences.maximumWindGust,
                normalizedExcess: normalized(value, threshold: preferences.maximumWindGust)
            ))
        }
        if preferences.considersCold, weather.minimumTemperature <= preferences.minimumComfortableTemperature {
            result.append(.init(
                kind: .cold, date: date, placeName: placeName,
                value: weather.minimumTemperature, threshold: preferences.minimumComfortableTemperature,
                normalizedExcess: max(
                    0,
                    (preferences.minimumComfortableTemperature - weather.minimumTemperature)
                        / max(abs(preferences.minimumComfortableTemperature), 10)
                )
            ))
        }
        if preferences.considersHeat, weather.maximumTemperature >= preferences.maximumComfortableTemperature {
            result.append(.init(
                kind: .heat, date: date, placeName: placeName,
                value: weather.maximumTemperature, threshold: preferences.maximumComfortableTemperature,
                normalizedExcess: normalized(weather.maximumTemperature, threshold: preferences.maximumComfortableTemperature)
            ))
        }
        return result
    }

    private static func normalized(_ value: Double, threshold: Double) -> Double {
        guard threshold != 0 else { return abs(value) }
        return max(0, (value - threshold) / abs(threshold))
    }

    private static func reasons(
        for violations: [TripWeatherViolation],
        calendar: Calendar
    ) -> [TripRecommendationReason] {
        guard !violations.isEmpty else { return [.noThresholdExceeded] }
        var result: [TripRecommendationReason] = []
        let grouped = Dictionary(grouping: violations, by: \.kind)
        func dayCount(_ values: [TripWeatherViolation]) -> Int {
            Set(values.map { WeatherDateKey.make(from: $0.date, calendar: calendar) }).count
        }
        if let values = grouped[.thunderstorm] {
            result.append(.thunderstorm(dayCount: dayCount(values)))
        }
        if let values = grouped[.rainProbability] {
            result.append(.rainProbability(
                dayCount: dayCount(values),
                maximum: Int(values.compactMap(\.value).max() ?? 0)
            ))
        }
        if let values = grouped[.precipitationAmount] {
            result.append(.precipitation(
                dayCount: dayCount(values), maximum: values.compactMap(\.value).max() ?? 0
            ))
        }
        if let values = grouped[.wind] {
            result.append(.wind(dayCount: dayCount(values), maximum: values.compactMap(\.value).max() ?? 0))
        }
        if let values = grouped[.gust] {
            result.append(.gust(dayCount: dayCount(values), maximum: values.compactMap(\.value).max() ?? 0))
        }
        if let values = grouped[.cold] {
            result.append(.cold(dayCount: dayCount(values), minimum: values.compactMap(\.value).min() ?? 0))
        }
        if let values = grouped[.heat] {
            result.append(.heat(dayCount: dayCount(values), maximum: values.compactMap(\.value).max() ?? 0))
        }
        return result
    }
}

enum SelectRecommendedStartCandidate {
    static func callAsFunction(candidates: [TripStartCandidate]) -> FlexibleTripStartComparison {
        let chronological = candidates.sorted { $0.offset < $1.offset }
        let fair = !chronological.isEmpty && chronological.allSatisfy(\.isFullyAssessable)
        guard fair else {
            return FlexibleTripStartComparison(
                candidates: chronological, recommendedOffset: nil,
                preferredDisplayOffset: 0, hasFairCommonBasis: false,
                differencesAreSmall: false
            )
        }

        let sorted = chronological.sorted {
            let lhs = Rank(candidate: $0)
            let rhs = Rank(candidate: $1)
            if lhs == rhs {
                if $0.offset == 0 { return true }
                if $1.offset == 0 { return false }
                return $0.offset < $1.offset
            }
            return lhs < rhs
        }
        guard let best = sorted.first else {
            return FlexibleTripStartComparison(
                candidates: chronological, recommendedOffset: nil,
                preferredDisplayOffset: 0, hasFairCommonBasis: true,
                differencesAreSmall: true
            )
        }
        guard sorted.count > 1 else {
            return FlexibleTripStartComparison(
                candidates: chronological, recommendedOffset: best.offset,
                preferredDisplayOffset: best.offset, hasFairCommonBasis: true,
                differencesAreSmall: false
            )
        }

        let bestRank = Rank(candidate: best)
        let secondRank = Rank(candidate: sorted[1])
        let smallDifference = bestRank.violationCount == secondRank.violationCount
            && bestRank.affectedDayCount == secondRank.affectedDayCount
            && abs(bestRank.severity - secondRank.severity) < 0.15
        return FlexibleTripStartComparison(
            candidates: chronological,
            recommendedOffset: smallDifference ? nil : best.offset,
            preferredDisplayOffset: smallDifference ? 0 : best.offset,
            hasFairCommonBasis: true,
            differencesAreSmall: smallDifference
        )
    }

    private struct Rank: Equatable, Comparable {
        let violationCount: Int
        let affectedDayCount: Int
        let severity: Double

        init(candidate: TripStartCandidate) {
            violationCount = candidate.assessment.violations.count
            affectedDayCount = candidate.assessment.affectedDayCount
            severity = candidate.assessment.severity
        }

        static func < (lhs: Rank, rhs: Rank) -> Bool {
            if lhs.violationCount != rhs.violationCount { return lhs.violationCount < rhs.violationCount }
            if lhs.affectedDayCount != rhs.affectedDayCount { return lhs.affectedDayCount < rhs.affectedDayCount }
            return lhs.severity < rhs.severity
        }
    }
}

enum FlexibleTripStartEngine {
    static func compare(
        segments: [FlexibleTripSegmentSnapshot],
        flexibility: TripStartFlexibility,
        weatherByDay: [WeatherDayKey: WeatherDay],
        preferences: TravelWeatherPreferences,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> FlexibleTripStartComparison {
        let drafts = (try? BuildFlexibleTripCandidates(calendar: calendar)(
            segments: segments, flexibility: flexibility
        )) ?? []
        let candidates = drafts.map {
            EvaluateTripStartCandidate.callAsFunction(
                $0, weatherByDay: weatherByDay, preferences: preferences,
                now: now, calendar: calendar
            )
        }
        return SelectRecommendedStartCandidate.callAsFunction(candidates: candidates)
    }
}
