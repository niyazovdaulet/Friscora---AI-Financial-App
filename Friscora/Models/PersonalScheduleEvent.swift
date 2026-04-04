//
//  PersonalScheduleEvent.swift
//  Friscora
//
//  In-app personal / non-work time blocks. Excluded from salary forecast and income sync.
//

import Foundation

struct PersonalScheduleEvent: Identifiable, Codable, Equatable {
    var id: UUID
    /// Normalized to start-of-day in the user’s calendar when saved.
    var date: Date
    var title: String
    var startMinutesFromMidnight: Int
    var endMinutesFromMidnight: Int
    /// When true, month grid hides the title and shows a generic “busy” label in compact UI.
    var showAsBusy: Bool
    
    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        startMinutesFromMidnight: Int,
        endMinutesFromMidnight: Int,
        showAsBusy: Bool = false
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.startMinutesFromMidnight = startMinutesFromMidnight
        self.endMinutesFromMidnight = endMinutesFromMidnight
        self.showAsBusy = showAsBusy
    }
    
    func displayTitle(fallbackBusy: String) -> String {
        if showAsBusy && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallbackBusy
        }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallbackBusy : t
    }
    
    func timeRangeString(locale: Locale) -> String {
        let startDate = dateFromMinutes(startMinutesFromMidnight)
        let endDate = dateFromMinutes(endMinutesFromMidnight)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: locale) ?? "h:mm a"
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }
    
    /// Inclusive start, exclusive end in absolute time for overlap checks.
    func absoluteInterval(calendar: Calendar) -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: date)
        guard let start = calendar.date(byAdding: .minute, value: startMinutesFromMidnight, to: day),
              var end = calendar.date(byAdding: .minute, value: endMinutesFromMidnight, to: day) else {
            return (day, day)
        }
        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }
        return (start, end)
    }
}
