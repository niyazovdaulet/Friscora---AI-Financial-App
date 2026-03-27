//
//  Job.swift
//  Friscora
//
//  Model representing a job/work position
//

import Foundation
import SwiftUI

/// Payment type for a job
enum PaymentType: String, CaseIterable, Codable {
    case hourly = "Hourly Rate"
    case fixedMonthly = "Fixed Monthly"
    
    var displayName: String {
        return rawValue
    }
    
    /// Localization key for display in UI (use with L10n).
    var localizationKey: String {
        switch self {
        case .hourly: return "job.payment_type.hourly"
        case .fixedMonthly: return "job.payment_type.fixed_monthly"
        }
    }
}

/// Job model
struct Job: Identifiable, Codable {
    let id: UUID
    var name: String
    var paymentType: PaymentType
    var hourlyRate: Double?
    var fixedMonthlyAmount: Double?
    var salaryType: SalaryType
    var paymentDays: [Int] // Day of month for monthly/twiceMonthly, weekday for weekly (1-7, 1=Sunday)
    var colorHex: String // Hex color string for calendar display
    /// Shifts define named time ranges (e.g. Morning 9:00–17:00). When set, user picks a shift per day instead of entering hours.
    var shifts: [Shift]
    /// When true (Yes): work in month M is paid on day D of month M+1. When false (No): paid on day D of month M; next payment covers (D+1 of M-1) through (D of M).
    var salaryPaidNextMonth: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        paymentType: PaymentType,
        hourlyRate: Double? = nil,
        fixedMonthlyAmount: Double? = nil,
        salaryType: SalaryType = .monthly,
        paymentDays: [Int] = [],
        colorHex: String = "2EC4B6", // Default teal
        shifts: [Shift] = [],
        salaryPaidNextMonth: Bool = true
    ) {
        self.id = id
        self.name = name
        self.paymentType = paymentType
        self.hourlyRate = hourlyRate
        self.fixedMonthlyAmount = fixedMonthlyAmount
        self.salaryType = salaryType
        self.paymentDays = paymentDays
        self.colorHex = colorHex
        self.shifts = shifts
        self.salaryPaidNextMonth = salaryPaidNextMonth
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, paymentType, hourlyRate, fixedMonthlyAmount, salaryType, paymentDays, colorHex, shifts, salaryPaidNextMonth
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        paymentType = try c.decode(PaymentType.self, forKey: .paymentType)
        hourlyRate = try c.decodeIfPresent(Double.self, forKey: .hourlyRate)
        fixedMonthlyAmount = try c.decodeIfPresent(Double.self, forKey: .fixedMonthlyAmount)
        salaryType = try c.decode(SalaryType.self, forKey: .salaryType)
        paymentDays = try c.decode([Int].self, forKey: .paymentDays)
        colorHex = try c.decode(String.self, forKey: .colorHex)
        shifts = try c.decodeIfPresent([Shift].self, forKey: .shifts) ?? []
        salaryPaidNextMonth = try c.decodeIfPresent(Bool.self, forKey: .salaryPaidNextMonth) ?? true
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(paymentType, forKey: .paymentType)
        try c.encodeIfPresent(hourlyRate, forKey: .hourlyRate)
        try c.encodeIfPresent(fixedMonthlyAmount, forKey: .fixedMonthlyAmount)
        try c.encode(salaryType, forKey: .salaryType)
        try c.encode(paymentDays, forKey: .paymentDays)
        try c.encode(colorHex, forKey: .colorHex)
        try c.encode(shifts, forKey: .shifts)
        try c.encode(salaryPaidNextMonth, forKey: .salaryPaidNextMonth)
    }
    
    /// Get the color for this job
    var color: Color {
        Color(hex: colorHex)
    }
    
    /// Shift by id (for displaying which shift was worked).
    func shift(withId id: UUID) -> Shift? {
        shifts.first { $0.id == id }
    }
    
    /// Get payment amount per hour (for hourly) or per month (for fixed)
    func getPaymentAmount() -> Double {
        switch paymentType {
        case .hourly:
            return hourlyRate ?? 0.0
        case .fixedMonthly:
            return fixedMonthlyAmount ?? 0.0
        }
    }
}
