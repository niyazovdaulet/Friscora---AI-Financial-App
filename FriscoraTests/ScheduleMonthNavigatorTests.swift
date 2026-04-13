import XCTest
@testable import Friscora

final class ScheduleMonthNavigatorTests: XCTestCase {
    func testPreviousIndexMovesBackByOne() {
        XCTAssertEqual(ScheduleMonthNavigator.previousIndex(from: 5, lowerBound: 0), 4)
    }

    func testPreviousIndexStopsAtLowerBound() {
        XCTAssertEqual(ScheduleMonthNavigator.previousIndex(from: 0, lowerBound: 0), 0)
    }

    func testNextIndexMovesForwardByOne() {
        XCTAssertEqual(ScheduleMonthNavigator.nextIndex(from: 1, upperBound: 10), 2)
    }

    func testNextIndexStopsAtUpperBound() {
        XCTAssertEqual(ScheduleMonthNavigator.nextIndex(from: 10, upperBound: 10), 10)
    }

    func testEarliestPartnerMonthUsesMinimumDateNotLexicographicEdgeCase() {
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        var days: [String: PartnerScheduleSnapshot.DayBucket] = [:]
        days["2028-04-07"] = PartnerScheduleSnapshot.DayBucket(work: [], personalEventCount: 1)
        days["2026-04-09"] = PartnerScheduleSnapshot.DayBucket(work: [], personalEventCount: 1)
        let snap = PartnerScheduleSnapshot(days: days, shareItems: [.shifts])
        let start = ScheduleMonthNavigator.startOfMonthContainingEarliestPartnerDay(in: snap, calendar: cal)
        XCTAssertNotNil(start)
        XCTAssertEqual(cal.component(.year, from: start!), 2026)
        XCTAssertEqual(cal.component(.month, from: start!), 4)
    }
}
