import XCTest
@testable import Friscora

final class StatementImportCategorizationPhase1Tests: XCTestCase {
    func testActiveCategorySnapshotContainsBuiltInAndActiveCustomCategories() {
        let service = CustomCategoryService.shared
        let original = service.customCategories
        defer { service.customCategories = original }

        let groceries = CustomCategory(name: "Groceries+", icon: "🛒")
        let taxi = CustomCategory(name: "Taxi", icon: "🚕")
        service.customCategories = [groceries, taxi]

        let provider = CategorySnapshotProvider(customCategoryService: service)
        let snapshot = provider.activeCategorySnapshot()

        XCTAssertEqual(snapshot.count, ExpenseCategory.allCases.count + 2)
        XCTAssertTrue(snapshot.contains(where: { $0.source == .builtIn && $0.builtInCategory == .food }))
        XCTAssertTrue(snapshot.contains(where: { $0.source == .custom && $0.customCategoryID == groceries.id }))
        XCTAssertTrue(snapshot.contains(where: { $0.source == .custom && $0.customCategoryID == taxi.id }))

        service.customCategories = [groceries]
        let afterDeletionSnapshot = provider.activeCategorySnapshot()
        XCTAssertFalse(afterDeletionSnapshot.contains(where: { $0.customCategoryID == taxi.id }))
    }

    func testTransactionTextNormalizerPreservesNonLatinAndDiacriticsWhileCleaningNoise() {
        let normalizer = TransactionTextNormalizer()
        let source = "  Café   Привет!!! Żółć---магазин\t\n#123  "

        let normalized = normalizer.normalize(source)

        XCTAssertEqual(normalized, "café привет żółć магазин 123")
    }
}
