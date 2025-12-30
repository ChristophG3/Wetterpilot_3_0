import Foundation

final class MemoryCache {
    private var store: [String: (expiry: Date, data: Data)] = [:]
    private let lock = NSLock()
    
    func get(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard let e = store[key], e.expiry > Date() else { store[key] = nil; return nil }
        return e.data
    }
    func set(_ key: String, data: Data, ttl: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        store[key] = (Date().addingTimeInterval(ttl), data)
    }
}

final class DiskCache {
    private let dir: URL
    init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("WetterpilotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    private func path(for key: String) -> URL { dir.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString) }
    
    func get(_ key: String) -> Data? {
        let url = path(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let meta = try? JSONDecoder().decode(Meta.self, from: data), meta.expiry > Date() {
            return meta.payload
        }
        try? FileManager.default.removeItem(at: url)
        return nil
    }
    func set(_ key: String, data: Data, ttl: TimeInterval) {
        let meta = Meta(expiry: Date().addingTimeInterval(ttl), payload: data)
        if let enc = try? JSONEncoder().encode(meta) {
            try? enc.write(to: path(for: key))
        }
    }
    private struct Meta: Codable { let expiry: Date; let payload: Data }
}
