import XCTest
@testable import Friscora

final class StatementImportLearningStoreTests: XCTestCase {
    func testLearnedMappingAppliedForRepeatedMerchant() {
        let defaults = UserDefaults.standard
        let key = "statement_import_learned_merchants_test_repeat"
        let store = LearnedMerchantStore(storageKey: key, defaults: defaults)
        store.clearAll()
        defer { store.clearAll() }

        store.saveManualOverride(
            transactionDescription: "UBER *TRIP 1234",
            builtInCategory: .transport,
            customCategoryID: nil
        )

        let resolver = DeterministicCategorizationResolver(learningStore: store)
        let snapshot = CategorySnapshotProvider().activeCategorySnapshot()
        let suggestion = resolver.resolve(
            transactionDescription: "UBER TRIP 9999",
            snapshot: snapshot
        )

        XCTAssertEqual(suggestion.category.builtInCategory, .transport)
        XCTAssertEqual(suggestion.confidence, 1.0)
        XCTAssertTrue(suggestion.reason.contains("manual correction"))
    }

    func testInvalidLearnedCustomCategoryIsIgnoredSafely() {
        let defaults = UserDefaults.standard
        let key = "statement_import_learned_merchants_test_invalid_custom"
        let store = LearnedMerchantStore(storageKey: key, defaults: defaults)
        store.clearAll()
        defer { store.clearAll() }

        let missingCustomID = UUID(uuidString: "00000000-0000-0000-0000-00000000AA01")!
        store.saveManualOverride(
            transactionDescription: "BIEDRONKA 123",
            builtInCategory: nil,
            customCategoryID: missingCustomID
        )

        let originalCustoms = CustomCategoryService.shared.customCategories
        defer { CustomCategoryService.shared.customCategories = originalCustoms }
        CustomCategoryService.shared.customCategories = []
        let resolver = DeterministicCategorizationResolver(learningStore: store)
        let snapshot = CategorySnapshotProvider().activeCategorySnapshot()
        let suggestion = resolver.resolve(
            transactionDescription: "BIEDRONKA 456",
            snapshot: snapshot
        )

        XCTAssertEqual(suggestion.category.builtInCategory, .food)
        XCTAssertLessThan(suggestion.confidence, 1.0)
    }

    func testMalformedPersistedSchemaFallsBackSafely() {
        let defaults = UserDefaults.standard
        let key = "statement_import_learned_merchants_test_malformed"
        let store = LearnedMerchantStore(storageKey: key, defaults: defaults)
        defer { defaults.removeObject(forKey: key) }

        defaults.set(Data("not-json".utf8), forKey: key)
        let mappings = store.loadMappings()

        XCTAssertTrue(mappings.isEmpty)
    }
}
