import Foundation

final class PersistenceStore {
    private let ud = UserDefaults.standard
    
    private enum Key: String {
        case startDateISO, durationDays, weights, places, hasSeenWelcome
    }
    
    var hasSeenWelcome: Bool {
        get { ud.bool(forKey: Key.hasSeenWelcome.rawValue) }
        set { ud.set(newValue, forKey: Key.hasSeenWelcome.rawValue) }
    }
    
    var startDate: Date? {
        get {
            guard let s = ud.string(forKey: Key.startDateISO.rawValue) else { return nil }
            return ISO8601DateFormatter.dateOnly.date(from: s)
        }
        set {
            let s = newValue.map { ISO8601DateFormatter.dateOnly.string(from: $0) }
            ud.set(s, forKey: Key.startDateISO.rawValue)
        }
    }
    
    var durationDays: Int {
        get { let v = ud.integer(forKey: Key.durationDays.rawValue); return v == 0 ? 3 : v }
        set { ud.set(newValue, forKey: Key.durationDays.rawValue) }
    }
    
    var weights: Weights {
        get {
            if let d = ud.data(forKey: Key.weights.rawValue),
               let w = try? JSONDecoder().decode(Weights.self, from: d) { return w }
            return Weights()
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) {
                ud.set(d, forKey: Key.weights.rawValue)
            }
        }
    }
    
    var places: [String] {
        get { ud.stringArray(forKey: Key.places.rawValue) ?? [] }
        set { ud.set(newValue, forKey: Key.places.rawValue) }
    }
    
    func resetAll() {
        [Key.startDateISO, .durationDays, .weights, .places].forEach { ud.removeObject(forKey: $0.rawValue) }
    }
}

extension ISO8601DateFormatter {
    static let dateOnly: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .iso8601)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
