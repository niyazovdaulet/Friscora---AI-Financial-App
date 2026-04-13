import XCTest
@testable import Friscora

final class CuratedAnalyticsAITests: XCTestCase {
    func testBiggestDriverUsesTopCategoryMath() {
        let context = makeContext(
            question: "What drove my spending this month?",
            monthlyExpenses: 500,
            categorySpending: [
                .init(displayName: "Food", amount: 300),
                .init(displayName: "Transport", amount: 200)
            ]
        )
        
        let reply = CuratedAnalyticsAI.replyIfMatched(context: context)
        XCTAssertNotNil(reply)
        XCTAssertTrue(reply?.contains("Food") == true)
        XCTAssertTrue(reply?.contains("60%") == true)
    }
    
    func testZeroExpensesForBiggestDriverReturnsEmptyCopy() {
        let context = makeContext(
            question: "What drove my spending this month?",
            monthlyExpenses: 0,
            categorySpending: []
        )
        
        let reply = CuratedAnalyticsAI.replyIfMatched(context: context)
        XCTAssertEqual(reply, L10n("ai.answer.biggest_driver.empty"))
    }
    
    func testBurnPacePastMonthUsesFinalBranch() {
        let calendar = Calendar.current
        let pastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let context = makeContext(
            referenceMonth: pastMonth,
            question: "At this pace, will I overspend income?",
            monthlyIncome: 2000,
            monthlyExpenses: 1500
        )
        
        let reply = CuratedAnalyticsAI.replyIfMatched(context: context)
        XCTAssertNotNil(reply)
        XCTAssertTrue(reply?.contains("closed month") == true)
    }
    
    func testMoMWithZeroPriorIncomeUsesNeutralPercent() {
        let context = makeContext(
            question: "How does this month compare to last month?",
            monthlyIncome: 1200,
            monthlyExpenses: 800,
            previousMonthIncome: 0,
            previousMonthExpenses: 0
        )
        
        let reply = CuratedAnalyticsAI.replyIfMatched(context: context)
        XCTAssertNotNil(reply)
        XCTAssertTrue(reply?.contains("0%") == true)
    }
    
    private func makeContext(
        referenceMonth: Date = Date(),
        question: String,
        monthlyIncome: Double = 1000,
        monthlyExpenses: Double = 600,
        goalAllocations: Double = 200,
        categorySpending: [RichAnalyticsCategorySpending] = [.init(displayName: "Food", amount: 600)],
        previousMonthIncome: Double = 900,
        previousMonthExpenses: Double = 500
    ) -> RichAnalyticsContext {
        RichAnalyticsContext(
            referenceMonth: referenceMonth,
            referenceMonthDisplayString: LocalizationManager.shared.monthYearString(for: referenceMonth),
            currencyCode: "USD",
            monthlyIncome: monthlyIncome,
            monthlyExpenses: monthlyExpenses,
            goalAllocationsThisMonth: goalAllocations,
            categorySpending: categorySpending,
            expensesThisMonth: [],
            previousMonthIncome: previousMonthIncome,
            previousMonthExpenses: previousMonthExpenses,
            previousMonthCategorySpending: [],
            activeGoals: [],
            userQuestion: question,
            primaryGoal: .saveMore
        )
    }
}
