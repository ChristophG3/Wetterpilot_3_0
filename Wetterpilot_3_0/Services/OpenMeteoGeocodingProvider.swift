import Foundation

protocol GeocodingProvider {
    func geocode(_ name: String) async throws -> GeoPlace
    func suggest(prefix: String, language: String, limit: Int) async throws -> [GeoPlace]
}

final class OpenMeteoGeocodingProvider: GeocodingProvider {
    private let network: NetworkClient
    private let caches: Caches
    private let ttl: TimeInterval = 60 * 60 * 24

    init(network: NetworkClient, caches: Caches) {
        self.network = network
        self.caches = caches
    }

    func geocode(_ name: String) async throws -> GeoPlace {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "geocode::\(trimmed.lowercased())"
        if let d = caches.memory.get(key) ?? caches.disk.get(key),
           let g = try? JSONDecoder().decode(GeoPlace.self, from: d) { return g }

        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [ .init(name: "name", value: trimmed), .init(name: "count", value: "1") ]
        guard let url = comps.url else { throw NetworkClient.NetError.badURL }

        let data = try await network.get(url: url)
        struct R: Codable { struct Res: Codable { let name, country_code: String; let latitude, longitude: Double; let admin1: String? }; let results: [Res]? }
        let r = try JSONDecoder().decode(R.self, from: data)
        guard let first = r.results?.first else { throw NSError(domain:"Geo", code:0) }
        let gp = GeoPlace(name: first.name, latitude: first.latitude, longitude: first.longitude)
        if let enc = try? JSONEncoder().encode(gp) { caches.memory.set(key, data: enc, ttl: ttl); caches.disk.set(key, data: enc, ttl: ttl) }
        return gp
    }

    func suggest(prefix: String, language: String, limit: Int) async throws -> [GeoPlace] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let key = "sugg::\(language)::\(trimmed.lowercased())"
        if let d = caches.memory.get(key) ?? caches.disk.get(key),
           let arr = try? JSONDecoder().decode([GeoPlace].self, from: d) { return arr }

        var comps = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        comps.queryItems = [
            .init(name:"name", value: trimmed),
            .init(name:"count", value: String(limit)),
            .init(name:"language", value: language)
        ]
        guard let url = comps.url else { throw NetworkClient.NetError.badURL }
        let data = try await network.get(url: url)
        struct R: Codable { struct Res: Codable { let name: String; let country_code: String; let latitude, longitude: Double; let admin1: String? }; let results: [Res]? }
        let r = try JSONDecoder().decode(R.self, from: data)

        let mapped: [GeoPlace] = (r.results ?? []).map { GeoPlace(name: "\($0.name), \($0.admin1 ?? ""), \($0.country_code)", latitude: $0.latitude, longitude: $0.longitude) }
        if let enc = try? JSONEncoder().encode(mapped) { caches.memory.set(key, data: enc, ttl: ttl); caches.disk.set(key, data: enc, ttl: ttl) }
        return mapped
    }
}
