import XCTest
@testable import Friscora

final class StatementImportCategorizationHardeningTests: XCTestCase {
    private let resolver = DeterministicCategorizationResolver()
    private let snapshot = CategorySnapshotProvider().activeCategorySnapshot()
    private let normalizer = TransactionTextNormalizer()

    func testSantanderFxRecurringDescriptorWithRateDriftStaysConsistent() {
        let month1 = resolver.resolve(
            transactionDescription: "DOP. MC PLATNOSC KARTA APPLE.COM/BILL 9.99 USD 1 USD=3.87 PLN PLN 1234****9876",
            snapshot: snapshot
        )
        let month2 = resolver.resolve(
            transactionDescription: "DOP. MC PLATNOSC KARTA APPLE.COM/BILL 9.99 USD 1 USD=4.12 PLN PLN 2222****5555",
            snapshot: snapshot
        )

        XCTAssertEqual(month1.category.builtInCategory, .subscriptions)
        XCTAssertEqual(month2.category.builtInCategory, .subscriptions)
        XCTAssertEqual(month1.confidence, month2.confidence, accuracy: 0.0001)
    }

    func testKaspiFeeLikeRowDoesNotMisclassifyAsTransport() {
        let suggestion = resolver.resolve(
            transactionDescription: "03.04.26 - 200,00 ₸ Others Commission for transfer of other banks",
            snapshot: snapshot
        )
        XCTAssertEqual(suggestion.category.builtInCategory, .other)
        XCTAssertGreaterThanOrEqual(suggestion.confidence, CategorizationThresholds.mediumLowerBound)
    }

    func testTransferFeeFalsePositivePreventionRoutesToOther() {
        let suggestion = resolver.resolve(
            transactionDescription: "Transfer to the phone OPLATA SERWISOWA",
            snapshot: snapshot
        )
        XCTAssertEqual(suggestion.category.builtInCategory, .other)
    }

    func testNonLatinNormalizationRetainedForCategorization() {
        let normalized = normalizer.normalizeForCategorization("  Привет!!! Żółć — магазин   ")
        XCTAssertEqual(normalized, "привет żółć магазин")
    }

    func testEmptyAndPunctuationOnlyDescriptionFallsBackSafely() {
        let suggestion = resolver.resolve(
            transactionDescription: "   !!! ??? ****   ",
            snapshot: snapshot
        )
        XCTAssertEqual(suggestion.category.builtInCategory, .other)
        XCTAssertFalse(suggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertGreaterThanOrEqual(suggestion.confidence, 0)
        XCTAssertLessThanOrEqual(suggestion.confidence, 1)
    }

    func testExtremeWhitespaceAndPunctuationArtifactsStillClassifyMerchant() {
        let suggestion = resolver.resolve(
            transactionDescription: "\n\t ZABKA,,,,,,,,   ###  WARSZAWA \t\t",
            snapshot: snapshot
        )
        XCTAssertEqual(suggestion.category.builtInCategory, .food)
    }

    func testConfidenceAndReasonAlwaysSaneForNormalPath() {
        let suggestion = resolver.resolve(
            transactionDescription: "ARENA KLUB ENTRY",
            snapshot: snapshot
        )
        XCTAssertGreaterThanOrEqual(suggestion.confidence, 0)
        XCTAssertLessThanOrEqual(suggestion.confidence, 1)
        XCTAssertFalse(suggestion.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
