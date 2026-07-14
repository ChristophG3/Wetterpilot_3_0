import Foundation
import SwiftData

@Model
final class TripSegment {
    var id: UUID
    var placeName: String
    var regionName: String?
    var countryName: String?
    var latitude: Double?
    var longitude: Double?
    var timeZoneIdentifier: String?
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var trip: Trip?

    init(
        id: UUID = UUID(),
        placeName: String,
        regionName: String? = nil,
        countryName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        timeZoneIdentifier: String? = nil,
        startDate: Date,
        endDate: Date,
        createdAt: Date = .now,
        trip: Trip? = nil
    ) {
        self.id = id
        self.placeName = placeName
        self.regionName = regionName
        self.countryName = countryName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.trip = trip
    }
}

