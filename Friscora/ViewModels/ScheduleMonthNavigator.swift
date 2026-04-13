//
//  ScheduleMonthNavigator.swift
//  Friscora
//
//  Pure month navigation logic for testing.
//

import Foundation

struct ScheduleMonthNavigator {
    static func previousIndex(from index: Int, lowerBound: Int = 0) -> Int {
        max(lowerBound, index - 1)
    }

    static func nextIndex(from index: Int, upperBound: Int) -> Int {
        min(upperBound, index + 1)
    }

    static func todayIndex(in months: [Date], calendar: Calendar = .current) -> Int? {
        let now = Date()
        return months.firstIndex { calendar.isDate($0, equalTo: now, toGranularity: .month) }
    }

    // MARK: - Partner schedule snapshot (year/month alignment)

    /// `true` if the visible month’s date interval contains at least one `yyyy-MM-dd` key from the partner snapshot.
    static func visibleMonthContainsAnyPartnerDay(
        snap: PartnerScheduleSnapshot,
        visibleMonthStart: Date,
        calendar: Calendar
    ) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonthStart) else { return false }
        for key in snap.days.keys {
            guard let d = ScheduleSharingScheduleExporter.dayKeyToDate(key) else { continue }
            if d >= interval.start && d < interval.end { return true }
        }
        return false
    }

    /// Start-of-month for the calendar month that contains the **earliest** day in the snapshot (by key sort).
    static func startOfMonthContainingFirstPartnerDay(
        in snap: PartnerScheduleSnapshot,
        calendar: Calendar
    ) -> Date? {
        startOfMonthContainingEarliestPartnerDay(in: snap, calendar: calendar)
    }

    /// Earliest partner day by actual `Date` (not string sort — avoids mis-ordering if key formats ever diverge).
    static func startOfMonthContainingEarliestPartnerDay(
        in snap: PartnerScheduleSnapshot,
        calendar: Calendar
    ) -> Date? {
        var earliest: Date?
        for key in snap.days.keys {
            guard let d = ScheduleSharingScheduleExporter.dayKeyToDate(key) else { continue }
            if let e = earliest {
                if d < e { earliest = d }
            } else {
                earliest = d
            }
        }
        guard let day = earliest else { return nil }
        return calendar.date(from: calendar.dateComponents([.year, .month], from: day))
    }
}
