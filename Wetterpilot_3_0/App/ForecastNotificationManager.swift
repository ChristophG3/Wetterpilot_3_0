import Foundation
import UserNotifications

protocol ForecastNotificationScheduling {
    func requestAuthorization() async throws -> Bool
    func schedule(tripID: UUID, tripName: String, firstTravelDate: Date, calendar: Calendar) async throws
    func remove(tripID: UUID)
}

struct ForecastNotificationPlanner {
    static func identifier(for tripID: UUID) -> String { "forecast-available-\(tripID.uuidString)" }
    static func comparisonIdentifier(for comparisonID: UUID) -> String {
        "comparison-forecast-available-\(comparisonID.uuidString)"
    }

    static func notificationDate(
        firstTravelDate: Date,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let travelDay = calendar.startOfDay(for: firstTravelDate)
        guard var date = calendar.date(byAdding: .day, value: -(ForecastAvailability.forecastDayCount - 1), to: travelDay) else { return nil }
        date = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: date) ?? date
        return date > now ? date : nil
    }
}

final class ForecastNotificationManager: ForecastNotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) { self.center = center }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func schedule(
        tripID: UUID,
        tripName: String,
        firstTravelDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws {
        remove(tripID: tripID)
        guard let fireDate = ForecastNotificationPlanner.notificationDate(
            firstTravelDate: firstTravelDate, calendar: calendar
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.forecastAvailable.title")
        content.body = String(localized: "notification.forecastAvailable.body \(tripName)")
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: ForecastNotificationPlanner.identifier(for: tripID),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await center.add(request)
    }

    func remove(tripID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [ForecastNotificationPlanner.identifier(for: tripID)])
    }

    func scheduleComparison(
        comparisonID: UUID,
        comparisonName: String,
        startDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) async throws {
        removeComparison(comparisonID: comparisonID)
        guard let fireDate = ForecastNotificationPlanner.notificationDate(
            firstTravelDate: startDate, calendar: calendar
        ) else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "comparison.notification.title")
        content.body = String(localized: "comparison.notification.body \(comparisonName)")
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: ForecastNotificationPlanner.comparisonIdentifier(for: comparisonID),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        try await center.add(request)
    }

    func removeComparison(comparisonID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [ForecastNotificationPlanner.comparisonIdentifier(for: comparisonID)]
        )
    }
}
