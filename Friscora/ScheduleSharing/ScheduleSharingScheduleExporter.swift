//
//  ScheduleSharingScheduleExporter.swift
//  Friscora
//
//  Builds PartnerScheduleSnapshot from local WorkScheduleService data for invite creation / mock API.
//

import Foundation

enum ScheduleSharingScheduleExporter {

    /// Monday-first calendar — single source of truth for the schedule grid (`WorkScheduleViewModel`) and exported day keys.
    static var gridCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    static func dayKey(for date: Date) -> String {
        let dayStart = gridCalendar.startOfDay(for: date)
        let c = gridCalendar.dateComponents([.year, .month, .day], from: dayStart)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Local calendar date at midnight for a snapshot day key (used for cross-checking grid dates vs. stored keys).
    static func dayKeyToDate(_ key: String) -> Date? {
        date(fromDayKey: key)
    }

    /// Exports the current local schedule into a server-shaped snapshot filtered by `shareItems`.
    static func exportSnapshot(shareItems: Set<ShareItem>) -> PartnerScheduleSnapshot {
        let work = WorkScheduleService.shared
        var dayMap: [String: PartnerScheduleSnapshot.DayBucket] = [:]

        if shareItems.contains(.shifts) {
            let cal = gridCalendar
            for wd in work.workDays {
                let key = dayKey(for: wd.date)
                let job = work.job(withId: wd.jobId)
                let range = work.resolvedDisplayTimeRangeMinutes(for: wd, calendar: cal)
                let segment = PartnerScheduleSnapshot.WorkSegment(
                    jobName: job?.name ?? L10n("schedule.share.partner.job_fallback"),
                    hoursWorked: wd.hoursWorked,
                    colorHex: job?.colorHex ?? "#888888",
                    startMinutesFromMidnight: range?.start,
                    endMinutesFromMidnight: range?.end
                )
                var bucket = dayMap[key] ?? PartnerScheduleSnapshot.DayBucket(work: [], personalEventCount: 0)
                bucket.work.append(segment)
                dayMap[key] = bucket
            }
        }

        if shareItems.contains(.events) {
            for ev in work.personalEvents {
                let key = dayKey(for: ev.date)
                var bucket = dayMap[key] ?? PartnerScheduleSnapshot.DayBucket(work: [], personalEventCount: 0)
                let summary = PartnerScheduleSnapshot.PersonalEventSummary(
                    title: ev.title,
                    startMinutesFromMidnight: ev.startMinutesFromMidnight,
                    endMinutesFromMidnight: ev.endMinutesFromMidnight,
                    showAsBusy: ev.showAsBusy
                )
                bucket.personalEvents.append(summary)
                bucket.personalEventCount = bucket.personalEvents.count
                dayMap[key] = bucket
            }
        }

        return PartnerScheduleSnapshot(
            days: dayMap,
            shareItems: Array(shareItems).sorted { $0.rawValue < $1.rawValue }
        )
    }

    static func filterSnapshot(_ snapshot: PartnerScheduleSnapshot, month: Date) -> PartnerScheduleSnapshot {
        let cal = gridCalendar
        let anchor = cal.date(from: cal.dateComponents([.year, .month], from: month)) ?? month
        guard let interval = cal.dateInterval(of: .month, for: anchor) else { return snapshot }
        let end = interval.end
        var filtered: [String: PartnerScheduleSnapshot.DayBucket] = [:]
        for (key, bucket) in snapshot.days {
            guard let date = Self.date(fromDayKey: key) else { continue }
            if date >= interval.start && date < end {
                filtered[key] = bucket
            }
        }
        return PartnerScheduleSnapshot(days: filtered, shareItems: snapshot.shareItems)
    }

    private static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents()
        c.year = parts[0]
        c.month = parts[1]
        c.day = parts[2]
        return gridCalendar.date(from: c)
    }
}
