import XCTest
@testable import Friscora

final class StatementImportParserTests: XCTestCase {
    private let parser = StatementParserService()

    func testParsesSantanderMultilineBlocks() {
        let lines = santanderFixture
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let blocks = parser.parseTransactionBlocks(from: lines)
        let parsed = blocks.compactMap { parser.buildParsedTransaction(from: $0) }

        XCTAssertGreaterThan(parsed.count, 0)
        XCTAssertTrue(parsed.contains { $0.direction == .expense && $0.currency == "PLN" })
    }

    func testParsesWhenDataOperacjiIsSplitAcrossLines() {
        let lines = [
            "Data ope",
            "racji",
            "2026-03-31",
            "Data księgowania",
            "2026-04-01",
            "Tytuł: TRANSAKCJA KARTĄ CURSOR",
            "-94,87 PLN"
        ]
        let blocks = parser.parseTransactionBlocks(from: lines.map { $0.trimmingCharacters(in: .whitespaces) })
        let parsed = blocks.compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.absoluteAmount ?? 0, 94.87, accuracy: 0.001)
    }

    func testAmountLineImmediatelyBeforeDataOperacjiPairsWithNextBlock() {
        let lines = [
            "Data operacji",
            "2026-04-06",
            "Data księgowania",
            "2026-04-07",
            "TRANSAKCJA KARTĄ",
            "Tytuł: DOP. MC PŁATNOŚĆ KARTĄ 37.89 PLN ZABKA",
            "WARSZAWA",
            "-37,89 PLN",
            "Data operacji",
            "2026-04-06",
            "Data księgowania",
            "2026-04-06",
            "UZNANIE",
            "Tytuł: BLIK transfer to mobile",
            "50,00 PLN"
        ]
        let blocks = parser.parseTransactionBlocks(from: lines)
        let parsed = blocks.compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(parsed.count, 2)
        XCTAssertEqual(parsed[0].direction, .expense)
        XCTAssertEqual(parsed[0].absoluteAmount, 37.89, accuracy: 0.01)
        XCTAssertEqual(parsed[1].direction, .income)
        XCTAssertEqual(parsed[1].absoluteAmount, 50.00, accuracy: 0.01)
    }

    func testColumnLayoutDatesAndAmountsAreMatchedSequentially() {
        let lines = [
            "Data ope", "racji", "2026-03-01",
            "Data księgowania", "2026-03-02",
            "Data ope", "racji", "2026-02-01",
            "Data księgowania", "2026-02-02",
            "Tytuł: DOP. MC PŁATNOŚĆ KARTĄ 20.00 USD 1 USD=3.8567 PLN CURSOR",
            "Tytuł: DOP. MC PŁATNOŚĆ KARTĄ 20.00 USD 1 USD=3.6687 PLN CURSOR",
            "-76,56 PLN",
            "-73,37 PLN"
        ]
        let blocks = parser.parseTransactionBlocks(from: lines)
        let parsed = blocks.compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(parsed.count, 2)
        XCTAssertTrue(parsed.allSatisfy { $0.direction == .expense })
        XCTAssertTrue(parsed.allSatisfy { $0.currency == "PLN" })
        XCTAssertEqual(parsed[0].absoluteAmount, 76.56, accuracy: 0.001)
        XCTAssertEqual(parsed[1].absoluteAmount, 73.37, accuracy: 0.001)
    }

    func testAmountParsingCommaDecimalsPLN() {
        let parsed = parser.detectAmount(in: "-1 560,56 PLN")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.currency, "PLN")
        XCTAssertEqual(parsed?.value ?? 0, -1560.56, accuracy: 0.001)
    }

    func testPolishStatementThousandsSpaceAndCommaDecimal() {
        let parsed = parser.detectAmount(in: "+1 044,23 PLN")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.value ?? 0, 1044.23, accuracy: 0.01)
    }

    func testFooterCapitalAmountRejectedAsTransaction() {
        XCTAssertNil(parser.detectAmount(in: "1 021 893 140 zł"))
    }

    func testDataOpisKwotaCombinedLineIsNotDateMarker() {
        let lines = [
            "Data Opis Kwota Data operacji",
            "2026-04-08",
            "Data księgowania",
            "2026-04-08"
        ]
        let blocks = parser.parseTransactionBlocks(from: lines)
        XCTAssertTrue(blocks.isEmpty || blocks.allSatisfy { $0.rejectionReason != nil })
    }

    func testInvalidBlockContainsRejectionReason() {
        let lines = [
            "Data operacji",
            "2026-03-02",
            "Tytuł: Invalid block without amount"
        ]
        let blocks = parser.parseTransactionBlocks(from: lines)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.rejectionReason, .missingAmount)
        XCTAssertNil(parser.buildParsedTransaction(from: blocks[0]))
    }

    func testDedupStillFlagsParsedOutput() {
        let originalExpenses = ExpenseService.shared.expenses
        defer { ExpenseService.shared.expenses = originalExpenses }

        let date = dateFromISO("2026-03-01")
        let existing = Expense(
            amount: 94.87,
            category: .other,
            date: date,
            note: "Santander grocery test",
            currency: "PLN"
        )
        ExpenseService.shared.expenses = [existing]

        let parsedTx = ParsedStatementTransaction(
            rawDescription: "Tytuł: Santander grocery test",
            normalizedDescription: "santander grocery test",
            displayDescription: "Santander grocery test",
            amount: -94.87,
            date: date,
            currency: "PLN",
            direction: .expense,
            confidence: 0.9
        )

        let warnings = TransactionDeduplicationService().detectDuplicates(parsedTransactions: [parsedTx])
        XCTAssertEqual(warnings.count, 1)
    }

    func testParsesEnglishKztTableRows() {
        let lines = [
            "Date Amount Transaction Details",
            "03.04.26 - 200,00 ₸ Others Commission for transfer of other banks",
            "03.04.26 - 19 842,69 ₸ Transfers To card of other banks PAYSEND",
            "03.04.26 + 20 000,00 ₸ Replenishment Adil N."
        ]

        let result = parser.parseTransactionBlocks(from: lines).compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(result.count, 0, "Block parser is Santander-specific and should not parse this layout.")

        // Validate generic signals used by fallback path in parseStatement.
        let amount = parser.detectAmount(in: lines[1])
        XCTAssertEqual(amount?.currency, "KZT")
        XCTAssertEqual(amount?.value ?? 0, -200.00, accuracy: 0.01)

        let plus = parser.detectAmount(in: lines[3])
        XCTAssertEqual(plus?.currency, "KZT")
        XCTAssertEqual(plus?.value ?? 0, 20_000.00, accuracy: 0.01)
    }

    func testDetectAmountHandlesSpaceAfterMinusSignForKzt() {
        let parsed = parser.detectAmount(in: "03.04.26 - 200,00 〒 Others Commission for transfer")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.currency, "KZT")
        XCTAssertEqual(parsed?.value ?? 0, -200.00, accuracy: 0.01)
    }

    func testTwoDigitYearDateParsesToCurrentCentury() {
        let lines = [
            "Data operacji",
            "03.04.26",
            "Tytuł: TEST",
            "-10,00 PLN"
        ]
        let blocks = parser.parseTransactionBlocks(from: lines)
        let parsed = blocks.compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(parsed.count, 1)
        let year = Calendar.current.component(.year, from: parsed[0].date)
        XCTAssertEqual(year, 2026)
    }

    func testParsesMmDdYyyyWithSlashes() {
        let lines = [
            "Data operacji",
            "04/24/2026",
            "Tytuł: TEST",
            "-10,00 PLN"
        ]
        let parsed = parser.parseTransactionBlocks(from: lines).compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(parsed.count, 1)
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.year, from: parsed[0].date), 2026)
        XCTAssertEqual(cal.component(.month, from: parsed[0].date), 4)
        XCTAssertEqual(cal.component(.day, from: parsed[0].date), 24)
    }

    func testParsesMmDdYyWithDots() {
        let lines = [
            "Data operacji",
            "04.24.26",
            "Tytuł: TEST",
            "-10,00 PLN"
        ]
        let parsed = parser.parseTransactionBlocks(from: lines).compactMap { parser.buildParsedTransaction(from: $0) }
        XCTAssertEqual(parsed.count, 1)
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.year, from: parsed[0].date), 2026)
        XCTAssertEqual(cal.component(.month, from: parsed[0].date), 4)
        XCTAssertEqual(cal.component(.day, from: parsed[0].date), 24)
    }

    private func dateFromISO(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date()
    }

    private var santanderFixture: String {
        """
        HISTORIA RACHUNKU
        Data operacji
        2026-03-01
        Data księgowania
        2026-03-02
        Tytuł: BIEDRONKA 1234 WARSZAWA
        Zakupy spożywcze
        -94,87 PLN
        Data operacji
        2026-03-03
        Tytuł: PRZELEW PRZYCHODZACY
        Wynagrodzenie
        5 420,00 PLN
        """
    }
}
