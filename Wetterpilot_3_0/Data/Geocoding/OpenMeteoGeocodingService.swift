import Foundation

struct GeocodedPlace: Identifiable, Hashable, Sendable {
    let name: String
    let regionName: String?
    let countryName: String?
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String?

    var id: String {
        "\(name)-\(latitude)-\(longitude)"
    }

    var subtitle: String {
        [regionName, countryName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

enum GeocodingError: LocalizedError {
    case invalidURL
    case placeNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Die Ortssuche konnte nicht gestartet werden."
        case .placeNotFound(let place):
            return "Der Ort „\(place)“ wurde nicht gefunden."
        }
    }
}

struct OpenMeteoGeocodingService {
    let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    func geocode(_ query: String) async throws -> GeocodedPlace {
        guard let place = try await suggestions(for: query, limit: 1).first else {
            throw GeocodingError.placeNotFound(query)
        }
        return place
    }

    func suggestions(for query: String, limit: Int = 5) async throws -> [GeocodedPlace] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: String(max(1, min(limit, 10)))),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { throw GeocodingError.invalidURL }

        struct Response: Decodable {
            struct Result: Decodable {
                let name: String
                let admin1: String?
                let country: String?
                let latitude: Double
                let longitude: Double
                let timezone: String?
            }
            let results: [Result]?
        }

        let data = try await client.data(from: url)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.results ?? []).map { result in
            GeocodedPlace(
                name: result.name,
                regionName: result.admin1,
                countryName: result.country,
                latitude: result.latitude,
                longitude: result.longitude,
                timeZoneIdentifier: result.timezone
            )
        }
    }
}
