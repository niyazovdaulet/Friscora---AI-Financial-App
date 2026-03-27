//
//  WorkScheduleService.swift
//  Friscora
//
//  Service for managing work schedule data with multiple jobs
//

import Foundation
import Combine

/// Service for managing work schedule
class WorkScheduleService: ObservableObject {
    static let shared = WorkScheduleService()
    
    @Published var workDays: [WorkDay] = []
    @Published var jobs: [Job] = []
    
    private let workDaysKey = "saved_work_days"
    private let jobsKey = "saved_jobs"
    
    private init() {
        loadWorkDays()
        loadJobs()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadWorkDays()
        loadJobs()
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
}
