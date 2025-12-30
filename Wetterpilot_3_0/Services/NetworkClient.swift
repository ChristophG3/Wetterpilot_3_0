import Foundation

final class NetworkClient {
    enum NetError: Error { case badURL, http(Int), decoding, other(Error) }
    
    func get(url: URL) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: url)
        if let r = resp as? HTTPURLResponse, !(200...299).contains(r.statusCode) {
            throw NetError.http(r.statusCode)
        }
        return data
    }
}
