import Foundation

struct WeatherHour: Codable, Equatable, Sendable, Identifiable {
    let timeISO: String
    let temperature: Double
    let apparentTemperature: Double
    let precipitationProbability: Int?
    let precipitationAmount: Double
    let weatherCode: Int
    let windSpeed: Double
    let windGust: Double

    var id: String { timeISO }
}

struct WeatherDay: Codable, Equatable, Sendable {
    let dateISO: String
    let weatherCode: Int
    let minimumTemperature: Double
    let maximumTemperature: Double
    let precipitationProbability: Int?
    let precipitationAmount: Double
    let maximumWindSpeed: Double
    let minimumApparentTemperature: Double?
    let maximumApparentTemperature: Double?
    let maximumWindGust: Double?
    let maximumUVIndex: Double?
    let sunriseISO: String?
    let sunsetISO: String?
    let hours: [WeatherHour]

    init(
        dateISO: String,
        weatherCode: Int,
        minimumTemperature: Double,
        maximumTemperature: Double,
        precipitationProbability: Int?,
        precipitationAmount: Double,
        maximumWindSpeed: Double,
        minimumApparentTemperature: Double? = nil,
        maximumApparentTemperature: Double? = nil,
        maximumWindGust: Double? = nil,
        maximumUVIndex: Double? = nil,
        sunriseISO: String? = nil,
        sunsetISO: String? = nil,
        hours: [WeatherHour] = []
    ) {
        self.dateISO = dateISO
        self.weatherCode = weatherCode
        self.minimumTemperature = minimumTemperature
        self.maximumTemperature = maximumTemperature
        self.precipitationProbability = precipitationProbability
        self.precipitationAmount = precipitationAmount
        self.maximumWindSpeed = maximumWindSpeed
        self.minimumApparentTemperature = minimumApparentTemperature
        self.maximumApparentTemperature = maximumApparentTemperature
        self.maximumWindGust = maximumWindGust
        self.maximumUVIndex = maximumUVIndex
        self.sunriseISO = sunriseISO
        self.sunsetISO = sunsetISO
        self.hours = hours
    }

    var symbolName: String { WeatherCondition.symbolName(for: weatherCode) }
    var conditionLocalizationKey: String { WeatherCondition.localizationKey(for: weatherCode) }
    var sunriseTime: String? { Self.time(from: sunriseISO) }
    var sunsetTime: String? { Self.time(from: sunsetISO) }

    private static func time(from iso: String?) -> String? {
        guard let iso, let time = iso.split(separator: "T").last else { return nil }
        return String(time.prefix(5))
    }
}

