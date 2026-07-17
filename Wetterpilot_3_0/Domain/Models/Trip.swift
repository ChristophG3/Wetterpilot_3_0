import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var forecastNotificationEnabled: Bool = false
    var startFlexibilityRawValue: String = TripStartFlexibility.exact.rawValue

    @Relationship(deleteRule: .cascade, inverse: \TripSegment.trip)
    var segments: [TripSegment]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        forecastNotificationEnabled: Bool = false,
        startFlexibility: TripStartFlexibility = .exact,
        segments: [TripSegment] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.forecastNotificationEnabled = forecastNotificationEnabled
        self.startFlexibilityRawValue = startFlexibility.rawValue
        self.segments = segments
    }

    var sortedSegments: [TripSegment] {
        segments.sorted {
            if $0.startDate == $1.startDate {
                return $0.createdAt < $1.createdAt
            }
            return $0.startDate < $1.startDate
        }
    }

    var startDate: Date? { segments.map(\.startDate).min() }
    var endDate: Date? { segments.map(\.endDate).max() }

    var startFlexibility: TripStartFlexibility {
        get { TripStartFlexibility(rawValue: startFlexibilityRawValue) ?? .exact }
        set { startFlexibilityRawValue = newValue.rawValue }
    }
}
