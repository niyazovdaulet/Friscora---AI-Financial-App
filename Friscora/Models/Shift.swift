//
//  Shift.swift
//  Friscora
//
//  Model for a work shift with start and end times. Hours are derived from the shift.
//

import Foundation

/// Convert minutes from midnight to a Date (today) for picker binding.
func dateFromMinutes(_ minutes: Int) -> Date {
    let cal = Calendar.current
    return cal.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
}

/// Convert a Date’s time to minutes from midnight.
func minutesFromDate(_ date: Date) -> Int {
    let cal = Calendar.current
    let h = cal.component(.hour, from: date)
    let m = cal.component(.minute, from: date)
    return h * 60 + m
}

/// A shift belongs to a job and defines a named time range (e.g. Morning 9:00–17:00).
/// Hours worked = end - start (handles overnight by adding 24h if end < start).
struct Shift: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// Minutes from midnight (0–1439). E.g. 9:00 AM = 540.
    var startMinutesFromMidnight: Int
    /// Minutes from midnight (0–1439). E.g. 5:00 PM = 1020.
    var endMinutesFromMidnight: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        startMinutesFromMidnight: Int,
        endMinutesFromMidnight: Int
    ) {
        self.id = id
        self.name = name
        self.startMinutesFromMidnight = max(0, min(1439, startMinutesFromMidnight))
        self.endMinutesFromMidnight = max(0, min(1439, endMinutesFromMidnight))
    }
    
    /// Duration in hours (e.g. 9:00–17:00 = 8.0). Handles overnight (end < start) as same-day wrap.
    var durationHours: Double {
        var diff = endMinutesFromMidnight - startMinutesFromMidnight
        if diff <= 0 { diff += 24 * 60 }
        return Double(diff) / 60.0
    }
    
    /// Start time as Date components (today, for display).
    var startTimeComponents: (hour: Int, minute: Int) {
        (startMinutesFromMidnight / 60, startMinutesFromMidnight % 60)
    }
    
    /// End time as Date components (today, for display).
    var endTimeComponents: (hour: Int, minute: Int) {
        (endMinutesFromMidnight / 60, endMinutesFromMidnight % 60)
    }
    
    /// Formatted time range for display, e.g. "10:00 AM - 6:00 PM".
    func timeRangeString(locale: Locale = Locale.current) -> String {
        let startDate = dateFromMinutes(startMinutesFromMidnight)
        let endDate = dateFromMinutes(endMinutesFromMidnight)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: locale) ?? "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}
