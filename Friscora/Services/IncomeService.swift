//
//  IncomeService.swift
//  Friscora
//
//  Service for managing incomes using UserDefaults
//

import Foundation
import Combine

/// Service for managing incomes
class IncomeService: ObservableObject {
    static let shared = IncomeService()
    
    @Published var incomes: [Income] = []
    
    private let incomesKey = "saved_incomes"
    
    private init() {
        loadIncomes()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadIncomes()
    }
    
    /// Load incomes from UserDefaults
    func loadIncomes() {
        if let data = UserDefaults.standard.data(forKey: incomesKey),
           let decoded = try? JSONDecoder().decode([Income].self, from: data) {
            incomes = decoded
        }
    }
    
    /// Save incomes to UserDefaults
    private func saveIncomes() {
        if let encoded = try? JSONEncoder().encode(incomes) {
            UserDefaults.standard.set(encoded, forKey: incomesKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Add a new income
    func addIncome(_ income: Income) {
        incomes.append(income)
        saveIncomes()
        
        // Debug print
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("💵 [INCOME ADDED]")
        print("   Amount: \(income.amount) \(income.currency)")
        print("   Date: \(formatter.string(from: income.date))")
        if let note = income.note {
            print("   Note: \(note)")
        }
        let monthTotal = totalIncomeForMonth(income.date)
        print("   Month Total Income: \(monthTotal) \(UserProfileService.shared.profile.currency)")
        print("─────────────────────────────────────────")
    }

    /// Add many incomes in one save/publish cycle.
    func addIncomes(_ newIncomes: [Income]) {
        guard !newIncomes.isEmpty else { return }
        incomes.append(contentsOf: newIncomes)
        saveIncomes()
    }

    /// Removes incomes created from a given statement import (used when deleting the imported PDF).
    func removeIncomes(withSourceStatementID statementID: UUID) {
        let before = incomes.count
        incomes.removeAll { $0.sourceStatementID == statementID }
        if incomes.count != before { saveIncomes() }
    }
    
    /// Update an income
    func updateIncome(_ income: Income) {
        if let index = incomes.firstIndex(where: { $0.id == income.id }) {
            let oldIncome = incomes[index]
            incomes[index] = income
            saveIncomes()
            
            // Debug print
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            print("🔄 [INCOME UPDATED]")
            print("   Old Amount: \(oldIncome.amount) \(oldIncome.currency)")
            print("   New Amount: \(income.amount) \(income.currency)")
            print("   Date: \(formatter.string(from: income.date))")
            let monthTotal = totalIncomeForMonth(income.date)
            print("   Month Total Income: \(monthTotal) \(UserProfileService.shared.profile.currency)")
            print("─────────────────────────────────────────")
        }
    }
    
    /// Delete an income
    func deleteIncome(_ income: Income) {
        if case .salary(let jobId, let paymentDate) = income.source {
            SalarySyncService.shared.recordUserDismissedSalary(jobId: jobId, paymentDate: paymentDate)
        }
        incomes.removeAll { $0.id == income.id }
        saveIncomes()
        
        // Debug print
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("🗑️ [INCOME DELETED]")
        print("   Amount: \(income.amount) \(income.currency)")
        print("   Date: \(formatter.string(from: income.date))")
        let monthTotal = totalIncomeForMonth(income.date)
        print("   Month Total Income (after delete): \(monthTotal) \(UserProfileService.shared.profile.currency)")
        print("─────────────────────────────────────────")
    }
    
    /// Get incomes for a specific month
    func incomesForMonth(_ date: Date) -> [Income] {
        let calendar = Calendar.current
        return incomes.filter { income in
            calendar.isDate(income.date, equalTo: date, toGranularity: .month)
        }
    }
    
    /// Returns true if an income already exists for this salary source (same job + payment date). Used to avoid duplicate salary sync.
    func hasIncome(for source: IncomeSource) -> Bool {
        guard case .salary(let jobId, let paymentDate) = source else { return false }
        let cal = Calendar.current
        return incomes.contains { income in
            guard case .salary(let existingJobId, let existingDate) = income.source else { return false }
            return existingJobId == jobId && cal.isDate(existingDate, inSameDayAs: paymentDate)
        }
    }
    
    /// Get total income for a month (converted to current currency)
    func totalIncomeForMonth(_ date: Date) -> Double {
        let monthIncomes = incomesForMonth(date)
        let currentCurrency = UserProfileService.shared.profile.currency
        var total: Double = 0
        
        for income in monthIncomes where income.countsTowardBalance {
            // For synchronous version, only sum same currency
            if income.currency == currentCurrency {
                total += income.amount
            } else {
                // Include with original amount
                total += income.amount
            }
        }
        
        return total
    }
}

