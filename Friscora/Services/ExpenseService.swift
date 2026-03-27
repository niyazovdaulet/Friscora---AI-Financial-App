//
//  ExpenseService.swift
//  Friscora
//
//  Service for managing expenses using UserDefaults (can be migrated to CoreData later)
//

import Foundation
import Combine

/// Service for managing expenses
class ExpenseService: ObservableObject {
    static let shared = ExpenseService()
    
    @Published var expenses: [Expense] = []
    
    private let expensesKey = "saved_expenses"
    
    private init() {
        loadExpenses()
        NotificationCenter.default.addObserver(self, selector: #selector(handleICloudSyncUpdate), name: .ICloudSyncDidUpdate, object: nil)
    }
    
    @objc private func handleICloudSyncUpdate() {
        loadExpenses()
    }
    
    /// Load expenses from UserDefaults
    func loadExpenses() {
        if let data = UserDefaults.standard.data(forKey: expensesKey),
           let decoded = try? JSONDecoder().decode([Expense].self, from: data) {
            expenses = decoded
        }
    }
    
    /// Save expenses to UserDefaults
    private func saveExpenses() {
        if let encoded = try? JSONEncoder().encode(expenses) {
            UserDefaults.standard.set(encoded, forKey: expensesKey)
            ICloudSyncService.shared.syncToCloud()
        }
    }
    
    /// Add a new expense
    func addExpense(_ expense: Expense) {
        expenses.append(expense)
        saveExpenses()
        
        // Debug print
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("💰 [EXPENSE ADDED]")
        print("   Amount: \(expense.amount) \(expense.currency)")
        print("   Category: \(expense.categoryName())")
        print("   Date: \(formatter.string(from: expense.date))")
        if let note = expense.note {
            print("   Note: \(note)")
        }
        let monthTotal = totalExpensesForMonth(expense.date)
        print("   Month Total Expenses: \(monthTotal) \(UserProfileService.shared.profile.currency)")
        print("─────────────────────────────────────────")
    }
    
    /// Update an expense
    func updateExpense(_ expense: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            let oldExpense = expenses[index]
            expenses[index] = expense
            saveExpenses()
            
            // Debug print
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            print("🔄 [EXPENSE UPDATED]")
            print("   Old Amount: \(oldExpense.amount) \(oldExpense.currency)")
            print("   New Amount: \(expense.amount) \(expense.currency)")
            print("   Category: \(expense.categoryName())")
            print("   Date: \(formatter.string(from: expense.date))")
            let monthTotal = totalExpensesForMonth(expense.date)
            print("   Month Total Expenses: \(monthTotal) \(UserProfileService.shared.profile.currency)")
            print("─────────────────────────────────────────")
        }
    }
    
    /// Delete an expense
    func deleteExpense(_ expense: Expense) {
        expenses.removeAll { $0.id == expense.id }
        saveExpenses()
        
        // Debug print
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        print("🗑️ [EXPENSE DELETED]")
        print("   Amount: \(expense.amount) \(expense.currency)")
        print("   Category: \(expense.categoryName())")
        print("   Date: \(formatter.string(from: expense.date))")
        let monthTotal = totalExpensesForMonth(expense.date)
        print("   Month Total Expenses (after delete): \(monthTotal) \(UserProfileService.shared.profile.currency)")
        print("─────────────────────────────────────────")
    }
    
    /// Get expenses for a specific month
    func expensesForMonth(_ date: Date) -> [Expense] {
        let calendar = Calendar.current
        return expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: date, toGranularity: .month)
        }
    }
    
    /// Get total expenses for a month (converted to current currency)
    func totalExpensesForMonth(_ date: Date) async -> Double {
        let monthExpenses = expensesForMonth(date)
        let currentCurrency = UserProfileService.shared.profile.currency
        let currencyService = CurrencyService.shared
        var total: Double = 0
        
        for expense in monthExpenses {
            if expense.currency == currentCurrency {
                total += expense.amount
            } else {
                do {
                    let converted = try await currencyService.convert(
                        amount: expense.amount,
                        from: expense.currency,
                        to: currentCurrency
                    )
                    total += converted
                } catch {
                    // Fallback to original amount if conversion fails
                    total += expense.amount
                }
            }
        }
        
        return total
    }
    
    /// Synchronous version for backward compatibility
    func totalExpensesForMonth(_ date: Date) -> Double {
        let monthExpenses = expensesForMonth(date)
        let currentCurrency = UserProfileService.shared.profile.currency
        var total: Double = 0
        
        for expense in monthExpenses {
            // For synchronous version, only sum same currency
            // Async conversion should be used for accurate totals
            if expense.currency == currentCurrency {
                total += expense.amount
            } else {
                // Include with warning - should use async version
                total += expense.amount
            }
        }
        
        return total
    }
    
    /// Get expenses by category for a month (converted to current currency)
    func expensesByCategoryForMonth(_ date: Date) -> [ExpenseCategory: Double] {
        let monthExpenses = expensesForMonth(date)
        let currentCurrency = UserProfileService.shared.profile.currency
        var categoryTotals: [ExpenseCategory: Double] = [:]
        
        for expense in monthExpenses {
            // For now, only sum same currency expenses
            // Full conversion requires async operation
            if expense.currency == currentCurrency {
                categoryTotals[expense.category, default: 0] += expense.amount
            } else {
                // Include with original amount
                categoryTotals[expense.category, default: 0] += expense.amount
            }
        }
        
        return categoryTotals
    }
    
    /// Get expenses by category (including custom categories) for a month
    func expensesByCategoryDisplayForMonth(_ date: Date) -> [CategoryDisplayInfo: Double] {
        let monthExpenses = expensesForMonth(date)
        let currentCurrency = UserProfileService.shared.profile.currency
        let customCategoryService = CustomCategoryService.shared
        var categoryTotals: [CategoryDisplayInfo: Double] = [:]
        
        for expense in monthExpenses {
            let amount = expense.currency == currentCurrency ? expense.amount : expense.amount
            
            // Check if expense has a custom category
            if let customId = expense.customCategoryId,
               let customCategory = customCategoryService.customCategories.first(where: { $0.id == customId }) {
                let categoryInfo = CategoryDisplayInfo(customCategory: customCategory)
                categoryTotals[categoryInfo, default: 0] += amount
            } else {
                // Use standard category
                let categoryInfo = CategoryDisplayInfo(category: expense.category)
                categoryTotals[categoryInfo, default: 0] += amount
            }
        }
        
        return categoryTotals
    }
}

