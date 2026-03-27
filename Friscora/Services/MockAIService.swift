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
    
    func getAdvice(context: FinancialContext) async throws -> String {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return generateAdvice(context: context)
    }
    
    private func generateAdvice(context: FinancialContext) -> String {
        let totalExpenses = context.fixedMonthlyExpenses + context.monthlySpending
        let remaining = context.monthlyIncome - totalExpenses
        let savingsRate = context.monthlyIncome > 0 ? (remaining / context.monthlyIncome) * 100 : 0
        
        var advice: [String] = []
        
        // Analyze spending patterns
        if context.monthlySpending > 0 {
            let topCategory = context.categoryBreakdown.max(by: { $0.value < $1.value })
            
            if let topCategory = topCategory {
                // Calculate percentage based on total expenses (monthlySpending is already total variable expenses)
                let categoryPercentage = (topCategory.value / context.monthlySpending) * 100
                
                if categoryPercentage > 40 {
                    advice.append("Your \(topCategory.key.rawValue.lowercased()) spending represents \(Int(categoryPercentage))% of your total expenses this month. This is quite high - consider reviewing if there are opportunities to optimize.")
                }
            }
        }
        
        // Analyze savings
        if remaining < 0 {
            advice.append("⚠️ You're spending more than you earn this month. I recommend reviewing your expenses and identifying areas where you can cut back.")
        } else if savingsRate < 10 {
            advice.append("Your savings rate is \(Int(savingsRate))%. Financial experts recommend saving at least 20% of your income. Consider setting up automatic transfers to a savings account.")
        } else if savingsRate >= 20 {
            advice.append("Great job! You're saving \(Int(savingsRate))% of your income. This is an excellent savings rate that will help you build financial security.")
        }
        
        // Goal-specific advice
        switch context.primaryGoal {
        case .saveMore:
            if remaining > 0 {
                let potentialIncrease = remaining * 0.1
                advice.append("By reducing discretionary spending by just 10%, you could increase your monthly savings by approximately \(formatCurrency(potentialIncrease)).")
            }
        case .payDebt:
            if remaining > 0 {
                advice.append("With \(formatCurrency(remaining)) remaining this month, consider allocating a portion to debt repayment. Even small regular payments can significantly reduce interest over time.")
            }
        case .controlSpending:
            if context.monthlySpending > context.monthlyIncome * 0.8 {
                advice.append("Your spending is high relative to your income. Try the 50/30/20 rule: 50% needs, 30% wants, 20% savings. Track your expenses for a week to identify patterns.")
            }
        }
        
        // Category-specific insights
        if let foodSpending = context.categoryBreakdown[.food], foodSpending > 0 {
            let avgDailyFood = foodSpending / 30
            if avgDailyFood > 50 {
                advice.append("Your daily food spending averages \(formatCurrency(avgDailyFood)). Meal planning and cooking at home could help reduce this by 20-30%.")
            }
        }
        
        // Handle user questions
        if !context.userQuestion.isEmpty {
            advice.insert("Regarding your question: \(context.userQuestion)", at: 0)
            advice.append("Based on your current financial situation, I'd recommend focusing on building an emergency fund first, then working towards your specific goals.")
        }
        
        // Default message if no specific advice
        if advice.isEmpty {
            advice.append("Your finances look balanced. Keep tracking your expenses and stay consistent with your goals.")
        }
        
        // Add disclaimer
        advice.append("\n\n⚠️ Friscora provides educational financial insights, not professional advice. Consult a financial advisor for personalized guidance.")
        
        return advice.joined(separator: "\n\n")
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

