import Foundation
import SwiftData

@Model
final class DestinationComparison {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var updatedAt: Date
    var forecastNotificationEnabled: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ComparisonCandidate.comparison)
    var candidates: [ComparisonCandidate]

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date,
        endDate: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        forecastNotificationEnabled: Bool = false,
        candidates: [ComparisonCandidate] = []
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.forecastNotificationEnabled = forecastNotificationEnabled
        self.candidates = candidates
    }

    var sortedCandidates: [ComparisonCandidate] {
        candidates.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class ComparisonCandidate {
    var id: UUID
    var placeName: String
    var regionName: String?
    var countryName: String?
    var latitude: Double?
    var longitude: Double?
    var timeZoneIdentifier: String?
    var createdAt: Date
    var comparison: DestinationComparison?

    init(
        id: UUID = UUID(),
        placeName: String,
        regionName: String? = nil,
        countryName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        timeZoneIdentifier: String? = nil,
        createdAt: Date = .now,
        comparison: DestinationComparison? = nil
    ) {
        self.id = id
        self.placeName = placeName
        self.regionName = regionName
        self.countryName = countryName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.createdAt = createdAt
        self.comparison = comparison
    }
}
