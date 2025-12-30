import Foundation

extension Date {
    func isoDate() -> String { ISO8601DateFormatter.dateOnly.string(from: self) }
}
