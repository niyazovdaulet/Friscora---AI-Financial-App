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
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var workDays: [WorkDay] = []
    @Published var jobs: [Job] = []
    @Published var personalEvents: [PersonalScheduleEvent] = []
    @Published var workPatterns: [WorkPattern] = []
    @Published var bulkOperations: [BulkOperation] = []
    @Published var patternSuggestion: SchedulePatternSuggestion?
    
    private let workDaysKey = "saved_work_days"
    private let jobsKey = "saved_jobs"
    private let personalEventsKey = "saved_personal_schedule_events"
    private let workPatternsKey = "work_patterns_v1"
    private let bulkOperationsKey = "bulk_operations_v1"
    private let dismissedPatternSuggestionsKey = "dismissed_pattern_suggestions_v1"
    
    private var suggestionRefreshTask: Task<Void, Never>?
    /// Fingerprints of dismissed earning-aware suggestions (30-day TTL).
    private(set) var dismissedPatternSuggestionTimestamps: [String: TimeInterval] = [:]
    
    private init() {
        loadWorkDays()
        loadJobs()
        loadPersonalEvents()
        loadWorkPatterns()
        loadBulkOperations()
        loadDismissedPatternSuggestions()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
        $workDays
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.schedulePatternSuggestionRefresh()
            }
            .store(in: &cancellables)
        $jobs
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.schedulePatternSuggestionRefresh()
            }
            .store(in: &cancellables)
        DispatchQueue.main.async { [weak self] in
            self?.schedulePatternSuggestionRefresh()
        }
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadWorkDays()
        loadJobs()
        loadPersonalEvents()
        loadWorkPatterns()
        loadBulkOperations()
        loadDismissedPatternSuggestions()
        schedulePatternSuggestionRefresh()
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
    
    /// Start/end minutes from midnight on the work day when custom times or a linked shift define a window; `nil` for hours-only entries with no schedule window.
    func resolvedDisplayTimeRangeMinutes(for workDay: WorkDay, calendar: Calendar) -> (start: Int, end: Int)? {
        if let cs = workDay.customStartMinutesFromMidnight, let ce = workDay.customEndMinutesFromMidnight {
            return (cs, ce)
        }
        if let job = job(withId: workDay.jobId), let sid = workDay.shiftId, let shift = job.shift(withId: sid) {
            return (shift.startMinutesFromMidnight, shift.endMinutesFromMidnight)
        }
        return nil
    }

    private func workDayInterval(_ workDay: WorkDay, calendar: Calendar) -> (start: Date, end: Date)? {
        let day = calendar.startOfDay(for: workDay.date)
        if let (sm, em) = resolvedDisplayTimeRangeMinutes(for: workDay, calendar: calendar) {
            guard let s = calendar.date(byAdding: .minute, value: sm, to: day),
                  var e = calendar.date(byAdding: .minute, value: em, to: day) else { return nil }
            if e <= s { e = calendar.date(byAdding: .day, value: 1, to: e) ?? e }
            return (s, e)
        }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        return (day, nextDay)
    }
    
    // MARK: - Work patterns & bulk history
    
    func loadWorkPatterns() {
        if let data = UserDefaults.standard.data(forKey: workPatternsKey),
           let decoded = try? JSONDecoder().decode([WorkPattern].self, from: data) {
            workPatterns = decoded
        } else {
            workPatterns = []
        }
    }
    
    private func saveWorkPatterns() {
        if let encoded = try? JSONEncoder().encode(workPatterns) {
            UserDefaults.standard.set(encoded, forKey: workPatternsKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    func loadBulkOperations() {
        if let data = UserDefaults.standard.data(forKey: bulkOperationsKey),
           let decoded = try? JSONDecoder().decode([BulkOperation].self, from: data) {
            bulkOperations = decoded
        } else {
            bulkOperations = []
        }
    }
    
    private func saveBulkOperations() {
        if let encoded = try? JSONEncoder().encode(bulkOperations) {
            UserDefaults.standard.set(encoded, forKey: bulkOperationsKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    func addOrUpdateWorkPattern(_ pattern: WorkPattern) {
        if let idx = workPatterns.firstIndex(where: { $0.id == pattern.id }) {
            workPatterns[idx] = pattern
        } else {
            workPatterns.append(pattern)
        }
        saveWorkPatterns()
    }
    
    func deleteWorkPattern(id: UUID, removeGeneratedWorkDays: Bool) {
        workPatterns.removeAll { $0.id == id }
        saveWorkPatterns()
        if removeGeneratedWorkDays {
            let toRemove = workDays.filter { $0.patternId == id }.map(\.id)
            performWorkDayBatch(toAdd: [], toRemove: toRemove, operationRecord: nil)
        }
    }
    
    /// Bulk add/remove work days in one save. Only entry point for pattern/bulk mutations.
    func performWorkDayBatch(
        toAdd: [WorkDay],
        toRemove: [UUID],
        operationRecord: BulkOperation?
    ) {
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        let removeSet = Set(toRemove)
        var list = workDays.filter { !removeSet.contains($0.id) }
        for wd in toAdd {
            if let index = list.firstIndex(where: {
                cal.isDate($0.date, inSameDayAs: wd.date) && $0.jobId == wd.jobId
            }) {
                list[index] = wd
            } else {
                list.append(wd)
            }
        }
        workDays = list
        saveWorkDays()
        if let record = operationRecord {
            var ops = bulkOperations
            ops.insert(record, at: 0)
            if ops.count > 20 {
                ops = Array(ops.prefix(20))
            }
            bulkOperations = ops
            saveBulkOperations()
        }
    }
    
    func removeBulkOperationRecord(id: UUID) {
        bulkOperations.removeAll { $0.id == id }
        saveBulkOperations()
    }
    
    /// Sets `patternId` on every work day with the given bulk id (one `saveWorkDays`).
    func assignPatternIdToWorkDays(bulkOperationId: UUID, patternId: UUID) {
        var list = workDays
        for i in list.indices where list[i].bulkOperationId == bulkOperationId {
            list[i].patternId = patternId
        }
        workDays = list
        saveWorkDays()
    }
    
    /// Applies all matching days in the pattern’s date range; tags rows with `patternId` and a new bulk id.
    func applyWorkPatternNow(
        _ pattern: WorkPattern,
        replaceExistingForJob: Bool = true,
        skipPersonalEventDays: Bool = false
    ) -> BulkOperation? {
        guard let job = job(withId: pattern.jobId),
              let shiftId = pattern.shiftId,
              let shift = job.shift(withId: shiftId) else { return nil }
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        let days = ScheduleWeekday.allDays(
            from: pattern.startDate,
            to: pattern.endDate,
            weekdays: Set(pattern.weekdays),
            calendar: cal
        )
        let bulkId = UUID()
        var toAdd: [WorkDay] = []
        var toRemove: [UUID] = []
        var replaced = 0
        var skipped = 0
        
        for day in days {
            let dayStart = cal.startOfDay(for: day)
            if skipPersonalEventDays, !personalEvents(onSameDayAs: dayStart).isEmpty {
                skipped += 1
                continue
            }
            let existing = workDay(for: dayStart, jobId: pattern.jobId)
            let interval = patternApplyInterval(shift: shift, day: dayStart, calendar: cal)
            if let ex = existing {
                if !replaceExistingForJob {
                    skipped += 1
                    continue
                }
                if hasScheduleOverlap(
                    on: dayStart,
                    proposedStart: interval.start,
                    proposedEnd: interval.end,
                    ignoringWorkDayId: ex.id,
                    calendar: cal
                ) {
                    skipped += 1
                    continue
                }
                toRemove.append(ex.id)
                replaced += 1
            } else {
                if hasScheduleOverlap(
                    on: dayStart,
                    proposedStart: interval.start,
                    proposedEnd: interval.end,
                    ignoringWorkDayId: nil,
                    calendar: cal
                ) {
                    skipped += 1
                    continue
                }
            }
            let wd = WorkDay(
                date: dayStart,
                hoursWorked: shift.durationHours,
                jobId: pattern.jobId,
                shiftId: shiftId,
                bulkOperationId: bulkId,
                patternId: pattern.id
            )
            toAdd.append(wd)
        }
        
        let label = pattern.name
        let op = BulkOperation(
            id: bulkId,
            jobId: pattern.jobId,
            shiftId: shiftId,
            patternId: pattern.id,
            appliedAt: Date(),
            dayCount: toAdd.count,
            replacedCount: replaced,
            skippedCount: skipped,
            label: label
        )
        performWorkDayBatch(toAdd: toAdd, toRemove: toRemove, operationRecord: op)
        var updated = pattern
        updated.lastAppliedAt = Date()
        updated.totalDaysGenerated += toAdd.count
        addOrUpdateWorkPattern(updated)
        return op
    }
    
    private func patternApplyInterval(shift: Shift, day: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let dayStart = calendar.startOfDay(for: day)
        guard let s = calendar.date(byAdding: .minute, value: shift.startMinutesFromMidnight, to: dayStart),
              var e = calendar.date(byAdding: .minute, value: shift.endMinutesFromMidnight, to: dayStart) else {
            return (dayStart, dayStart)
        }
        if e <= s { e = calendar.date(byAdding: .day, value: 1, to: e) ?? e }
        return (s, e)
    }
    
    func workDays(withBulkOperationId id: UUID) -> [WorkDay] {
        workDays.filter { $0.bulkOperationId == id }
    }
    
    // MARK: - Pattern suggestion suppression
    
    func loadDismissedPatternSuggestions() {
        guard let data = UserDefaults.standard.data(forKey: dismissedPatternSuggestionsKey),
              let raw = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            dismissedPatternSuggestionTimestamps = [:]
            return
        }
        let now = Date().timeIntervalSince1970
        let ttl: TimeInterval = 30 * 24 * 3600
        dismissedPatternSuggestionTimestamps = raw.filter { now - $0.value < ttl }
        if dismissedPatternSuggestionTimestamps.count != raw.count {
            persistDismissedPatternSuggestions()
        }
    }
    
    func dismissPatternSuggestion(fingerprint: String) {
        dismissedPatternSuggestionTimestamps[fingerprint] = Date().timeIntervalSince1970
        persistDismissedPatternSuggestions()
        patternSuggestion = nil
        schedulePatternSuggestionRefresh()
    }
    
    private func persistDismissedPatternSuggestions() {
        if let data = try? JSONEncoder().encode(dismissedPatternSuggestionTimestamps) {
            UserDefaults.standard.set(data, forKey: dismissedPatternSuggestionsKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    // MARK: - Pattern suggestion (background)
    
    func schedulePatternSuggestionRefresh() {
        suggestionRefreshTask?.cancel()
        let workDaysSnapshot = workDays
        let jobsSnapshot = jobs
        let patternsSnapshot = workPatterns
        let dismissed = dismissedPatternSuggestionTimestamps
        suggestionRefreshTask = Task.detached(priority: .utility) { [weak self] in
            let suggestion = SchedulePatternDetector.computeSuggestion(
                workDays: workDaysSnapshot,
                jobs: jobsSnapshot,
                existingPatterns: patternsSnapshot,
                dismissedFingerprints: dismissed
            )
            await MainActor.run {
                guard let self else { return }
                self.patternSuggestion = suggestion
            }
        }
    }
}
