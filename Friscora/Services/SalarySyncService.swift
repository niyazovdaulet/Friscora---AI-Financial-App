//
//  SalarySyncService.swift
//  Friscora
//
//  Syncs scheduled work-shift salary to Dashboard income. Creates one income per
//  (job, payment date) when that date is today or in the past; skips future and duplicates.
//

import Foundation

/// One past salary event: pay date and amount for a job. Used to decide what income to create.
private struct PastPaymentEvent {
    let jobId: UUID
    let jobName: String
    let paymentDate: Date
    let amount: Double
}

final class SalarySyncService {
    static let shared = SalarySyncService()
    
    private let workScheduleService = WorkScheduleService.shared
    private let incomeService = IncomeService.shared
    private let calendar = Calendar.current
    
    /// User removed a synced salary income; do not recreate it for this (job, pay day) until the job is deleted (optional cleanup).
    private let userDismissedKey = "salary_sync_user_dismissed_v1"
    private var userDismissedSalaryKeys: Set<String> = []
    
    private init() {
        loadUserDismissed()
        NotificationCenter.default.addObserver(
            forName: .ICloudSyncDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadUserDismissedFromStorage()
        }
    }
    
    private func loadUserDismissed() {
        guard let data = UserDefaults.standard.data(forKey: userDismissedKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            userDismissedSalaryKeys = []
            return
        }
        userDismissedSalaryKeys = Set(decoded)
    }
    
