//
//  ScheduleWeekday.swift
//  Friscora
//
//  App-wide weekday encoding for patterns and schedule UI: 1 = Monday … 7 = Sunday.
//

import Foundation

enum ScheduleWeekday {
    /// Maps `Calendar.Component.weekday` (1 = Sunday … 7 = Saturday) to app encoding (1 = Monday … 7 = Sunday).
    static func appWeekday(mondayFirst1To7 date: Date, calendar: Calendar) -> Int {
        let swiftWeekday = calendar.component(.weekday, from: date)
        // Swift: Sun=1 … Sat=7 → Mon=2 … Sun=1
        if swiftWeekday == 1 { return 7 }
        return swiftWeekday - 1
    }
    
    /// Every `startOfDay` in `[start...end]` whose app-weekday is in `weekdays` (1=Mon…7=Sun).
    static func allDays(from start: Date, to end: Date, weekdays: Set<Int>, calendar: Calendar) -> [Date] {
        guard !weekdays.isEmpty else { return [] }
        var out: [Date] = []
        var d = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while d <= endDay {
            let w = appWeekday(mondayFirst1To7: d, calendar: calendar)
            if weekdays.contains(w) {
                out.append(d)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }
}
