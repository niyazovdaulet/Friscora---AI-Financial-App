import XCTest
@testable import Friscora

final class StatementImportCategorizationMigrationTests: XCTestCase {
    func testOldParsedTransactionDecodesWithNilCategorizationFields() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "rawDescription": "ZABKA WARSZAWA",
          "normalizedDescription": "zabka warszawa",
          "displayDescription": "ZABKA WARSZAWA",
          "amount": -94.87,
          "absoluteAmount": 94.87,
          "date": 0,
          "currency": "PLN",
          "direction": "expense",
          "category": "imported",
          "confidence": 0.8,
          "warnings": [],
          "isSelected": true,
          "isEdited": false
        }
        """
        let tx = try JSONDecoder().decode(ParsedStatementTransaction.self, from: Data(json.utf8))
        XCTAssertNil(tx.suggestedBuiltInCategory)
        XCTAssertNil(tx.suggestedCustomCategoryID)
        XCTAssertNil(tx.categorizationConfidence)
        XCTAssertNil(tx.categorizationReasons)
        XCTAssertNil(tx.categorizationSource)
        XCTAssertNil(tx.isCategorizationManuallyOverridden)
    }

    func testOldSessionDecodesWithNilCategorizationFields() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "statementFileID": "00000000-0000-0000-0000-000000000011",
          "status": "readyForReview",
          "parsedTransactions": [
            {
              "id": "00000000-0000-0000-0000-000000000012",
              "rawDescription": "LIDL POZNAN",
              "normalizedDescription": "lidl poznan",
              "displayDescription": "LIDL POZNAN",
              "amount": -20.25,
              "absoluteAmount": 20.25,
              "date": 0,
              "currency": "PLN",
              "direction": "expense",
              "category": "imported",
              "confidence": 0.7,
              "warnings": [],
              "isSelected": true,
              "isEdited": false
            }
          ],
          "selectedTransactionIDs": ["00000000-0000-0000-0000-000000000012"],
          "warnings": [],
          "createdAt": 0,
          "updatedAt": 0
        }
        """
        let session = try JSONDecoder().decode(StatementImportSession.self, from: Data(json.utf8))
        XCTAssertEqual(session.parsedTransactions.count, 1)
        XCTAssertNil(session.parsedTransactions[0].suggestedBuiltInCategory)
        XCTAssertNil(session.parsedTransactions[0].categorizationConfidence)
        XCTAssertNil(session.parsedTransactions[0].categorizationSource)
    }

    func testCoordinatorBackfillsCategorizationWhenLoadingOldSessionData() throws {
        let key = "statement_import_sessions_v1"
        let defaults = UserDefaults.standard
        let backup = defaults.data(forKey: key)
        defer {
            if let backup {
                defaults.set(backup, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let sessionJSON = """
        [
          {
            "id": "00000000-0000-0000-0000-000000000020",
            "statementFileID": "00000000-0000-0000-0000-000000000021",
            "status": "readyForReview",
            "parsedTransactions": [
              {
                "id": "00000000-0000-0000-0000-000000000022",
                "rawDescription": "APPLE.COM/BILL 1 USD=4.01 PLN PLN",
                "normalizedDescription": "apple com bill",
                "displayDescription": "APPLE.COM/BILL",
                "amount": -50.00,
                "absoluteAmount": 50.00,
                "date": 0,
                "currency": "PLN",
                "direction": "expense",
                "category": "imported",
                "confidence": 0.8,
                "warnings": [],
                "isSelected": true,
                "isEdited": false
              },
              {
                "id": "00000000-0000-0000-0000-000000000023",
                "rawDescription": "Salary transfer",
                "normalizedDescription": "salary transfer",
                "displayDescription": "Salary transfer",
                "amount": 2500.00,
                "absoluteAmount": 2500.00,
                "date": 0,
                "currency": "PLN",
                "direction": "income",
                "category": "imported",
                "confidence": 0.9,
                "warnings": [],
                "isSelected": true,
                "isEdited": false
              }
            ],
            "selectedTransactionIDs": [
              "00000000-0000-0000-0000-000000000022",
              "00000000-0000-0000-0000-000000000023"
            ],
            "warnings": [],
            "createdAt": 0,
            "updatedAt": 0
          }
        ]
        """
        defaults.set(Data(sessionJSON.utf8), forKey: key)

        let coordinator = StatementImportCoordinator()
        let fileID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let loaded = coordinator.session(for: fileID)

        XCTAssertNotNil(loaded)
        guard let loaded else { return }
        let expense = loaded.parsedTransactions.first(where: { $0.direction == .expense })
        let income = loaded.parsedTransactions.first(where: { $0.direction == .income })
        XCTAssertEqual(expense?.suggestedBuiltInCategory, .subscriptions)
        XCTAssertNotNil(expense?.categorizationConfidence)
        XCTAssertEqual(expense?.categorizationSource, .builtIn)
        XCTAssertNil(income?.suggestedBuiltInCategory)
        XCTAssertNil(income?.categorizationConfidence)
    }
}
