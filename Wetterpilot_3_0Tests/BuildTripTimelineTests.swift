import XCTest
@testable import Wetterpilot_3_0

final class BuildTripTimelineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testBuildsOneDayPerTravelDate() throws {
        let barcelona = TimelineSegment(
            id: UUID(),
            placeName: "Barcelona",
            startDate: date(2026, 8, 1),
            endDate: date(2026, 8, 2)
        )
        let ibiza = TimelineSegment(
            id: UUID(),
            placeName: "Ibiza",
            startDate: date(2026, 8, 3),
            endDate: date(2026, 8, 3)
        )

        let days = try BuildTripTimeline(calendar: calendar)(segments: [ibiza, barcelona])

        XCTAssertEqual(days.map(\.placeName), ["Barcelona", "Barcelona", "Ibiza"])
        XCTAssertEqual(days.map(\.dayNumber), [1, 2, 3])
    }

    func testRejectsGapWithoutFixedPlace() {
        let first = TimelineSegment(
            id: UUID(),
            placeName: "Barcelona",
            startDate: date(2026, 8, 1),
            endDate: date(2026, 8, 1)
        )
        let second = TimelineSegment(
            id: UUID(),
            placeName: "Palermo",
            startDate: date(2026, 8, 3),
            endDate: date(2026, 8, 3)
        )

        XCTAssertThrowsError(try BuildTripTimeline(calendar: calendar)(segments: [first, second])) {
            XCTAssertEqual($0 as? TimelineError, .gapBetweenSegments)
        }
    }

    func testRejectsOverlappingStays() {
        let first = TimelineSegment(
            id: UUID(),
            placeName: "Bangkok",
            startDate: date(2026, 9, 1),
            endDate: date(2026, 9, 3)
        )
        let second = TimelineSegment(
            id: UUID(),
            placeName: "Chiang Mai",
            startDate: date(2026, 9, 2),
            endDate: date(2026, 9, 4)
        )

        XCTAssertThrowsError(try BuildTripTimeline(calendar: calendar)(segments: [first, second])) {
            XCTAssertEqual($0 as? TimelineError, .overlappingSegments)
        }
    }

    func testAllowsTwoPlacesOnSharedTransferDay() throws {
        let bangkok = TimelineSegment(
            id: UUID(),
            placeName: "Bangkok",
            startDate: date(2026, 9, 1),
            endDate: date(2026, 9, 3)
        )
        let chiangMai = TimelineSegment(
            id: UUID(),
            placeName: "Chiang Mai",
            startDate: date(2026, 9, 3),
            endDate: date(2026, 9, 4)
        )

        let days = try BuildTripTimeline(calendar: calendar)(segments: [bangkok, chiangMai])

        XCTAssertEqual(days.map(\.placeName), ["Bangkok", "Bangkok", "Bangkok", "Chiang Mai", "Chiang Mai"])
        XCTAssertEqual(days.map(\.dayNumber), [1, 2, 3, 3, 4])
    }

    func testNewPlaceDefaultsToLastEnteredDatePlusOneDay() {
        let last = SegmentDraft(
            placeName: "Bangkok",
            startDate: date(2026, 7, 15, hour: 18),
            endDate: date(2026, 7, 16, hour: 22)
        )

        let next = SegmentDraft.defaultStartDate(after: last, calendar: calendar)

        XCTAssertEqual(next, date(2026, 7, 17))
    }

    func testMovingStartDateForwardAlsoMovesEarlierEndDate() {
        var draft = SegmentDraft(
            placeName: "Bad Aibling",
            startDate: date(2026, 7, 14),
            endDate: date(2026, 7, 14)
        )

        draft.setStartDate(date(2026, 7, 15, hour: 19), calendar: calendar)

        XCTAssertEqual(draft.startDate, date(2026, 7, 15))
        XCTAssertEqual(draft.endDate, date(2026, 7, 15))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
