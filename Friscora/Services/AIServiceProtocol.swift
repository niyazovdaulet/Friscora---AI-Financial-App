//
//  AIServiceProtocol.swift
//  Friscora
//
//  Protocol defining the interface for AI services
//  Allows easy replacement of MockAIService with real AI API
//

import Foundation

/// Financial context data structure for AI analysis
struct FinancialContext {
    let monthlyIncome: Double
    let fixedMonthlyExpenses: Double
    let monthlySpending: Double
    let categoryBreakdown: [ExpenseCategory: Double]
    let primaryGoal: FinancialGoal
    let userQuestion: String
}

/// Protocol for AI service implementations
protocol AIServiceProtocol {
    /// Get AI response based on financial context
    func getAdvice(context: FinancialContext) async throws -> String
}

