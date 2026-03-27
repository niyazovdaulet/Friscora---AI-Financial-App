//
//  WorkScheduleSettings.swift
//  Friscora
//
//  Settings model for work schedule configuration
//

import Foundation

/// Salary payment type enum
enum SalaryType: String, CaseIterable, Codable {
    case monthly = "Once per month"
    case weekly = "Weekly"
    case daily = "Daily"
    case twiceMonthly = "Twice per month"
    
    var displayName: String {
        return rawValue
    }
    
    /// Localization key for display in UI (use with L10n).
    var localizationKey: String {
        switch self {
        case .monthly: return "job.salary_type.monthly"
        case .weekly: return "job.salary_type.weekly"
        case .daily: return "job.salary_type.daily"
        case .twiceMonthly: return "job.salary_type.twice_monthly"
        }
    }
}

/// Work schedule settings model
struct WorkScheduleSettings: Codable {
    var hourlyRate: Double
    var salaryType: SalaryType
    var salaryDates: [Date] // Dates for monthly/twiceMonthly, weekday component for weekly
    var weeklyDayOfWeek: Int? // 1 = Sunday, 2 = Monday, etc. (for weekly type)
    
    init(
        hourlyRate: Double = 0.0,
        salaryType: SalaryType = .monthly,
        salaryDates: [Date] = [],
        weeklyDayOfWeek: Int? = nil
    ) {
        self.hourlyRate = hourlyRate
        self.salaryType = salaryType
        self.salaryDates = salaryDates
        self.weeklyDayOfWeek = weeklyDayOfWeek
    }
}
