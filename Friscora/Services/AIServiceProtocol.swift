//
//  AIServiceProtocol.swift
//  Friscora
//
//  Protocol defining the interface for AI services
//  Allows easy replacement of MockAIService with real AI API
//

import Foundation

/// Financial context data structure for AI analysis
struct RichAnalyticsCategorySpending {
    let displayName: String
    let amount: Double
}

struct RichAnalyticsContext {
    let referenceMonth: Date
    let referenceMonthDisplayString: String
    let currencyCode: String
    let monthlyIncome: Double
    let monthlyExpenses: Double
    let goalAllocationsThisMonth: Double
    let categorySpending: [RichAnalyticsCategorySpending]
    let expensesThisMonth: [Expense]
    let previousMonthIncome: Double
    let previousMonthExpenses: Double
    let previousMonthCategorySpending: [RichAnalyticsCategorySpending]
    let activeGoals: [Goal]
    let userQuestion: String
    let primaryGoal: FinancialGoal
}

/// Protocol for AI service implementations
protocol AIServiceProtocol {
    /// Get AI response based on financial context
    func getAdvice(context: RichAnalyticsContext) async throws -> String
}