    private func dismissalKey(jobId: UUID, paymentDate: Date) -> String {
        let day = calendar.startOfDay(for: paymentDate)
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(jobId.uuidString)|\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
    
    /// Call when the user deletes salary-sourced income so automatic sync does not recreate it.
    func recordUserDismissedSalary(jobId: UUID, paymentDate: Date) {
        let key = dismissalKey(jobId: jobId, paymentDate: paymentDate)
        guard !userDismissedSalaryKeys.contains(key) else { return }
        userDismissedSalaryKeys.insert(key)
        persistUserDismissed()
    }
    
    /// Remove dismissal entries for a job (e.g. when the job is deleted).
    func removeDismissals(forJobId jobId: UUID) {
        let prefix = jobId.uuidString + "|"
        let before = userDismissedSalaryKeys.count
        userDismissedSalaryKeys = userDismissedSalaryKeys.filter { !$0.hasPrefix(prefix) }
        if userDismissedSalaryKeys.count != before { persistUserDismissed() }
    }
    
    private func persistUserDismissed() {
        if let encoded = try? JSONEncoder().encode(Array(userDismissedSalaryKeys).sorted()) {
            UserDefaults.standard.set(encoded, forKey: userDismissedKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    private func isUserDismissed(jobId: UUID, paymentDate: Date) -> Bool {
        userDismissedSalaryKeys.contains(dismissalKey(jobId: jobId, paymentDate: paymentDate))
    }
    
    /// Reload from storage (e.g. after iCloud pull).
    func reloadUserDismissedFromStorage() {
        loadUserDismissed()
    }
    
    /// Call on app activation or when Work data changes. Creates missing salary incomes for all jobs (today or past only).
    func syncSalaryToIncome() {
        let today = calendar.startOfDay(for: Date())
        let currency = UserProfileService.shared.profile.currency
        
        for job in workScheduleService.jobs {
            let events = pastPaymentEvents(for: job, upTo: today)
            for event in events where event.amount > 0 {
                let source = IncomeSource.salary(jobId: event.jobId, paymentDate: event.paymentDate)
                guard !isUserDismissed(jobId: event.jobId, paymentDate: event.paymentDate) else { continue }
                guard !incomeService.hasIncome(for: source) else { continue }
                
                let income = Income(
                    amount: event.amount,
                    date: event.paymentDate,
                    note: event.jobName,
                    currency: currency,
                    source: source
                )
                incomeService.addIncome(income)
            }
        }
    }
    
    // MARK: - Past payment enumeration (mirrors WorkScheduleViewModel logic)
    
    private func pastPaymentEvents(for job: Job, upTo today: Date) -> [PastPaymentEvent] {
        var events: [PastPaymentEvent] = []
        
        switch job.salaryType {
        case .monthly:
            events = pastMonthlyPayments(for: job, upTo: today)
        case .twiceMonthly:
            events = pastTwiceMonthlyPayments(for: job, upTo: today)
        case .weekly:
            events = pastWeeklyPayments(for: job, upTo: today)
        case .daily:
            events = pastDailyPayments(for: job, upTo: today)
        }
        
        return events.filter { $0.paymentDate <= today }
    }
    
    private func effectivePaymentDay(_ day: Int, in month: Date) -> Int {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return day }
        let lastDay = range.upperBound - 1
        if day == 31 { return lastDay }
        if day == 30 { return min(30, lastDay) }
        return day
    }
    
    private func amountForJob(_ job: Job, hours: Double) -> Double {
        switch job.paymentType {
        case .hourly: return hours * (job.hourlyRate ?? 0)
        case .fixedMonthly: return hours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
        }
    }
    
    /// Monthly: work in baseMonth paid (baseMonth+1, day) or (baseMonth, day) for rolling.
    private func pastMonthlyPayments(for job: Job, upTo today: Date) -> [PastPaymentEvent] {
        var events: [PastPaymentEvent] = []
        guard let day = job.paymentDays.first else { return events }
        
        // Look back ~24 months to cover all past pay days
        guard let startMonth = calendar.date(byAdding: .month, value: -24, to: today) else { return events }
        var baseMonth = calendar.startOfMonth(startMonth)
        let endMonth = calendar.startOfMonth(today)
        
        while baseMonth <= endMonth {
            let effectiveDay = effectivePaymentDay(day, in: baseMonth)
            
            if job.salaryPaidNextMonth {
                // Paid next month: work in baseMonth → paid (baseMonth+1, day)
                guard let payMonth = calendar.date(byAdding: .month, value: 1, to: baseMonth) else { baseMonth = nextMonth(baseMonth); continue }
                let payDay = effectivePaymentDay(day, in: payMonth)
                guard let paymentDate = calendar.date(from: DateComponents(calendar: calendar, year: calendar.component(.year, from: payMonth), month: calendar.component(.month, from: payMonth), day: payDay)) else { baseMonth = nextMonth(baseMonth); continue }
                if paymentDate > today { baseMonth = nextMonth(baseMonth); continue }
                
                let hours = workScheduleService.totalHoursForMonth(baseMonth, jobId: job.id)
                let amount: Double
                switch job.paymentType {
                case .hourly: amount = hours * (job.hourlyRate ?? 0)
                case .fixedMonthly: amount = hours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
                }
                events.append(PastPaymentEvent(jobId: job.id, jobName: job.name, paymentDate: paymentDate, amount: amount))
            } else {
                // Rolling: paid on day D of baseMonth; period (D+1 of M-1) through (D of M)
                guard let paymentDate = calendar.date(from: DateComponents(calendar: calendar, year: calendar.component(.year, from: baseMonth), month: calendar.component(.month, from: baseMonth), day: effectiveDay)) else { baseMonth = nextMonth(baseMonth); continue }
                if paymentDate > today { baseMonth = nextMonth(baseMonth); continue }
                
                let (periodStart, periodEnd) = periodForPaymentDay(paymentDate)
                let hours = workScheduleService.totalHours(from: periodStart, to: periodEnd, jobId: job.id)
                let amount = amountForJob(job, hours: hours)
                events.append(PastPaymentEvent(jobId: job.id, jobName: job.name, paymentDate: paymentDate, amount: amount))
            }
            
            baseMonth = nextMonth(baseMonth)
        }
        
        return events
    }
    
    private func nextMonth(_ month: Date) -> Date {
        calendar.date(byAdding: .month, value: 1, to: month) ?? month
    }
    
    private func periodForPaymentDay(_ paymentDate: Date) -> (Date, Date) {
        let periodEnd = calendar.startOfDay(for: paymentDate)
        guard let oneMonthBefore = calendar.date(byAdding: .month, value: -1, to: paymentDate),
              let periodStart = calendar.date(byAdding: .day, value: 1, to: oneMonthBefore) else {
            return (periodEnd, periodEnd)
        }
        return (calendar.startOfDay(for: periodStart), periodEnd)
    }
    
    /// Twice monthly: two pay days per month.
    private func pastTwiceMonthlyPayments(for job: Job, upTo today: Date) -> [PastPaymentEvent] {
        var events: [PastPaymentEvent] = []
        let days = Array(job.paymentDays.prefix(2))
        guard let startMonth = calendar.date(byAdding: .month, value: -24, to: today) else { return events }
        var month = calendar.startOfMonth(startMonth)
        let endMonth = calendar.startOfMonth(today)
        
        while month <= endMonth {
            let monthHours = workScheduleService.totalHoursForMonth(month, jobId: job.id)
            let monthlyAmount: Double
            switch job.paymentType {
            case .hourly: monthlyAmount = monthHours * (job.hourlyRate ?? 0)
            case .fixedMonthly: monthlyAmount = monthHours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
            }
            let halfAmount = monthlyAmount / 2.0
            
            for day in days {
                let effectiveDay = effectivePaymentDay(day, in: month)
                guard let paymentDate = calendar.date(from: DateComponents(calendar: calendar, year: calendar.component(.year, from: month), month: calendar.component(.month, from: month), day: effectiveDay)) else { continue }
                if paymentDate > today { continue }
                events.append(PastPaymentEvent(jobId: job.id, jobName: job.name, paymentDate: paymentDate, amount: halfAmount))
            }
            month = nextMonth(month)
        }
        
        return events
    }
    
    /// Weekly: one payment per week on the job's weekday; amount = monthly hours/salary for that month / 4.
    private func pastWeeklyPayments(for job: Job, upTo today: Date) -> [PastPaymentEvent] {
        var events: [PastPaymentEvent] = []
        guard job.paymentDays.first != nil else { return events }
        
        var paymentDate = calendar.startOfDay(for: today)
        var weeksBack = 0
        let maxWeeks = 52
        
        while weeksBack < maxWeeks {
            let monthStart = calendar.startOfMonth(paymentDate)
            let monthHours = workScheduleService.totalHoursForMonth(monthStart, jobId: job.id)
            let monthlyAmount: Double
            switch job.paymentType {
            case .hourly: monthlyAmount = monthHours * (job.hourlyRate ?? 0)
            case .fixedMonthly: monthlyAmount = monthHours > 0 ? (job.fixedMonthlyAmount ?? 0) : 0
            }
            let weeklyAmount = monthlyAmount / 4.0
            
            if weeklyAmount > 0 {
                events.append(PastPaymentEvent(jobId: job.id, jobName: job.name, paymentDate: paymentDate, amount: weeklyAmount))
            }
            
            guard let next = calendar.date(byAdding: .weekOfYear, value: -1, to: paymentDate) else { break }
            paymentDate = next
            weeksBack += 1
        }
        
        return events
    }
    
    /// Daily: one payment per work day, paid next month same day.
    private func pastDailyPayments(for job: Job, upTo today: Date) -> [PastPaymentEvent] {
        var events: [PastPaymentEvent] = []
        let workDays = workScheduleService.workDays.filter { $0.jobId == job.id }
        
        for workDay in workDays {
            guard let paymentDate = calendar.date(byAdding: .month, value: 1, to: workDay.date) else { continue }
            let paymentDayStart = calendar.startOfDay(for: paymentDate)
            if paymentDayStart > today { continue }
            
            let dailyAmount: Double
            switch job.paymentType {
            case .hourly:
                dailyAmount = workDay.hoursWorked * (job.hourlyRate ?? 0)
            case .fixedMonthly:
                dailyAmount = (job.fixedMonthlyAmount ?? 0) / 30.0
            }
            if dailyAmount > 0 {
                events.append(PastPaymentEvent(jobId: job.id, jobName: job.name, paymentDate: paymentDayStart, amount: dailyAmount))
            }
        }
        
        return events
    }
}

private extension Calendar {
    func startOfMonth(_ date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
