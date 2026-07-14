import Foundation

struct TripDay: Identifiable, Hashable {
    let date: Date
    let segmentID: UUID
    let placeName: String
    let dayNumber: Int

    var id: String {
        "\(segmentID.uuidString)-\(date.timeIntervalSinceReferenceDate)"
    }
}

