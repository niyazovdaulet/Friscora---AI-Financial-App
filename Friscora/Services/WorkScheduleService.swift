//
//  WorkScheduleService.swift
//  Friscora
//
//  Service for managing work schedule data with multiple jobs
//

import Foundation
import Combine

/// Service for managing work schedule and personal (non-work) schedule entries.
class WorkScheduleService: ObservableObject {
    static let shared = WorkScheduleService()
    
    @Published var workDays: [WorkDay] = []
    @Published var jobs: [Job] = []
    @Published var personalEvents: [PersonalScheduleEvent] = []
    
    private let workDaysKey = "saved_work_days"
    private let jobsKey = "saved_jobs"
    private let personalEventsKey = "saved_personal_schedule_events"
    
    private init() {
        loadWorkDays()
        loadJobs()
        loadPersonalEvents()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadWorkDays()
        loadJobs()
        loadPersonalEvents()
    }
    
    // MARK: - Work Days
    
    /// Load work days from UserDefaults
    func loadWorkDays() {
        if let data = UserDefaults.standard.data(forKey: workDaysKey),
           let decoded = try? JSONDecoder().decode([WorkDay].self, from: data) {
            workDays = decoded
        }
    }
    
    /// Save work days to UserDefaults
    private func saveWorkDays() {
        if let encoded = try? JSONEncoder().encode(workDays) {
            UserDefaults.standard.set(encoded, forKey: workDaysKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Add or update a work day
    func addOrUpdateWorkDay(_ workDay: WorkDay) {
        // Check if there's already a work day for this date and job
        if let index = workDays.firstIndex(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: workDay.date) && $0.jobId == workDay.jobId
        }) {
            workDays[index] = workDay
        } else {
            workDays.append(workDay)
        }
        saveWorkDays()
    }
    
    /// Delete a work day
    func deleteWorkDay(_ workDay: WorkDay) {
        workDays.removeAll { $0.id == workDay.id }
        saveWorkDays()
    }
    
    /// Get work day for a specific date and job
    func workDay(for date: Date, jobId: UUID) -> WorkDay? {
        return workDays.first { 
            Calendar.current.isDate($0.date, inSameDayAs: date) && $0.jobId == jobId
        }
    }
    
    /// Get all work days for a specific date (can have multiple jobs)
    func workDays(for date: Date) -> [WorkDay] {
        return workDays.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Get total hours for a specific month
    func totalHoursForMonth(_ date: Date) -> Double {
        let calendar = Calendar.current
        return workDays
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            .reduce(0) { $0 + $1.hoursWorked }
    }
    
    /// Get total hours for a specific month and job
    func totalHoursForMonth(_ date: Date, jobId: UUID) -> Double {
        let calendar = Calendar.current
        return workDays
            .filter { 
                calendar.isDate($0.date, equalTo: date, toGranularity: .month) && $0.jobId == jobId
            }
            .reduce(0) { $0 + $1.hoursWorked }
    }
    
    /// Get total hours for a job in a date range (inclusive of start and end calendar days)
    func totalHours(from start: Date, to end: Date, jobId: UUID) -> Double {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return workDays
            .filter { workDay in
                guard workDay.jobId == jobId else { return false }
                let day = calendar.startOfDay(for: workDay.date)
                return day >= startDay && day <= endDay
            }
            .reduce(0) { $0 + $1.hoursWorked }
    }
    
    // MARK: - Jobs
    
    /// Load jobs from UserDefaults
    func loadJobs() {
        if let data = UserDefaults.standard.data(forKey: jobsKey),
           let decoded = try? JSONDecoder().decode([Job].self, from: data) {
            jobs = decoded
        }
    }
    
    /// Save jobs to UserDefaults
    private func saveJobs() {
        if let encoded = try? JSONEncoder().encode(jobs) {
            UserDefaults.standard.set(encoded, forKey: jobsKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Add a new job
    func addJob(_ job: Job) {
        jobs.append(job)
        saveJobs()
    }
    
    /// Update an existing job
    func updateJob(_ job: Job) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
            saveJobs()
        }
    }
    
    /// Delete a job
    func deleteJob(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        // Also delete all work days for this job
        workDays.removeAll { $0.jobId == job.id }
        saveJobs()
        saveWorkDays()
    }
    
    /// Get job by ID
    func job(withId id: UUID) -> Job? {
        return jobs.first { $0.id == id }
    }
    
    /// Check if user has any jobs
    var hasJobs: Bool {
        !jobs.isEmpty
    }
    
    var hasPersonalEvents: Bool {
        !personalEvents.isEmpty
    }
    
    // MARK: - Personal events (excluded from salary / forecast)
    
    func loadPersonalEvents() {
        guard let data = UserDefaults.standard.data(forKey: personalEventsKey),
              let decoded = try? JSONDecoder().decode([PersonalScheduleEvent].self, from: data) else {
            personalEvents = []
            return
        }
        personalEvents = decoded
    }
    
    private func savePersonalEvents() {
        if let encoded = try? JSONEncoder().encode(personalEvents) {
            UserDefaults.standard.set(encoded, forKey: personalEventsKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    func personalEvents(onSameDayAs date: Date) -> [PersonalScheduleEvent] {
        let cal = Calendar.current
        return personalEvents.filter { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.startMinutesFromMidnight < $1.startMinutesFromMidnight }
    }
    
    func addOrUpdatePersonalEvent(_ event: PersonalScheduleEvent) {
        var e = event
        e.date = Calendar.current.startOfDay(for: event.date)
        if let index = personalEvents.firstIndex(where: { $0.id == e.id }) {
            personalEvents[index] = e
        } else {
            personalEvents.append(e)
        }
        savePersonalEvents()
    }
    
    func deletePersonalEvent(_ event: PersonalScheduleEvent) {
        personalEvents.removeAll { $0.id == event.id }
        savePersonalEvents()
    }
    
    func deleteAllPersonalEvents(inMonth month: Date) {
        let cal = Calendar.current
        personalEvents.removeAll { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
        savePersonalEvents()
    }
    
    // MARK: - Schedule overlap (work + personal)
    
    /// Half-open interval [start, end) in absolute time.
    func hasScheduleOverlap(
        on day: Date,
        proposedStart: Date,
        proposedEnd: Date,
        ignoringPersonalEventId: UUID? = nil,
        ignoringWorkDayId: UUID? = nil,
        calendar: Calendar = .current
    ) -> Bool {
        guard proposedEnd > proposedStart else { return false }
        for block in scheduleTimeBlocks(onSameDayAs: day, calendar: calendar) {
            if let pid = block.personalEventId, pid == ignoringPersonalEventId { continue }
            if let wid = block.workDayId, wid == ignoringWorkDayId { continue }
            if proposedStart < block.end && proposedEnd > block.start { return true }
        }
        return false
    }
    
    private struct ScheduleTimeBlock {
        let start: Date
        let end: Date
        let workDayId: UUID?
        let personalEventId: UUID?
    }
    
    private func scheduleTimeBlocks(onSameDayAs date: Date, calendar: Calendar) -> [ScheduleTimeBlock] {
        var blocks: [ScheduleTimeBlock] = []
        for wd in workDays where calendar.isDate(wd.date, inSameDayAs: date) {
            if let interval = workDayInterval(wd, calendar: calendar) {
                blocks.append(ScheduleTimeBlock(start: interval.start, end: interval.end, workDayId: wd.id, personalEventId: nil))
            }
        }
        for ev in personalEvents where calendar.isDate(ev.date, inSameDayAs: date) {
            let interval = ev.absoluteInterval(calendar: calendar)
            blocks.append(ScheduleTimeBlock(start: interval.start, end: interval.end, workDayId: nil, personalEventId: ev.id))
        }
        return blocks
    }
    
    private func workDayInterval(_ workDay: WorkDay, calendar: Calendar) -> (start: Date, end: Date)? {
        let day = calendar.startOfDay(for: workDay.date)
        if let cs = workDay.customStartMinutesFromMidnight, let ce = workDay.customEndMinutesFromMidnight {
            guard let s = calendar.date(byAdding: .minute, value: cs, to: day),
                  var e = calendar.date(byAdding: .minute, value: ce, to: day) else { return nil }
            if e <= s { e = calendar.date(byAdding: .day, value: 1, to: e) ?? e }
            return (s, e)
        }
        if let job = job(withId: workDay.jobId), let sid = workDay.shiftId, let shift = job.shift(withId: sid) {
            guard let s = calendar.date(byAdding: .minute, value: shift.startMinutesFromMidnight, to: day),
                  var e = calendar.date(byAdding: .minute, value: shift.endMinutesFromMidnight, to: day) else { return nil }
            if e <= s { e = calendar.date(byAdding: .day, value: 1, to: e) ?? e }
            return (s, e)
        }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return (day, nextDay)
    }
}
