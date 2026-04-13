import XCTest
@testable import Friscora

final class StatementImportCommitCategorizationTests: XCTestCase {
    private var originalExpenses: [Expense] = []
    private var originalCustomCategories: [CustomCategory] = []

    override func setUp() {
        super.setUp()
        originalExpenses = ExpenseService.shared.expenses
        originalCustomCategories = CustomCategoryService.shared.customCategories
        ExpenseService.shared.expenses = []
        CustomCategoryService.shared.customCategories = []
    }

    override func tearDown() {
        ExpenseService.shared.expenses = originalExpenses
        CustomCategoryService.shared.customCategories = originalCustomCategories
        super.tearDown()
    }

    func testCommitUsesSuggestedCustomCategoryWhenConfidenceAllows() {
        let custom = CustomCategory(name: "Groceries", icon: "🛒")
        CustomCategoryService.shared.customCategories = [custom]
        let tx = makeExpenseTransaction(
            description: "BIEDRONKA",
            suggestedBuiltIn: nil,
            suggestedCustomID: custom.id,
            confidence: 0.90,
            source: .custom,
            manual: false
        )

        _ = StatementImportCommitService().commit(file: makeFile(), session: makeSession(with: [tx]))

        XCTAssertEqual(ExpenseService.shared.expenses.count, 1)
        XCTAssertEqual(ExpenseService.shared.expenses[0].category, .other)
        XCTAssertEqual(ExpenseService.shared.expenses[0].customCategoryId, custom.id)
    }

    func testCommitManualOverrideCategoryWins() {
        let tx = makeExpenseTransaction(
            description: "UBER",
            suggestedBuiltIn: .transport,
            suggestedCustomID: nil,
            confidence: 0.10,
            source: .manual,
            manual: true
        )

        _ = StatementImportCommitService().commit(file: makeFile(), session: makeSession(with: [tx]))

        XCTAssertEqual(ExpenseService.shared.expenses.count, 1)
        XCTAssertEqual(ExpenseService.shared.expenses[0].category, .transport)
        XCTAssertNil(ExpenseService.shared.expenses[0].customCategoryId)
    }

    func testCommitLowConfidenceFallsBackToOther() {
        let tx = makeExpenseTransaction(
            description: "UNKNOWN",
            suggestedBuiltIn: .food,
            suggestedCustomID: nil,
            confidence: 0.30,
            source: .builtIn,
            manual: false
        )

        _ = StatementImportCommitService().commit(file: makeFile(), session: makeSession(with: [tx]))

        XCTAssertEqual(ExpenseService.shared.expenses.count, 1)
        XCTAssertEqual(ExpenseService.shared.expenses[0].category, .other)
        XCTAssertNil(ExpenseService.shared.expenses[0].customCategoryId)
    }

    func testCommitFallsBackWhenCustomCategoryRemovedBeforeCommit() {
        let custom = CustomCategory(name: "One-off", icon: "🏷️")
        CustomCategoryService.shared.customCategories = [custom]
        let tx = makeExpenseTransaction(
            description: "ONE OFF",
            suggestedBuiltIn: nil,
            suggestedCustomID: custom.id,
            confidence: 0.95,
            source: .custom,
            manual: false
        )
        // Snapshot changed mid-session: category removed before final commit.
        CustomCategoryService.shared.customCategories = []

        _ = StatementImportCommitService().commit(file: makeFile(), session: makeSession(with: [tx]))

        XCTAssertEqual(ExpenseService.shared.expenses.count, 1)
        XCTAssertEqual(ExpenseService.shared.expenses[0].category, .other)
        XCTAssertNil(ExpenseService.shared.expenses[0].customCategoryId)
    }

    private func makeFile() -> ImportedStatementFile {
        ImportedStatementFile(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!,
            displayName: "statement",
            localURL: URL(fileURLWithPath: "/tmp/statement.pdf"),
            fileHash: "hash"
        )
    }

    private func makeSession(with transactions: [ParsedStatementTransaction]) -> StatementImportSession {
        StatementImportSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000F010")!,
            statementFileID: UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!,
            status: .readyForReview,
            parsedTransactions: transactions,
            selectedTransactionIDs: Set(transactions.map(\.id)),
            warnings: []
        )
    }

    private func makeExpenseTransaction(
        description: String,
        suggestedBuiltIn: ExpenseCategory?,
        suggestedCustomID: UUID?,
        confidence: Double,
        source: CategorizationSource?,
        manual: Bool
    ) -> ParsedStatementTransaction {
        var tx = ParsedStatementTransaction(
            id: UUID(),
            rawDescription: description,
            normalizedDescription: description.lowercased(),
            displayDescription: description,
            amount: -10,
            date: Date(timeIntervalSince1970: 0),
            currency: "PLN",
            direction: .expense,
            confidence: 0.8
        )
        tx.suggestedBuiltInCategory = suggestedBuiltIn
        tx.suggestedCustomCategoryID = suggestedCustomID
        tx.categorizationConfidence = confidence
        tx.categorizationSource = source
        tx.isCategorizationManuallyOverridden = manual
        return tx
    }
}
