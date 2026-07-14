import Foundation

enum WeatherServiceError: LocalizedError {
    case invalidURL
    case malformedForecast

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Die Wetterabfrage konnte nicht erstellt werden."
        case .malformedForecast:
            return "Die Wetterdaten sind unvollständig."
        }
    }
}

struct OpenMeteoWeatherService {
    let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    func forecast(latitude: Double, longitude: Double) async throws -> [WeatherDay] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.5f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.5f", longitude)),
            URLQueryItem(name: "forecast_days", value: "16"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(
                name: "daily",
                value: [
                    "weather_code",
                    "temperature_2m_min",
                    "temperature_2m_max",
                    "apparent_temperature_min",
                    "apparent_temperature_max",
                    "precipitation_probability_max",
                    "precipitation_sum",
                    "wind_speed_10m_max",
                    "wind_gusts_10m_max",
                    "uv_index_max",
                    "sunrise",
                    "sunset"
                ].joined(separator: ",")
            ),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
            URLQueryItem(name: "precipitation_unit", value: "mm")
        ]
        guard let url = components?.url else { throw WeatherServiceError.invalidURL }
        let data = try await client.data(from: url)
        return try Self.decodeForecast(data)
    }

    static func decodeForecast(_ data: Data) throws -> [WeatherDay] {
        struct Response: Decodable {
            struct Daily: Decodable {
                let time: [String]
                let weatherCode: [Int?]
                let minimumTemperature: [Double?]
                let maximumTemperature: [Double?]
                let precipitationProbability: [Int?]
                let precipitationAmount: [Double?]
                let maximumWindSpeed: [Double?]
                let minimumApparentTemperature: [Double?]?
                let maximumApparentTemperature: [Double?]?
                let maximumWindGust: [Double?]?
                let maximumUVIndex: [Double?]?
                let sunrise: [String?]?
                let sunset: [String?]?

                enum CodingKeys: String, CodingKey {
                    case time
                    case weatherCode = "weather_code"
                    case minimumTemperature = "temperature_2m_min"
                    case maximumTemperature = "temperature_2m_max"
                    case minimumApparentTemperature = "apparent_temperature_min"
                    case maximumApparentTemperature = "apparent_temperature_max"
                    case precipitationProbability = "precipitation_probability_max"
                    case precipitationAmount = "precipitation_sum"
                    case maximumWindSpeed = "wind_speed_10m_max"
                    case maximumWindGust = "wind_gusts_10m_max"
                    case maximumUVIndex = "uv_index_max"
                    case sunrise
                    case sunset
                }
            }
            let daily: Daily
        }

        let daily = try JSONDecoder().decode(Response.self, from: data).daily
        let forecast = daily.time.indices.compactMap { index -> WeatherDay? in
            // Open-Meteo can return nulls for the least certain day at the end of
            // the forecast. Keep all complete days instead of rejecting the
            // otherwise valid response.
            guard let code = value(in: daily.weatherCode, at: index),
                  let minimum = value(in: daily.minimumTemperature, at: index),
                  let maximum = value(in: daily.maximumTemperature, at: index),
                  let precipitation = value(in: daily.precipitationAmount, at: index),
                  let wind = value(in: daily.maximumWindSpeed, at: index) else {
                return nil
            }
            return WeatherDay(
                dateISO: daily.time[index],
                weatherCode: code,
                minimumTemperature: minimum,
                maximumTemperature: maximum,
                precipitationProbability: value(in: daily.precipitationProbability, at: index),
                precipitationAmount: precipitation,
                maximumWindSpeed: wind,
                minimumApparentTemperature: value(in: daily.minimumApparentTemperature, at: index),
                maximumApparentTemperature: value(in: daily.maximumApparentTemperature, at: index),
                maximumWindGust: value(in: daily.maximumWindGust, at: index),
                maximumUVIndex: value(in: daily.maximumUVIndex, at: index),
                sunriseISO: value(in: daily.sunrise, at: index),
                sunsetISO: value(in: daily.sunset, at: index)
            )
        }

        guard !forecast.isEmpty else {
            throw WeatherServiceError.malformedForecast
        }
        return forecast
    }

    private static func value<T>(in values: [T?]?, at index: Int) -> T? {
        guard let values, values.indices.contains(index) else { return nil }
        return values[index]
    }
}
