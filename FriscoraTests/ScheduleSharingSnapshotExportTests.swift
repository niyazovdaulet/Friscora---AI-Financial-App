//
//  ScheduleSharingSnapshotExportTests.swift
//  FriscoraTests
//

import XCTest
@testable import Friscora

final class ScheduleSharingSnapshotExportTests: XCTestCase {

    func testLegacySnapshotDecodesWithoutPersonalEventsArray() throws {
        let json = """
        {"days":{"2026-01-15":{"work":[],"personalEventCount":3}},"shareItems":["events"]}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let snap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: data)
        let bucket = try XCTUnwrap(snap.days["2026-01-15"])
        XCTAssertEqual(bucket.personalEventCount, 3)
        XCTAssertTrue(bucket.personalEvents.isEmpty)
        XCTAssertEqual(bucket.displayablePersonalEventCount, 3)
    }

    func testSnapshotRoundTripPreservesPersonalEventSummaries() throws {
        var bucket = PartnerScheduleSnapshot.DayBucket(work: [], personalEventCount: 0)
        bucket.personalEvents = [
            PartnerScheduleSnapshot.PersonalEventSummary(
                title: "Gym",
                startMinutesFromMidnight: 600,
                endMinutesFromMidnight: 660,
                showAsBusy: false
            )
        ]
        bucket.personalEventCount = 1
        let snap = PartnerScheduleSnapshot(days: ["2026-06-01": bucket], shareItems: [.events])
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: data)
        let roundBucket = try XCTUnwrap(decoded.days["2026-06-01"])
        XCTAssertEqual(roundBucket.personalEvents.count, 1)
        XCTAssertEqual(roundBucket.personalEvents.first?.title, "Gym")
        XCTAssertEqual(roundBucket.personalEvents.first?.startMinutesFromMidnight, 600)
        XCTAssertEqual(roundBucket.displayablePersonalEventCount, 1)
    }

    func testLegacyWorkSegmentDecodesWithoutShiftTimes() throws {
        let json = """
        {"jobName":"Eng","hoursWorked":8,"colorHex":"#FF8000"}
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let seg = try JSONDecoder().decode(PartnerScheduleSnapshot.WorkSegment.self, from: data)
        XCTAssertNil(seg.startMinutesFromMidnight)
        XCTAssertNil(seg.endMinutesFromMidnight)
    }

    func testWorkSegmentRoundTripShiftTimes() throws {
        let seg = PartnerScheduleSnapshot.WorkSegment(
            jobName: "Eng",
            hoursWorked: 8,
            colorHex: "#FF8000",
            startMinutesFromMidnight: 540,
            endMinutesFromMidnight: 1_020
        )
        let data = try JSONEncoder().encode(seg)
        let decoded = try JSONDecoder().decode(PartnerScheduleSnapshot.WorkSegment.self, from: data)
        XCTAssertEqual(decoded.startMinutesFromMidnight, 540)
        XCTAssertEqual(decoded.endMinutesFromMidnight, 1_020)
    }
}
