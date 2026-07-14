import Foundation

enum TimelineError: LocalizedError, Equatable {
    case emptyTrip
    case emptyPlace
    case invalidDateRange
    case overlappingSegments
    case gapBetweenSegments

    var errorDescription: String? {
        switch self {
        case .emptyTrip:
            return "Füge mindestens einen Ort hinzu."
        case .emptyPlace:
            return "Jeder Aufenthalt benötigt einen Ort."
        case .invalidDateRange:
            return "Das Enddatum darf nicht vor dem Startdatum liegen."
        case .overlappingSegments:
            return "Aufenthalte dürfen sich nur an einem gemeinsamen Wechseltag überschneiden."
        case .gapBetweenSegments:
            return "Jedem Reisetag muss ein fester Ort zugeordnet sein."
        }
    }
}

struct TimelineSegment: Equatable {
    let id: UUID
    let placeName: String
    let startDate: Date
    let endDate: Date
}

struct BuildTripTimeline {
    var calendar: Calendar = .autoupdatingCurrent

    func callAsFunction(segments: [TimelineSegment]) throws -> [TripDay] {
        guard !segments.isEmpty else { throw TimelineError.emptyTrip }

        let normalized = segments.enumerated()
            .map { index, segment in
                (
                    index,
                    TimelineSegment(
                        id: segment.id,
                        placeName: segment.placeName.trimmingCharacters(in: .whitespacesAndNewlines),
                        startDate: calendar.startOfDay(for: segment.startDate),
                        endDate: calendar.startOfDay(for: segment.endDate)
                    )
                )
            }
            .sorted {
                if $0.1.startDate == $1.1.startDate {
                    return $0.0 < $1.0
                }
                return $0.1.startDate < $1.1.startDate
            }
            .map(\.1)

        guard normalized.allSatisfy({ !$0.placeName.isEmpty }) else {
            throw TimelineError.emptyPlace
        }
        guard normalized.allSatisfy({ $0.endDate >= $0.startDate }) else {
            throw TimelineError.invalidDateRange
        }

        // Any number of locations may share one travel day. An overlap spanning
        // two or more calendar days is still invalid.
        for firstIndex in normalized.indices {
            for secondIndex in normalized.indices where secondIndex > firstIndex {
                let first = normalized[firstIndex]
                let second = normalized[secondIndex]
                let overlapStart = max(first.startDate, second.startDate)
                let overlapEnd = min(first.endDate, second.endDate)
                if overlapStart <= overlapEnd,
                   let secondOverlapDay = calendar.date(byAdding: .day, value: 1, to: overlapStart),
                   secondOverlapDay <= overlapEnd {
                    throw TimelineError.overlappingSegments
                }
            }
        }

        // Check the union of all stays so a shorter same-day stop cannot create
        // a false gap while another stay still covers the following days.
        var coveredThrough = normalized[0].endDate
        for segment in normalized.dropFirst() {
            guard let expectedNextDay = calendar.date(byAdding: .day, value: 1, to: coveredThrough) else {
                throw TimelineError.invalidDateRange
            }
            if segment.startDate > expectedNextDay {
                throw TimelineError.gapBetweenSegments
            }
            coveredThrough = max(coveredThrough, segment.endDate)
        }

        var result: [TripDay] = []
        let firstTravelDate = normalized[0].startDate
        var date = firstTravelDate
        var dayNumber = 1
        while date <= coveredThrough {
            for segment in normalized where segment.startDate <= date && segment.endDate >= date {
                result.append(
                    TripDay(
                        date: date,
                        segmentID: segment.id,
                        placeName: segment.placeName,
                        dayNumber: dayNumber
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
            dayNumber += 1
        }
        return result
    }
}
