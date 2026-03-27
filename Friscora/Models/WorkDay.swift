//
//  WorkDay.swift
//  Friscora
//
//  Model representing a single work day with hours worked
//

import Foundation

/// WorkDay model representing hours worked on a specific date (and optionally which shift).
struct WorkDay: Identifiable, Codable {
    let id: UUID
    let date: Date
    var hoursWorked: Double
    var jobId: UUID
    /// When set, hours were derived from this shift. Kept for display; hoursWorked is still the source for calculations.
    var shiftId: UUID?
    /// When set, overrides the shift's time range for this day only (e.g. worked 10:00–15:00 instead of full shift).
    var customStartMinutesFromMidnight: Int?
    var customEndMinutesFromMidnight: Int?
    
    init(id: UUID = UUID(), date: Date, hoursWorked: Double, jobId: UUID, shiftId: UUID? = nil, customStartMinutesFromMidnight: Int? = nil, customEndMinutesFromMidnight: Int? = nil) {
        self.id = id
        self.date = date
        self.hoursWorked = hoursWorked
        self.jobId = jobId
        self.shiftId = shiftId
        self.customStartMinutesFromMidnight = customStartMinutesFromMidnight
        self.customEndMinutesFromMidnight = customEndMinutesFromMidnight
    }
    
    enum CodingKeys: String, CodingKey {
        case id, date, hoursWorked, jobId, shiftId, customStartMinutesFromMidnight, customEndMinutesFromMidnight
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        hoursWorked = try c.decode(Double.self, forKey: .hoursWorked)
        jobId = try c.decode(UUID.self, forKey: .jobId)
        shiftId = try c.decodeIfPresent(UUID.self, forKey: .shiftId)
        customStartMinutesFromMidnight = try c.decodeIfPresent(Int.self, forKey: .customStartMinutesFromMidnight)
        customEndMinutesFromMidnight = try c.decodeIfPresent(Int.self, forKey: .customEndMinutesFromMidnight)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(hoursWorked, forKey: .hoursWorked)
        try c.encode(jobId, forKey: .jobId)
        try c.encodeIfPresent(shiftId, forKey: .shiftId)
        try c.encodeIfPresent(customStartMinutesFromMidnight, forKey: .customStartMinutesFromMidnight)
        try c.encodeIfPresent(customEndMinutesFromMidnight, forKey: .customEndMinutesFromMidnight)
    }
    
    /// Display time range for this day: custom times if set, otherwise nil (caller uses shift times).
    func customTimeRangeString(locale: Locale) -> String? {
        guard let start = customStartMinutesFromMidnight, let end = customEndMinutesFromMidnight else { return nil }
        let startDate = dateFromMinutes(start)
        let endDate = dateFromMinutes(end)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: locale) ?? "h:mm a"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}
