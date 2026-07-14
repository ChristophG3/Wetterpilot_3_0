import Foundation

enum HTTPError: LocalizedError {
    case invalidResponse
    case statusCode(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "network.error.invalidResponse")
        case .statusCode(let code):
            return String(localized: "network.error.statusCode \(code)")
        }
    }
}

struct HTTPClient {
    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadRevalidatingCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        guard 200..<300 ~= response.statusCode else {
            throw HTTPError.statusCode(response.statusCode)
        }
        return data
    }
}
