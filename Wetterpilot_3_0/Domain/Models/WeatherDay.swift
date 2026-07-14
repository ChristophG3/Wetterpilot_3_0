import Foundation

struct WeatherDay: Equatable, Sendable {
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
        sunsetISO: String? = nil
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
    }

    var symbol: String {
        switch weatherCode {
        case 0: return "☀️"
        case 1, 2: return "🌤️"
        case 3: return "☁️"
        case 45, 48: return "🌫️"
        case 51, 53, 55, 56, 57: return "🌦️"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "🌧️"
        case 71, 73, 75, 77, 85, 86: return "❄️"
        case 95, 96, 99: return "⛈️"
        default: return "🌡️"
        }
    }

    var conditionText: String {
        switch weatherCode {
        case 0: return "Klarer Himmel"
        case 1: return "Überwiegend klar"
        case 2: return "Teilweise bewölkt"
        case 3: return "Bewölkt"
        case 45, 48: return "Nebel"
        case 51, 53, 55, 56, 57: return "Nieselregen"
        case 61, 63, 65, 66, 67: return "Regen"
        case 71, 73, 75, 77, 85, 86: return "Schnee"
        case 80, 81, 82: return "Regenschauer"
        case 95, 96, 99: return "Gewitter"
        default: return "Wechselhaft"
        }
    }

    var sunriseTime: String? { Self.time(from: sunriseISO) }
    var sunsetTime: String? { Self.time(from: sunsetISO) }

    private static func time(from iso: String?) -> String? {
        guard let iso, let time = iso.split(separator: "T").last else { return nil }
        return String(time.prefix(5))
    }
}

struct WeatherDayKey: Hashable {
    let segmentID: UUID
    let dateISO: String
}

enum WeatherDateKey {
    static func make(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
