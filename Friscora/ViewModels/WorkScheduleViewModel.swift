//
//  WorkScheduleViewModel.swift
//  Friscora
//
//  ViewModel for work schedule view with multiple jobs
//

import Foundation
import Combine
import SwiftUI

class WorkScheduleViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var totalHours: Double = 0
    @Published var estimatedSalary: Double = 0
    @Published var averageDailyHours: Double = 0
    @Published var projectedPayments: [ProjectedPayment] = []
    
    private let workScheduleService = WorkScheduleService.shared
    private let userProfileService = UserProfileService.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// Calendar with week starting on Monday (used for Work Tab schedule grid).
    var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    struct ProjectedPayment: Identifiable {
        let id: UUID
        let date: Date
        let amount: Double
        let jobName: String
        let jobColor: Color
        
        init(id: UUID = UUID(), date: Date, amount: Double, jobName: String, jobColor: Color) {
            self.id = id
            self.date = date
            self.amount = amount
            self.jobName = jobName
            self.jobColor = jobColor
        }
    }
    
    init() {
        setupSubscriptions()
        updateCalculations()
    }
    
    private func setupSubscriptions() {
        // Update when work days change
        workScheduleService.$workDays
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCalculations()
            }
            .store(in: &cancellables)
        
        // Update when jobs change
        workScheduleService.$jobs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateCalculations()
            }
            .store(in: &cancellables)
        
        // Update when selected month changes - debounce to handle rapid tapping
        $selectedMonth
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] newMonth in
                self?.updateCalculationsForMonth(newMonth)
            }
            .store(in: &cancellables)
    }
    
    func updateCalculations() {
        updateCalculationsForMonth(selectedMonth)
    }
    
    private func updateCalculationsForMonth(_ month: Date) {
        // Ensure we're using the current selectedMonth (in case of rapid changes)
        let targetMonth = selectedMonth
        
        // Calculate total hours for selected month
        let hours = workScheduleService.totalHoursForMonth(targetMonth)
        
        // Calculate estimated salary for selected month (sum across all jobs)
        let salary = calculateTotalSalaryForMonth(targetMonth)
        
        // Calculate average daily hours
        let workDaysInMonth = workDaysForMonth(targetMonth)
        let avgHours: Double
        if !workDaysInMonth.isEmpty {
            avgHours = hours / Double(workDaysInMonth.count)
        } else {
            avgHours = 0
        }
        
        // Calculate projected payments for NEXT month
        let payments = calculateProjectedPaymentsForMonth(targetMonth)
        
        // Update all properties at once to avoid partial state updates
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Only update if the month hasn't changed during calculation
            if self.calendar.isDate(self.selectedMonth, equalTo: targetMonth, toGranularity: .month) {
                self.totalHours = hours
                self.estimatedSalary = salary
                self.averageDailyHours = avgHours
                self.projectedPayments = payments
            }
        }
    }
    
    private func workDaysForMonth(_ date: Date) -> [WorkDay] {
        return workScheduleService.workDays.filter { workDay in
            calendar.isDate(workDay.date, equalTo: date, toGranularity: .month)
        }
    }
    
    /// For monthly payment: day 31 means "last day of month"; day 30 means "last day" when month has fewer than 30 days. Other days are used as-is.
    private func effectivePaymentDay(_ day: Int, in month: Date) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return day }
        let lastDayOfMonth = range.upperBound - 1
        if day == 31 {
            return lastDayOfMonth
        }
        if day == 30 {
            return min(30, lastDayOfMonth)
        }
        return day
    }
    
    private func calculateTotalSalaryForMonth(_ date: Date) -> Double {
        var totalSalary: Double = 0
        
        for job in workScheduleService.jobs {
            let jobHours = workScheduleService.totalHoursForMonth(date, jobId: job.id)
            
            switch job.paymentType {
            case .hourly:
                totalSalary += jobHours * (job.hourlyRate ?? 0)
            case .fixedMonthly:
                // For fixed monthly, check if there are any work days in the month
                if jobHours > 0 {
                    totalSalary += (job.fixedMonthlyAmount ?? 0)
                }
            }
        }
        
        return totalSalary
    }
    
    private func calculateProjectedPaymentsForMonth(_ month: Date) -> [ProjectedPayment] {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else {
            return []
        }
        
        // Only show jobs that have at least one work day in the selected month
        let jobsWithWork = workScheduleService.jobs.filter { job in
            workScheduleService.totalHoursForMonth(month, jobId: job.id) > 0
        }
        
        var payments: [ProjectedPayment] = []
        for job in jobsWithWork {
            let jobPayments = calculatePaymentsForJob(job, in: nextMonth, baseMonth: month)
            payments.append(contentsOf: jobPayments)
        }
        
        return payments.sorted { $0.date < $1.date }
    }
    
    private func calculatePaymentsForJob(_ job: Job, in month: Date, baseMonth: Date) -> [ProjectedPayment] {
        var payments: [ProjectedPayment] = []
        let baseMonthHours = workScheduleService.totalHoursForMonth(baseMonth, jobId: job.id)
        
        switch job.paymentType {
        case .hourly:
            break
        case .fixedMonthly:
            break
        }
        
        switch job.salaryType {
        case .monthly:
            guard let day = job.paymentDays.first else { return payments }
            let effectiveDay = effectivePaymentDay(day, in: baseMonth)
            
            if job.salaryPaidNextMonth {
                // Yes: work in February → paid March 17 (next month, same day)
                var components = calendar.dateComponents([.year, .month], from: month)
                components.day = effectivePaymentDay(day, in: month)
                if let paymentDate = calendar.date(from: components) {
                    let amount: Double
                    switch job.paymentType {
                    case .hourly: amount = baseMonthHours * (job.hourlyRate ?? 0)
                    case .fixedMonthly: amount = baseMonthHours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
                    }
                    payments.append(ProjectedPayment(
                        date: paymentDate,
                        amount: amount,
                        jobName: job.name,
                        jobColor: job.color
                    ))
                }
            } else {
                // No: rolling period. Feb 17 pays Jan 18–Feb 17; Mar 17 pays Feb 18–Mar 17.
                // Show payment in base month and in next month
                if let basePaymentDate = calendar.date(from: {
                    var c = calendar.dateComponents([.year, .month], from: baseMonth)
                    c.day = effectiveDay
                    return c
                }()) {
                    let (periodStart, periodEnd) = periodForPaymentDay(basePaymentDate)
                    let hours = workScheduleService.totalHours(from: periodStart, to: periodEnd, jobId: job.id)
                    let amount = amountForJob(job, hours: hours)
                    payments.append(ProjectedPayment(date: basePaymentDate, amount: amount, jobName: job.name, jobColor: job.color))
                }
                if let nextPaymentDate = calendar.date(from: {
                    var c = calendar.dateComponents([.year, .month], from: month)
                    c.day = effectivePaymentDay(day, in: month)
                    return c
                }()) {
                    let (periodStart, periodEnd) = periodForPaymentDay(nextPaymentDate)
                    let hours = workScheduleService.totalHours(from: periodStart, to: periodEnd, jobId: job.id)
                    let amount = amountForJob(job, hours: hours)
                    payments.append(ProjectedPayment(date: nextPaymentDate, amount: amount, jobName: job.name, jobColor: job.color))
                }
            }
            
        case .twiceMonthly:
            let monthlyAmount: Double
            switch job.paymentType {
            case .hourly: monthlyAmount = baseMonthHours * (job.hourlyRate ?? 0)
            case .fixedMonthly: monthlyAmount = baseMonthHours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
            }
            let days = Array(job.paymentDays.prefix(2))
            for day in days {
                let effectiveDay = effectivePaymentDay(day, in: baseMonth)
                var components = calendar.dateComponents([.year, .month], from: baseMonth)
                components.day = effectiveDay
                if let paymentDate = calendar.date(from: components) {
                    payments.append(ProjectedPayment(
                        date: paymentDate,
                        amount: monthlyAmount / 2.0,
                        jobName: job.name,
                        jobColor: job.color
                    ))
                }
            }
            
        case .weekly:
            let monthlyAmount: Double
            switch job.paymentType {
            case .hourly: monthlyAmount = baseMonthHours * (job.hourlyRate ?? 0)
            case .fixedMonthly: monthlyAmount = baseMonthHours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
            }
            if let dayOfWeek = job.paymentDays.first {
                // Get the first day of the month
                let components = calendar.dateComponents([.year, .month], from: month)
                guard let firstDayOfMonth = calendar.date(from: components) else { break }
                
                // Find the first occurrence of the selected weekday
                let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
                let daysToAdd = (dayOfWeek - firstWeekday + 7) % 7
                
                guard var paymentDate = calendar.date(byAdding: .day, value: daysToAdd, to: firstDayOfMonth) else { break }
                
                // Generate weekly payments for the month
                while calendar.isDate(paymentDate, equalTo: month, toGranularity: .month) {
                    let weeklyAmount = monthlyAmount / 4.0 // Approximate
                    payments.append(ProjectedPayment(
                        date: paymentDate,
                        amount: weeklyAmount,
                        jobName: job.name,
                        jobColor: job.color
                    ))
                    
                    guard let nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: paymentDate) else { break }
                    paymentDate = nextDate
                    
                    if payments.count > 10 { // Safety limit
                        break
                    }
                }
            }
            
        case .daily:
            // For daily, use work days from base month as reference
            let workDays = workDaysForMonth(baseMonth).filter { $0.jobId == job.id }
            for workDay in workDays {
                let dailyAmount: Double
                switch job.paymentType {
                case .hourly:
                    dailyAmount = workDay.hoursWorked * (job.hourlyRate ?? 0)
                case .fixedMonthly:
                    dailyAmount = (job.fixedMonthlyAmount ?? 0) / 30.0 // Approximate daily
                }
                
                // Project to same day in next month
                if let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: workDay.date) {
                    payments.append(ProjectedPayment(
                        date: nextMonthDate,
                        amount: dailyAmount,
                        jobName: job.name,
                        jobColor: job.color
                    ))
                }
            }
        }
        
        return payments
    }
    
    /// For rolling monthly: payment on D pays period (D - 1 month + 1 day) through D. Returns (startOfPeriod, endOfPeriod) as start-of-day dates.
    private func periodForPaymentDay(_ paymentDate: Date) -> (Date, Date) {
        let periodEnd = calendar.startOfDay(for: paymentDate)
        guard let oneMonthBefore = calendar.date(byAdding: .month, value: -1, to: paymentDate),
              let periodStart = calendar.date(byAdding: .day, value: 1, to: oneMonthBefore) else {
            return (periodEnd, periodEnd)
        }
        return (calendar.startOfDay(for: periodStart), periodEnd)
    }
    
    private func amountForJob(_ job: Job, hours: Double) -> Double {
        switch job.paymentType {
        case .hourly: return hours * (job.hourlyRate ?? 0)
        case .fixedMonthly: return hours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
        }
    }
    
    func monthString(for date: Date) -> String {
        LocalizationManager.shared.monthYearString(for: date)
    }
    
    func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
    
    func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
        }
    }
}
