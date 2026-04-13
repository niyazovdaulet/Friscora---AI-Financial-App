//
//  SmartSchedulePlannerTests.swift
//  FriscoraTests
//

import XCTest
@testable import Friscora

final class SmartSchedulePlannerTests: XCTestCase {
    
    func testWorkDayDecodesLegacyPayloadWithoutNewKeys() throws {
        let id = UUID()
        let jobId = UUID()
        let shiftId = UUID()
        let day = Date(timeIntervalSinceReferenceDate: 100_000)
        let payload: [String: Any] = [
            "id": id.uuidString,
            "date": day.timeIntervalSinceReferenceDate,
            "hoursWorked": 8.0,
            "jobId": jobId.uuidString,
            "shiftId": shiftId.uuidString,
            "customStartMinutesFromMidnight": NSNull(),
            "customEndMinutesFromMidnight": NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let wd = try JSONDecoder().decode(WorkDay.self, from: data)
        XCTAssertNil(wd.bulkOperationId)
        XCTAssertNil(wd.patternId)
    }
    
    func testScheduleWeekdayRoundTripKnownDates() {
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        var c = DateComponents()
        c.year = 2026
        c.month = 4
        c.day = 13
        let monday = cal.date(from: c)!
        XCTAssertEqual(ScheduleWeekday.appWeekday(mondayFirst1To7: monday, calendar: cal), 1)
        c.day = 19
        let sunday = cal.date(from: c)!
        XCTAssertEqual(ScheduleWeekday.appWeekday(mondayFirst1To7: sunday, calendar: cal), 7)
    }
    
    func testPatternDetectorSkipsWhenFingerprintDismissed() {
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        let jobId = UUID()
        let shiftId = UUID()
        let job = Job(id: jobId, name: "Test", paymentType: .hourly, hourlyRate: 15, shifts: [
            Shift(id: shiftId, name: "Day", startMinutesFromMidnight: 9 * 60, endMinutesFromMidnight: 17 * 60)
        ])
        var workDays: [WorkDay] = []
        for i in 0..<6 {
            guard let d = cal.date(byAdding: .day, value: i * 2, to: cal.startOfDay(for: Date())) else { continue }
            workDays.append(WorkDay(date: d, hoursWorked: 8, jobId: jobId, shiftId: shiftId))
        }
        let fp = SchedulePatternDetector.fingerprint(jobId: jobId, shiftId: shiftId, weekdays: [1, 2, 3])
        let dismissed: [String: TimeInterval] = [fp: Date().timeIntervalSince1970]
        let suggestion = SchedulePatternDetector.computeSuggestion(
            workDays: workDays,
            jobs: [job],
            existingPatterns: [],
            dismissedFingerprints: dismissed
        )
        XCTAssertNil(suggestion)
    }
}
