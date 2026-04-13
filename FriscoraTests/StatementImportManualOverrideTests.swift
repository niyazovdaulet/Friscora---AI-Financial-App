import XCTest
@testable import Friscora

@MainActor
final class StatementImportManualOverrideTests: XCTestCase {
    private let sessionsKey = "statement_import_sessions_v1"

    func testManualOverridePersistsInSessionStorage() {
        let defaults = UserDefaults.standard
        let backup = defaults.data(forKey: sessionsKey)
        defer {
            if let backup {
                defaults.set(backup, forKey: sessionsKey)
            } else {
                defaults.removeObject(forKey: sessionsKey)
            }
        }

        let fileID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let txID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!

        let tx = ParsedStatementTransaction(
            id: txID,
            rawDescription: "UBER TRIP",
            normalizedDescription: "uber trip",
            displayDescription: "UBER TRIP",
            amount: -12,
            date: Date(timeIntervalSince1970: 0),
            currency: "PLN",
            direction: .expense,
            confidence: 0.8
        )
        let session = StatementImportSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            statementFileID: fileID,
            status: .readyForReview,
            parsedTransactions: [tx],
            selectedTransactionIDs: Set([txID]),
            warnings: [],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let file = ImportedStatementFile(
            id: fileID,
            displayName: "override-test",
            localURL: URL(fileURLWithPath: "/tmp/override-test.pdf"),
            fileHash: "hash"
        )

        let coordinator = StatementImportCoordinator()
        coordinator.updateSession(session)
        guard let stored = coordinator.session(for: fileID) else {
            XCTFail("Expected stored session")
            return
        }

        let vm = StatementImportReviewViewModel(file: file, session: stored, coordinator: coordinator)
        var updated = vm.session.parsedTransactions[0]
        updated.suggestedBuiltInCategory = .transport
        updated.suggestedCustomCategoryID = nil
        updated.categorizationSource = .manual
        updated.isCategorizationManuallyOverridden = true
        updated.categorizationConfidence = 1.0
        updated.categorizationReasons = ["Selected manually during statement review."]
        vm.updateTransaction(updated)

        let reloaded = coordinator.session(for: fileID)
        XCTAssertEqual(reloaded?.parsedTransactions.first?.suggestedBuiltInCategory, .transport)
        XCTAssertEqual(reloaded?.parsedTransactions.first?.categorizationSource, .manual)
        XCTAssertEqual(reloaded?.parsedTransactions.first?.isCategorizationManuallyOverridden, true)
    }

    func testManualOverrideSurvivesSelectionRefresh() {
        let defaults = UserDefaults.standard
        let backup = defaults.data(forKey: sessionsKey)
        defer {
            if let backup {
                defaults.set(backup, forKey: sessionsKey)
            } else {
                defaults.removeObject(forKey: sessionsKey)
            }
        }

        let fileID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        let txID = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!

        var tx = ParsedStatementTransaction(
            id: txID,
            rawDescription: "BIEDRONKA",
            normalizedDescription: "biedronka",
            displayDescription: "BIEDRONKA",
            amount: -42,
            date: Date(timeIntervalSince1970: 0),
            currency: "PLN",
            direction: .expense,
            confidence: 0.8
        )
        tx.suggestedBuiltInCategory = .food
        tx.categorizationSource = .manual
        tx.isCategorizationManuallyOverridden = true
        tx.categorizationConfidence = 1.0
        tx.categorizationReasons = ["Selected manually during statement review."]

        let session = StatementImportSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            statementFileID: fileID,
            status: .readyForReview,
            parsedTransactions: [tx],
            selectedTransactionIDs: Set([txID])
        )
        let file = ImportedStatementFile(
            id: fileID,
            displayName: "refresh-test",
            localURL: URL(fileURLWithPath: "/tmp/refresh-test.pdf"),
            fileHash: "hash"
        )

        let coordinator = StatementImportCoordinator()
        coordinator.updateSession(session)
        let vm = StatementImportReviewViewModel(file: file, session: session, coordinator: coordinator)
        vm.toggleSelection(tx)
        vm.toggleSelection(tx)

        let reloaded = coordinator.session(for: fileID)
        XCTAssertEqual(reloaded?.parsedTransactions.first?.suggestedBuiltInCategory, .food)
        XCTAssertEqual(reloaded?.parsedTransactions.first?.categorizationSource, .manual)
        XCTAssertEqual(reloaded?.parsedTransactions.first?.isCategorizationManuallyOverridden, true)
    }
}
