import Foundation

struct ForecastDay: Codable, Hashable, Identifiable {
    var id: String { dateISO + placeID }
    let placeID: String
    let dateISO: String // yyyy-MM-dd
    let tMin: Double
    let tMax: Double
    let rainMM: Double
    let sunHours: Double
    let windKmh: Double
    let weatherCode: Int
}

typealias DailyByDate = [String: [ForecastDay]] // dateISO -> [place days]

enum WeatherEmoji {
    static func emoji(for code: Int) -> String {
        switch code {
        case 0: return "☀️"
        case 1,2,3: return "🌤️"
        case 45,48: return "🌫️"
        case 51,53,55,56,57: return "🌦️"
        case 61,63,65: return "🌧️"
        case 66,67,71,73,75,77,85,86: return "❄️"
        case 80,81,82: return "🌧️"
        case 95,96,99: return "⛈️"
        default: return "🌡️"
        }
    }
}
