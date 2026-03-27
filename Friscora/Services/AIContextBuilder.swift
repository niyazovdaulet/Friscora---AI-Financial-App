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
        userQuestion: String = ""
    ) -> FinancialContext {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month expenses
        let currentMonthExpenses = expenses.filter { expense in
            calendar.isDate(expense.date, equalTo: now, toGranularity: .month)
        }
        
        // Get current month incomes
        let currentMonthIncomes = incomes.filter { income in
            calendar.isDate(income.date, equalTo: now, toGranularity: .month)
        }
        
        // Calculate monthly spending and income
        let monthlySpending = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let monthlyIncome = currentMonthIncomes.reduce(0) { $0 + $1.amount }
        
        // Build category breakdown
        var categoryBreakdown: [ExpenseCategory: Double] = [:]
        for expense in currentMonthExpenses {
            categoryBreakdown[expense.category, default: 0] += expense.amount
        }
        
        return FinancialContext(
            monthlyIncome: monthlyIncome,
            fixedMonthlyExpenses: 0, // No longer used, kept for compatibility
            monthlySpending: monthlySpending,
            categoryBreakdown: categoryBreakdown,
            primaryGoal: userProfile.primaryGoal,
            userQuestion: userQuestion
        )
    }
}

