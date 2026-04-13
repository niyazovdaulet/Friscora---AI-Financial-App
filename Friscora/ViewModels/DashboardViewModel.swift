//
//  DashboardViewModel.swift
//  Friscora
//
//  ViewModel for dashboard view
//

import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var monthlyIncome: Double = 0
    @Published var totalExpenses: Double = 0
    @Published var goalAllocations: Double = 0
    @Published var remainingBalance: Double = 0
    @Published var categoryBreakdown: [CategoryDisplayInfo: Double] = [:]
    @Published var carryoverAmount: Double = 0
    @Published var activeGoals: [Goal] = []
    @Published var mergedMonths: Set<String> = []

    private let expenseService = ExpenseService.shared
    private let incomeService = IncomeService.shared
    private let goalService = GoalService.shared
    private let userProfileService = UserProfileService.shared
    private let customCategoryService = CustomCategoryService.shared
    private var cancellables = Set<AnyCancellable>()
    private var lastMonthChangeLogKey: String?
    private var lastFinancialSummaryLogSignature: String?
    
    private let mergedMonthsKey = "merged_months"
    let calendar = Calendar.current
    
    init() {
        loadMergedMonths()
        setupSubscriptions()
        // Use async conversion for initial load to handle multi-currency
        print("🚀 [DASHBOARD INITIALIZED]")
        print("   Merged Months Count: \(mergedMonths.count)")
        if !mergedMonths.isEmpty {
            print("   Merged Months: \(Array(mergedMonths).joined(separator: ", "))")
        }
        print("─────────────────────────────────────────")
        updateDataAsync()
    }
    
    /// Load merged months from UserDefaults
    private func loadMergedMonths() {
        if let data = UserDefaults.standard.data(forKey: mergedMonthsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            mergedMonths = Set(decoded)
        }
    }
    
    /// Save merged months to UserDefaults
    private func saveMergedMonths() {
        if let encoded = try? JSONEncoder().encode(Array(mergedMonths)) {
            UserDefaults.standard.set(encoded, forKey: mergedMonthsKey)
        }
    }
    
    /// Get month key for storage
    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    /// Check if a month is merged
    func isMonthMerged(_ date: Date) -> Bool {
        return mergedMonths.contains(monthKey(for: date))
    }
    
    /// Toggle merge status for selected month
    func toggleMergeMonth() {
        let key = monthKey(for: selectedMonth)
        let wasMerged = mergedMonths.contains(key)
        
        if wasMerged {
            mergedMonths.remove(key)
            print("🔓 [MONTH UNMERGED]")
            print("   Month: \(monthString(for: selectedMonth))")
            print("   ⚠️ This month's balance is NO LONGER added to current month")
        } else {
            mergedMonths.insert(key)
            print("🔗 [MONTH MERGED]")
            print("   Month: \(monthString(for: selectedMonth))")
            
            // Calculate this month's balance
            let monthIncome = incomeService.totalIncomeForMonth(selectedMonth)
            let monthExpenses = expenseService.totalExpensesForMonth(selectedMonth)
            let monthGoalAllocations = goalService.totalGoalAllocationsForMonth(selectedMonth)
            let monthBalance = monthIncome - monthExpenses - monthGoalAllocations
            
            print("   Month Income: \(monthIncome) \(userProfileService.profile.currency)")
            print("   Month Expenses: \(monthExpenses) \(userProfileService.profile.currency)")
            print("   Month Goal Allocations: \(monthGoalAllocations) \(userProfileService.profile.currency)")
            print("   Month Remaining Balance: \(monthBalance) \(userProfileService.profile.currency)")
            print("   ✅ This balance will be added to current month")
        }
        saveMergedMonths()
        print("─────────────────────────────────────────")
        updateDataAsync()
    }
    
    /// Get merged balance from merged months for current month (synchronous version for quick access)
    func mergedBalanceForCurrentMonth() -> Double {
        guard isCurrentMonth else { return 0 }
        
        var totalMerged: Double = 0
        
        for monthKey in mergedMonths {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            if let monthDate = formatter.date(from: monthKey) {
                // Calculate remaining balance for that month (simplified, currency conversion handled in async)
                let monthIncome = incomeService.totalIncomeForMonth(monthDate)
                let monthExpenses = expenseService.totalExpensesForMonth(monthDate)
                let monthGoalAllocations = goalService.totalGoalAllocationsForMonth(monthDate)
                let monthBalance = monthIncome - monthExpenses - monthGoalAllocations
                totalMerged += max(0, monthBalance) // Only positive balances
            }
        }
        
        return totalMerged
    }
    
    private func setupSubscriptions() {
        // Subscribe to expense changes
        expenseService.$expenses
            .sink { [weak self] _ in
                // Use async conversion to handle multi-currency properly
                self?.updateDataAsync()
            }
            .store(in: &cancellables)
        
        // Subscribe to income changes
        incomeService.$incomes
            .sink { [weak self] _ in
                // Use async conversion to handle multi-currency properly
                self?.updateDataAsync()
            }
            .store(in: &cancellables)
        
        // Subscribe to profile changes (especially currency)
        userProfileService.$profile
            .sink { [weak self] _ in
                // When currency changes, use async conversion
                self?.updateDataAsync()
            }
            .store(in: &cancellables)
        
        // Subscribe to selected month changes
        $selectedMonth
            .sink { [weak self] newMonth in
                guard let self = self else { return }
                let monthLogKey = self.monthChangeLogKey(for: newMonth)
                if self.lastMonthChangeLogKey != monthLogKey {
                    self.lastMonthChangeLogKey = monthLogKey
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMMM yyyy"
                    print("📅 [MONTH CHANGED] \(formatter.string(from: newMonth)) | current: \(self.isCurrentMonth) | past: \(self.isPastMonth)")
                }
                // Use async conversion for month changes too
                self.updateDataAsync()
            }
            .store(in: &cancellables)
        
        // Subscribe to custom category changes
        customCategoryService.$customCategories
            .sink { [weak self] _ in
                // Update data when custom categories change
                self?.updateDataAsync()
            }
            .store(in: &cancellables)
        
        // Subscribe to goal changes
        goalService.$goals
            .sink { [weak self] _ in
                // Update data when goals change
                self?.updateDataAsync()
            }
            .store(in: &cancellables)
        
        // Subscribe to goal activity changes
        goalService.$activities
            .sink { [weak self] _ in
                // Update data when goal activities change
                self?.updateDataAsync()
            }
            .store(in: &cancellables)
    }
    
    /// Get available months from app installation date to current month
    var availableMonths: [Date] {
        let installationDate = userProfileService.profile.appInstallationDate
        let currentDate = Date()
        
        var months: [Date] = []
        var date = calendar.dateInterval(of: .month, for: installationDate)?.start ?? installationDate
        
        while date <= currentDate {
            months.append(date)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { break }
            date = nextMonth
        }
        
        return months.reversed() // Most recent first
    }
    
    /// Check if the selected month is the current month
    var isCurrentMonth: Bool {
        calendar.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }
    
    /// Check if the selected month is in the past
    var isPastMonth: Bool {
        !isCurrentMonth && selectedMonth < Date()
    }
    
    /// Get formatted month string for display (nominative form, e.g. "Февраль" not "февраля")
    func monthString(for date: Date) -> String {
        LocalizationManager.shared.monthYearString(for: date)
    }
    
    func updateData() {
        monthlyIncome = incomeService.totalIncomeForMonth(selectedMonth)
        totalExpenses = expenseService.totalExpensesForMonth(selectedMonth)
        goalAllocations = goalService.totalGoalAllocationsForMonth(selectedMonth)
        
        // No automatic carryover: only merged months add to balance (user must tap "Merge" on a month).
        carryoverAmount = 0
        
        // Add merged balance if viewing current month (only from months user explicitly merged)
        let mergedBalance = isCurrentMonth ? mergedBalanceForCurrentMonth() : 0
        remainingBalance = monthlyIncome + carryoverAmount + mergedBalance - totalExpenses - goalAllocations
        
        categoryBreakdown = expenseService.expensesByCategoryDisplayForMonth(selectedMonth)
        activeGoals = goalService.activeGoalsWithProgress()
    }

    /// Async version that properly converts currencies
    func updateDataAsync() {
        Task {
            let currentCurrency = userProfileService.profile.currency
            let currencyService = CurrencyService.shared
            let customCategoryService = CustomCategoryService.shared

            let selectedSnapshot = await convertedMonthSnapshot(
                month: selectedMonth,
                currentCurrency: currentCurrency,
                currencyService: currencyService,
                customCategoryService: customCategoryService
            )

            // No automatic carryover: past months only add to balance when user explicitly merges them.
            let carryover: Double = 0

            // Get active goals
            let activeGoalsList = goalService.activeGoalsWithProgress()
            
            // Calculate merged balance if viewing current month
            var mergedBalance: Double = 0
            if isCurrentMonth {
                for monthKey in mergedMonths {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM"
                    if let monthDate = formatter.date(from: monthKey) {
                        let monthExpenses = expenseService.expensesForMonth(monthDate)
                        let monthIncomes = incomeService.incomesForMonth(monthDate)
                        let monthGoalActivities = goalService.activitiesForMonth(monthDate)
                        
                        var monthIncomeTotal: Double = 0
                        var monthExpenseTotal: Double = 0
                        var monthGoalTotal: Double = 0
                        
                        for income in monthIncomes where income.countsTowardBalance {
                            if income.currency == currentCurrency {
                                monthIncomeTotal += income.amount
                            } else {
                                do {
                                    monthIncomeTotal += try await currencyService.convert(
                                        amount: income.amount,
                                        from: income.currency,
                                        to: currentCurrency
                                    )
                                } catch {
                                    monthIncomeTotal += income.amount
                                }
                            }
                        }
                        
                        for expense in monthExpenses {
                            if expense.currency == currentCurrency {
                                monthExpenseTotal += expense.amount
                            } else {
                                do {
                                    monthExpenseTotal += try await currencyService.convert(
                                        amount: expense.amount,
                                        from: expense.currency,
                                        to: currentCurrency
                                    )
                                } catch {
                                    monthExpenseTotal += expense.amount
                                }
                            }
                        }
                        
                        for activity in monthGoalActivities {
                            if let goal = goalService.goals.first(where: { $0.id == activity.goalId }) {
                                let goalCurrency = goal.effectiveCurrency
                                let amount: Double
                                if goalCurrency == currentCurrency {
                                    amount = activity.amount
                                } else {
                                    do {
                                        amount = try await currencyService.convert(
                                            amount: activity.amount,
                                            from: goalCurrency,
                                            to: currentCurrency
                                        )
                                    } catch {
                                        amount = activity.amount
                                    }
                                }
                                monthGoalTotal += amount
                            }
                        }
                        
                        let monthBalance = monthIncomeTotal - monthExpenseTotal - monthGoalTotal
                        mergedBalance += max(0, monthBalance)
                    }
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                monthlyIncome = selectedSnapshot.income
                totalExpenses = selectedSnapshot.expenses
                goalAllocations = selectedSnapshot.goals
                carryoverAmount = carryover
                remainingBalance = monthlyIncome + carryoverAmount + mergedBalance - totalExpenses - goalAllocations
                categoryBreakdown = selectedSnapshot.categoryTotals
                activeGoals = activeGoalsList

                // Keep debug output compact and avoid duplicate spam from repeated async updates.
                let signature = financialSummaryLogSignature(
                    currency: currentCurrency,
                    mergedBalance: mergedBalance
                )
                if lastFinancialSummaryLogSignature != signature {
                    lastFinancialSummaryLogSignature = signature
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMMM yyyy"
                    print(
                        "📊 [FINANCIAL SUMMARY] \(formatter.string(from: selectedMonth)) | " +
                        "Income: \(String(format: "%.2f", monthlyIncome)) \(currentCurrency) | " +
                        "Expenses: \(String(format: "%.2f", totalExpenses)) \(currentCurrency) | " +
                        "Goals: \(String(format: "%.2f", goalAllocations)) \(currentCurrency) | " +
                        "Carryover: \(String(format: "%.2f", carryoverAmount)) \(currentCurrency) | " +
                        "Merged: \(String(format: "%.2f", mergedBalance)) \(currentCurrency) | " +
                        "Balance: \(String(format: "%.2f", remainingBalance)) \(currentCurrency)"
                    )
                }
            }
        }
    }
    
    func refresh() {
        updateDataAsync()
    }

    // MARK: - Month snapshot (FX)

    private struct MonthFinancialSnapshot {
        let income: Double
        let expenses: Double
        let goals: Double
        let categoryTotals: [CategoryDisplayInfo: Double]
    }

    private func convertedMonthSnapshot(
        month: Date,
        currentCurrency: String,
        currencyService: CurrencyService,
        customCategoryService: CustomCategoryService
    ) async -> MonthFinancialSnapshot {
        let monthExpenses = expenseService.expensesForMonth(month)
        let monthIncomes = incomeService.incomesForMonth(month)
        var totalExpensesConverted: Double = 0
        var categoryTotals: [CategoryDisplayInfo: Double] = [:]

        for expense in monthExpenses {
            let amount: Double
            if expense.currency == currentCurrency {
                amount = expense.amount
            } else {
                do {
                    amount = try await currencyService.convert(
                        amount: expense.amount,
                        from: expense.currency,
                        to: currentCurrency
                    )
                } catch {
                    amount = expense.amount
                }
            }
            totalExpensesConverted += amount

            if let customId = expense.customCategoryId,
               let customCategory = customCategoryService.customCategories.first(where: { $0.id == customId }) {
                let categoryInfo = CategoryDisplayInfo(customCategory: customCategory)
                categoryTotals[categoryInfo, default: 0] += amount
            } else if let customId = expense.customCategoryId {
                let categoryInfo = CategoryDisplayInfo(orphanCustomCategoryId: customId)
                categoryTotals[categoryInfo, default: 0] += amount
            } else {
                let categoryInfo = CategoryDisplayInfo(category: expense.category)
                categoryTotals[categoryInfo, default: 0] += amount
            }
        }

        var totalIncomeConverted: Double = 0
        for income in monthIncomes where income.countsTowardBalance {
            if income.currency == currentCurrency {
                totalIncomeConverted += income.amount
            } else {
                do {
                    let converted = try await currencyService.convert(
                        amount: income.amount,
                        from: income.currency,
                        to: currentCurrency
                    )
                    totalIncomeConverted += converted
                } catch {
                    totalIncomeConverted += income.amount
                }
            }
        }

        let monthGoalActivities = goalService.activitiesForMonth(month)
        var totalGoalAllocations: Double = 0
        for activity in monthGoalActivities {
            if let goal = goalService.goals.first(where: { $0.id == activity.goalId }) {
                let goalCurrency = goal.effectiveCurrency
                let amount: Double
                if goalCurrency == currentCurrency {
                    amount = activity.amount
                } else {
                    do {
                        amount = try await currencyService.convert(
                            amount: activity.amount,
                            from: goalCurrency,
                            to: currentCurrency
                        )
                    } catch {
                        amount = activity.amount
                    }
                }
                totalGoalAllocations += amount
            }
        }

        return MonthFinancialSnapshot(
            income: totalIncomeConverted,
            expenses: totalExpensesConverted,
            goals: totalGoalAllocations,
            categoryTotals: categoryTotals
        )
    }

    private func monthChangeLogKey(for date: Date) -> String {
        "\(monthKey(for: date))|\(isCurrentMonth)|\(isPastMonth)|\(isMonthMerged(date))"
    }

    private func financialSummaryLogSignature(currency: String, mergedBalance: Double) -> String {
        let month = monthKey(for: selectedMonth)
        return [
            month,
            currency,
            String(format: "%.2f", monthlyIncome),
            String(format: "%.2f", totalExpenses),
            String(format: "%.2f", goalAllocations),
            String(format: "%.2f", carryoverAmount),
            String(format: "%.2f", mergedBalance),
            String(format: "%.2f", remainingBalance),
            "\(mergedMonths.count)"
        ].joined(separator: "|")
    }
}

