import XCTest
@testable import Friscora

final class StatementImportCategorizationEngineTests: XCTestCase {
    private let resolver = DeterministicCategorizationResolver()
    private let snapshot = CategorySnapshotProvider().activeCategorySnapshot()

    func testRuleHitForFoodMerchantIsHighConfidence() {
        let suggestion = resolver.resolve(
            transactionDescription: "DOP. MC PLATNOSC KARTA 37.89 PLN ZABKA WARSZAWA",
            snapshot: snapshot
        )

        XCTAssertEqual(suggestion.category.builtInCategory, .food)
        XCTAssertEqual(CategorizationThresholds.band(for: suggestion.confidence), .high)
        XCTAssertGreaterThanOrEqual(suggestion.confidence, CategorizationThresholds.highLowerBound)
    }

    func testConfidenceThresholdBands() {
        XCTAssertEqual(CategorizationThresholds.band(for: 0.85), .high)
        XCTAssertEqual(CategorizationThresholds.band(for: 0.84), .medium)
        XCTAssertEqual(CategorizationThresholds.band(for: 0.60), .medium)
        XCTAssertEqual(CategorizationThresholds.band(for: 0.59), .low)
    }

    func testFallbackBehaviorForUnknownDescriptorUsesOtherWithLowConfidence() {
        let suggestion = resolver.resolve(
            transactionDescription: "UNRECOGNIZED BANK COUNTER ENTRY ABC123",
            snapshot: snapshot
        )

        XCTAssertEqual(suggestion.category.builtInCategory, .other)
        XCTAssertEqual(CategorizationThresholds.band(for: suggestion.confidence), .low)
        XCTAssertLessThan(suggestion.confidence, CategorizationThresholds.mediumLowerBound)
    }

    func testRecurringFxMerchantClassificationIsConsistent() {
        let first = resolver.resolve(
            transactionDescription: "APPLE.COM/BILL 1 USD=4.01 PLN PLN 1234****9876",
            snapshot: snapshot
        )
        let second = resolver.resolve(
            transactionDescription: "APPLE COM BILL 1 USD=3.78 PLN PLN 9999****0000",
            snapshot: snapshot
        )

        XCTAssertEqual(first.category.builtInCategory, .subscriptions)
        XCTAssertEqual(second.category.builtInCategory, .subscriptions)
        XCTAssertEqual(first.confidence, second.confidence, accuracy: 0.0001)
    }

    func testTransferToPhoneRoutesToSafeFallbackPath() {
        let suggestion = resolver.resolve(
            transactionDescription: "Transfer to the phone +48 700 100 200",
            snapshot: snapshot
        )

        XCTAssertEqual(suggestion.category.builtInCategory, .other)
        XCTAssertEqual(CategorizationThresholds.band(for: suggestion.confidence), .low)
        XCTAssertLessThan(suggestion.confidence, CategorizationThresholds.mediumLowerBound)
    }
}
