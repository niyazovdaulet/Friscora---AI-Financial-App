import XCTest
@testable import Friscora

/// Ordering for dashboard “Spending by category” (top 4 + show-more threshold).
final class DashboardCategoryOrderingTests: XCTestCase {
    func testOrderedBreakdownDescendingAmountTieBreaksByName() {
        let high = CategoryDisplayInfo(customCategory: CustomCategory(name: "Z", icon: "⭐️"))
        let tieA = CategoryDisplayInfo(customCategory: CustomCategory(name: "Alpha", icon: "🅰️"))
        let tieZ = CategoryDisplayInfo(customCategory: CustomCategory(name: "Zulu", icon: "🅱️"))
        let breakdown: [CategoryDisplayInfo: Double] = [
            tieZ: 10,
            high: 50,
            tieA: 10
        ]
        let rows = DashboardViewModel.orderedCategoryBreakdownForDashboard(breakdown)
        XCTAssertEqual(rows.map(\.category.name), ["Z", "Alpha", "Zulu"])
        XCTAssertEqual(rows.map(\.amount), [50, 10, 10])
    }

    func testMoreThanFourCategoriesMeansFifthExistsForShowMore() {
        let cats = ExpenseCategory.allCases.map { CategoryDisplayInfo(category: $0) }
        var breakdown: [CategoryDisplayInfo: Double] = [:]
        for (i, c) in cats.enumerated() {
            breakdown[c] = Double(i + 1)
        }
        let full = DashboardViewModel.orderedCategoryBreakdownForDashboard(breakdown)
        XCTAssertEqual(full.count, cats.count)
        XCTAssertGreaterThan(full.count, 4)
        let visible = Array(full.prefix(4))
        XCTAssertEqual(visible.count, 4)
        XCTAssertTrue(full.count > 4)
    }
}
