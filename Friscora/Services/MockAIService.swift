//
//  MockAIService.swift
//  Friscora
//
//  Mock AI service that provides realistic financial advice
//  Can be easily replaced with real AI API implementation
//

import Foundation

/// Mock AI service implementation
class MockAIService: AIServiceProtocol {
    static let shared = MockAIService()
    
    private init() {}
    
    func getAdvice(context: RichAnalyticsContext) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)
        
        if !context.userQuestion.isEmpty,
           let curated = CuratedAnalyticsAI.replyIfMatched(context: context) {
            return "\(curated)\n\n\(L10n("chat.disclaimer"))"
        }
        return "\(fallbackAdvice(context: context))\n\n\(L10n("chat.disclaimer"))"
    }
    
    private func fallbackAdvice(context: RichAnalyticsContext) -> String {
        let income = CurrencyFormatter.format(context.monthlyIncome, currencyCode: context.currencyCode)
        let expenses = CurrencyFormatter.format(context.monthlyExpenses, currencyCode: context.currencyCode)
        let savings = CurrencyFormatter.format(context.goalAllocationsThisMonth, currencyCode: context.currencyCode)
        let leftover = CurrencyFormatter.format(context.monthlyIncome - context.monthlyExpenses - context.goalAllocationsThisMonth, currencyCode: context.currencyCode)
        return String(
            format: L10n("ai.answer.fallback.generic"),
            context.referenceMonthDisplayString,
            income,
            expenses,
            savings,
            leftover
        )
    }
}

