//
//  SchedulePatternDetector.swift
//  Friscora
//
//  Heuristic “earning-aware” schedule pattern suggestion from recent work days (4-week window).
//

import Foundation

enum SchedulePatternDetector {
    
    static func fingerprint(jobId: UUID, shiftId: UUID?, weekdays: [Int]) -> String {
        let sorted = weekdays.sorted()
        return "\(jobId.uuidString)|\(shiftId?.uuidString ?? "none")|\(sorted.map(String.init).joined(separator: ","))"
    }
    
    /// Returns a suggestion when recent shifts form a repeatable weekday pattern and no duplicate pattern exists.
    static func computeSuggestion(
        workDays: [WorkDay],
        jobs: [Job],
        existingPatterns: [WorkPattern],
        dismissedFingerprints: [String: TimeInterval]
    ) -> SchedulePatternSuggestion? {
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        let today = cal.startOfDay(for: Date())
        guard let windowStart = cal.date(byAdding: .day, value: -28, to: today) else { return nil }
        
        let windowed = workDays.filter {
            let d = cal.startOfDay(for: $0.date)
            return d >= windowStart && d <= today
        }
        guard windowed.count >= 4 else { return nil }
        
        let jobById = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
        
        /// Groups key: job|shift
        struct Cluster {
            var jobId: UUID
            var shiftId: UUID?
            var weekdayCounts: [Int: Int] = [:]
            var totalHours: Double = 0
        }
        
        var clusters: [String: Cluster] = [:]
        
        for wd in windowed {
            guard let shiftId = wd.shiftId else { continue }
            guard jobById[wd.jobId] != nil else { continue }
            let key = "\(wd.jobId.uuidString)|\(shiftId.uuidString)"
            var c = clusters[key] ?? Cluster(jobId: wd.jobId, shiftId: shiftId)
            let w = ScheduleWeekday.appWeekday(mondayFirst1To7: wd.date, calendar: cal)
            c.weekdayCounts[w, default: 0] += 1
            c.totalHours += wd.hoursWorked
            clusters[key] = c
        }
        
        guard let best = clusters.values.max(by: { lhs, rhs in
            let lhsScore = lhs.weekdayCounts.values.reduce(0, +)
            let rhsScore = rhs.weekdayCounts.values.reduce(0, +)
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            return lhs.totalHours < rhs.totalHours
        }) else { return nil }
        
        let activeWeekdays = best.weekdayCounts.filter { $0.value >= 2 }.map(\.key).sorted()
        guard activeWeekdays.count >= 2 else { return nil }
        
        guard let job = jobById[best.jobId] else { return nil }
        
        if existingPatterns.contains(where: { p in
            p.jobId == best.jobId
                && Set(p.weekdays) == Set(activeWeekdays)
                && p.shiftId == best.shiftId
        }) {
            return nil
        }
        
        let fp = fingerprint(jobId: best.jobId, shiftId: best.shiftId, weekdays: activeWeekdays)
        if dismissedFingerprints[fp] != nil {
            return nil
        }
        
        let isFixed = job.paymentType == .fixedMonthly
        var monthly: Double?
        if job.paymentType == .hourly, let rate = job.hourlyRate, rate > 0, let shiftId = best.shiftId,
           let shift = job.shift(withId: shiftId) {
            let hoursPerShift = shift.durationHours
            let daysPerWeek = Double(activeWeekdays.count)
            let hoursPerWeek = daysPerWeek * hoursPerShift
            monthly = hoursPerWeek * 4.33 * rate
        }
        
        return SchedulePatternSuggestion(
            id: UUID(),
            jobId: best.jobId,
            shiftId: best.shiftId,
            weekdays: activeWeekdays,
            estimatedMonthlyEarnings: monthly,
            isFixedMonthlyJob: isFixed
        )
    }
}
