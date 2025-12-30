import Foundation
import CoreLocation

protocol WeatherProvider {
    func fetchDaily(lat: Double, lon: Double) async throws -> [ForecastDay]
}

final class OpenMeteoWeatherProvider: WeatherProvider {
    private let network: NetworkClient
    private let caches: Caches

    /// 24h Cache – ok, weil Open-Meteo Tageswerte liefert
    private let ttl: TimeInterval = 60 * 60 * 24

    /// Maximaler Vorhersagehorizont von Open-Meteo (inkl. heute)
    private let maxForecastDays = 16

    init(network: NetworkClient, caches: Caches) {
        self.network = network
        self.caches = caches
    }

    func fetchDaily(lat: Double, lon: Double) async throws -> [ForecastDay] {
        // v2: Cache-Key versionieren + Tage anhängen, um alte (kürzere) Antworten zu vermeiden
        let key = String(format: "v2_forecast_%0.5f_%0.5f_days_%d", lat, lon, maxForecastDays)

        if let d = caches.memory.get(key) ?? caches.disk.get(key),
           let arr = try? JSONDecoder().decode([ForecastDay].self, from: d) {
            return arr
        }

        // Request: 16 Tage, timezone=auto, metrische Einheiten
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(format: "%.5f", lat)),
            .init(name: "longitude", value: String(format: "%.5f", lon)),
            .init(name: "forecast_days", value: "\(maxForecastDays)"),
            .init(name: "timezone", value: "auto"),
            .init(name: "daily", value: [
                "weathercode",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_sum",
                "windspeed_10m_max",
                "sunshine_duration"
            ].joined(separator: ",")),
            .init(name: "windspeed_unit", value: "kmh"),
            .init(name: "precipitation_unit", value: "mm")
        ]

        guard let url = comps.url else { throw NetworkClient.NetError.badURL }
        let data = try await network.get(url: url)

        // --- Decoding ---
        struct R: Codable {
            struct Daily: Codable {
                let time: [String]                     // "yyyy-MM-dd"
                let weathercode: [Int]
                let temperature_2m_min: [Double]
                let temperature_2m_max: [Double]
                let precipitation_sum: [Double]
                let windspeed_10m_max: [Double]
                let sunshine_duration: [Double]?       // optional in manchen Regionen
            }
            let daily: Daily
        }

        let r = try JSONDecoder().decode(R.self, from: data)
        let d = r.daily

        // --- Defensive length checks ---
        let c = d.time.count
        guard c > 0,
              d.weathercode.count == c,
              d.temperature_2m_min.count == c,
              d.temperature_2m_max.count == c,
              d.precipitation_sum.count == c,
              d.windspeed_10m_max.count == c,
              (d.sunshine_duration?.count ?? c) == c
        else {
            // Inkonsistente Antwort – lieber leer als Crash
            return []
        }

        var out: [ForecastDay] = []
        out.reserveCapacity(c)

        for i in 0..<c {
            let sunH = (d.sunshine_duration?[i] ?? 0.0) / 3600.0 // Sekunden → Stunden
            out.append(
                ForecastDay(
                    placeID: "",                       // RouteVM kann das später befüllen
                    dateISO: d.time[i],                // z. B. "2025-10-05"
                    tMin: d.temperature_2m_min[i],
                    tMax: d.temperature_2m_max[i],
                    rainMM: d.precipitation_sum[i],
                    sunHours: sunH,
                    windKmh: d.windspeed_10m_max[i],
                    weatherCode: d.weathercode[i]
                )
            )
        }

        // Cache schreiben
        if let enc = try? JSONEncoder().encode(out) {
            caches.memory.set(key, data: enc, ttl: ttl)
            caches.disk.set(key, data: enc, ttl: ttl)
        }

        #if DEBUG
        print("[OpenMeteo] fetched \(out.count) daily rows (lat=\(lat), lon=\(lon))")
        #endif

        return out
    }
}