enum WeatherCondition {
    static func symbolName(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func localizationKey(for code: Int) -> String {
        switch code {
        case 0: return "weather.condition.clear"
        case 1: return "weather.condition.mainlyClear"
        case 2: return "weather.condition.partlyCloudy"
        case 3: return "weather.condition.cloudy"
        case 45, 48: return "weather.condition.fog"
        case 51, 53, 55, 56, 57: return "weather.condition.drizzle"
        case 61, 63, 65, 66, 67: return "weather.condition.rain"
        case 71, 73, 75, 77, 85, 86: return "weather.condition.snow"
        case 80, 81, 82: return "weather.condition.showers"
        case 95, 96, 99: return "weather.condition.thunderstorm"
        default: return "weather.condition.variable"
        }
    }
}

struct WeatherDayKey: Hashable {
    let segmentID: UUID
    let dateISO: String
}

enum WeatherDateKey {
    static func make(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

enum ForecastState: Equatable, Sendable {
    case loading
    case available(lastUpdated: Date)
    case partiallyAvailable(availableDates: Set<String>, availableFrom: Date, lastUpdated: Date?)
    case outsideForecastRange(availableFrom: Date)
    case stale(lastUpdated: Date)
    case failed

    static func resolve(
        availability: ForecastAvailability,
        lastUpdated: Date?,
        usesStaleData: Bool
    ) -> ForecastState {
        if !availability.availableDates.isEmpty,
           availability.unavailableDates.isEmpty,
           let lastUpdated {
            return usesStaleData ? .stale(lastUpdated: lastUpdated) : .available(lastUpdated: lastUpdated)
        }
        if !availability.availableDates.isEmpty {
            return .partiallyAvailable(
                availableDates: availability.availableDates,
                availableFrom: availability.expectedAvailabilityDate ?? .now,
                lastUpdated: lastUpdated
            )
        }
        if let expected = availability.expectedAvailabilityDate {
            return .outsideForecastRange(availableFrom: expected)
        }
        return .failed
    }
}

struct ForecastAvailability: Equatable, Sendable {
    static let forecastDayCount = 16

    let availableDates: Set<String>
    let unavailableDates: Set<String>
    let expectedAvailabilityDate: Date?

    static func evaluate(
        travelDates: [Date],
        forecastDates: Set<String>,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ForecastAvailability {
        let uniqueDays = Set(travelDates.map { calendar.startOfDay(for: $0) })
        let keys = Set(uniqueDays.map { WeatherDateKey.make(from: $0, calendar: calendar) })
        let available = keys.intersection(forecastDates)
        let unavailable = keys.subtracting(available)
        let firstUnavailableFuture = uniqueDays
            .filter { !available.contains(WeatherDateKey.make(from: $0, calendar: calendar)) }
            .filter { $0 >= calendar.startOfDay(for: now) }
            .min()
        let expected = firstUnavailableFuture.flatMap {
            calendar.date(byAdding: .day, value: -(forecastDayCount - 1), to: $0)
        }
        return ForecastAvailability(
            availableDates: available,
            unavailableDates: unavailable,
            expectedAvailabilityDate: expected.map { max(calendar.startOfDay(for: now), $0) }
        )
    }
}

enum WeatherAdvisoryKind: String, CaseIterable, Sendable {
    case highRainProbability
    case heavyPrecipitation
    case strongWind
    case strongGusts
    case thunderstorm
    case highHeat
    case highUV

    var localizationKey: String { "weather.advisory.\(rawValue)" }
    var symbolName: String {
        switch self {
        case .highRainProbability, .heavyPrecipitation: return "cloud.rain.fill"
        case .strongWind: return "wind"
        case .strongGusts: return "tornado"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .highHeat: return "thermometer.high"
        case .highUV: return "sun.max.trianglebadge.exclamationmark.fill"
        }
    }
}

struct WeatherAdvisory: Identifiable, Equatable, Sendable {
    let kind: WeatherAdvisoryKind
    var id: WeatherAdvisoryKind { kind }
}

enum WeatherAdvisoryThresholds {
    static let rainProbability = 70
    static let precipitationMillimeters = 10.0
    static let windKilometersPerHour = 40.0
    static let gustKilometersPerHour = 60.0
    static let heatCelsius = 32.0
    static let uvIndex = 8.0
}

enum WeatherAdvisoryEvaluator {
    static func advisories(for weather: WeatherDay) -> [WeatherAdvisory] {
        var kinds: [WeatherAdvisoryKind] = []
        if (weather.precipitationProbability ?? 0) >= WeatherAdvisoryThresholds.rainProbability { kinds.append(.highRainProbability) }
        if weather.precipitationAmount >= WeatherAdvisoryThresholds.precipitationMillimeters { kinds.append(.heavyPrecipitation) }
        if weather.maximumWindSpeed >= WeatherAdvisoryThresholds.windKilometersPerHour { kinds.append(.strongWind) }
        if (weather.maximumWindGust ?? 0) >= WeatherAdvisoryThresholds.gustKilometersPerHour { kinds.append(.strongGusts) }
        if [95, 96, 99].contains(weather.weatherCode) { kinds.append(.thunderstorm) }
        if weather.maximumTemperature >= WeatherAdvisoryThresholds.heatCelsius { kinds.append(.highHeat) }
        if (weather.maximumUVIndex ?? 0) >= WeatherAdvisoryThresholds.uvIndex { kinds.append(.highUV) }
        return kinds.map(WeatherAdvisory.init)
    }
}

enum HourlyWeatherSummary: Equatable, Sendable {
    case mostlyDry
    case rainFrom(hour: Int)
    case showersPossible
    case unavailable

    static func evaluate(_ hours: [WeatherHour]) -> HourlyWeatherSummary {
        guard !hours.isEmpty else { return .unavailable }
        let relevant = hours.filter { hourValue($0.timeISO) >= 6 }
        guard let firstWet = relevant.first(where: { ($0.precipitationProbability ?? 0) >= 50 || $0.precipitationAmount >= 0.2 }) else {
            return .mostlyDry
        }
        let hour = hourValue(firstWet.timeISO)
        return hour >= 12 ? .rainFrom(hour: hour) : .showersPossible
    }

    private static func hourValue(_ iso: String) -> Int {
        guard let time = iso.split(separator: "T").last,
              let hour = Int(time.split(separator: ":").first ?? "") else { return 0 }
        return hour
    }
}

enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit
    var id: String { rawValue }
    func value(fromCelsius value: Double) -> Double { self == .celsius ? value : value * 9 / 5 + 32 }
    var symbol: String { self == .celsius ? "°C" : "°F" }
}

enum WindSpeedUnit: String, CaseIterable, Identifiable {
    case kilometersPerHour
    case milesPerHour
    var id: String { rawValue }
    func value(fromKilometersPerHour value: Double) -> Double { self == .kilometersPerHour ? value : value * 0.621371 }
    var symbol: String { self == .kilometersPerHour ? "km/h" : "mph" }
}
