//
//  AIContextBuilder.swift
//  Friscora
//
//  Builds financial context from user data for AI analysis
//

import Foundation

/// Builds financial context for AI service
class AIContextBuilder {
    static func buildContext(
        userProfile: UserProfile,
        expenses: [Expense],
        incomes: [Income],
        userQuestion: String = "",
        referenceMonth: Date = Date()
    ) -> RichAnalyticsContext {
        let calendar = Calendar.current
        let currencyCode = userProfile.currency
        
        let expensesThisMonth = expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: referenceMonth, toGranularity: .month)
        }
        let incomesThisMonth = incomes.filter { income in
            calendar.isDate(income.date, equalTo: referenceMonth, toGranularity: .month)
        }
        let monthlyExpenses = expensesThisMonth.reduce(0) { $0 + $1.amount }
        let monthlyIncome = incomesThisMonth.reduce(0) { total, income in
            total + (income.countsTowardBalance ? income.amount : 0)
        }
        let goalAllocationsThisMonth = GoalService.shared.totalGoalAllocationsForMonth(referenceMonth)
        
        let categorySpending = buildCategorySpending(for: expensesThisMonth, currencyCode: currencyCode)
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceMonth) ?? referenceMonth
        let previousMonthExpensesRows = expenses.filter {
            calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month)
        }
        let previousMonthIncomeRows = incomes.filter {
            calendar.isDate($0.date, equalTo: previousMonth, toGranularity: .month)
        }
        let previousMonthExpenses = previousMonthExpensesRows.reduce(0) { $0 + $1.amount }
        let previousMonthIncome = previousMonthIncomeRows.reduce(0) { total, income in
            total + (income.countsTowardBalance ? income.amount : 0)
        }
        let previousMonthCategorySpending = buildCategorySpending(for: previousMonthExpensesRows, currencyCode: currencyCode)
        
        // Sort by nearest deadline first, then newest created date.
        let activeGoals = GoalService.shared.activeGoalsWithProgress()
            .sorted {
                switch ($0.deadline, $1.deadline) {
                case let (lhs?, rhs?):
                    return lhs < rhs
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                case (nil, nil):
                    return $0.createdDate > $1.createdDate
                }
            }
        
        return RichAnalyticsContext(
            referenceMonth: referenceMonth,
            referenceMonthDisplayString: LocalizationManager.shared.monthYearString(for: referenceMonth),
            currencyCode: currencyCode,
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            goalAllocationsThisMonth: goalAllocationsThisMonth,
            categorySpending: categorySpending,
            expensesThisMonth: expensesThisMonth,
            previousMonthIncome: previousMonthIncome,
            previousMonthExpenses: previousMonthExpenses,
            previousMonthCategorySpending: previousMonthCategorySpending,
            activeGoals: activeGoals,
            userQuestion: userQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryGoal: userProfile.primaryGoal
        )
    }
    
    private static func buildCategorySpending(for expenses: [Expense], currencyCode: String) -> [RichAnalyticsCategorySpending] {
        let customCategoryService = CustomCategoryService.shared
        var totals: [String: Double] = [:]
        
        for expense in expenses {
            let key: String
            if let customId = expense.customCategoryId,
               let customCategory = customCategoryService.customCategories.first(where: { $0.id == customId }) {
                key = customCategory.name
            } else if expense.customCategoryId != nil {
                key = L10n("deleted_category.expense_label")
            } else {
                key = expense.category.localizedName
            }
            totals[key, default: 0] += (expense.currency == currencyCode ? expense.amount : expense.amount)
        }
        
        return totals.map { RichAnalyticsCategorySpending(displayName: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}

