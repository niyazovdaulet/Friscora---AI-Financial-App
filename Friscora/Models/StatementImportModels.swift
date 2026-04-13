import Foundation

enum StatementFileStatus: String, Codable, CaseIterable {
    case uploaded = "Uploaded"
    case scanned = "Scanned"
    case reviewed = "Reviewed"
    case imported = "Imported"
    case needsReview = "Needs Review"
    case failed = "Failed"
}

enum StatementImportSessionStatus: String, Codable {
    case created
    case parsing
    case readyForReview
    case imported
    case failed
}

enum ParsedTransactionDirection: String, Codable, CaseIterable {
    case income
    case expense
}

struct ImportedStatementFile: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var localURL: URL
    var fileHash: String
    var importedAt: Date
    var pageCount: Int
    var status: StatementFileStatus
    var transactionCount: Int
    var totalIncome: Double
    var totalExpense: Double
    var currencySet: Set<String>
    var lastScannedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        localURL: URL,
        fileHash: String,
        importedAt: Date = Date(),
        pageCount: Int = 0,
        status: StatementFileStatus = .uploaded,
        transactionCount: Int = 0,
        totalIncome: Double = 0,
        totalExpense: Double = 0,
        currencySet: Set<String> = [],
        lastScannedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.localURL = localURL
        self.fileHash = fileHash
        self.importedAt = importedAt
        self.pageCount = pageCount
        self.status = status
        self.transactionCount = transactionCount
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.currencySet = currencySet
        self.lastScannedAt = lastScannedAt
    }
}

struct ParsedStatementTransaction: Identifiable, Codable, Equatable {
    let id: UUID
    var rawDescription: String
    var normalizedDescription: String
    var displayDescription: String
    var amount: Double
    var absoluteAmount: Double
    var date: Date
    var currency: String
    var direction: ParsedTransactionDirection
    var category: String
    var confidence: Double
    var warnings: [String]
    var isSelected: Bool
    var isEdited: Bool
    var rawSourceLine: String?
    var suggestedBuiltInCategory: ExpenseCategory?
    var suggestedCustomCategoryID: UUID?
    var categorizationConfidence: Double?
    var categorizationReasons: [String]?
    var categorizationSource: CategorizationSource?
    var isCategorizationManuallyOverridden: Bool?

    init(
        id: UUID = UUID(),
        rawDescription: String,
        normalizedDescription: String,
        displayDescription: String,
        amount: Double,
        date: Date,
        currency: String,
        direction: ParsedTransactionDirection,
        category: String = "imported",
        confidence: Double,
        warnings: [String] = [],
        isSelected: Bool = true,
        isEdited: Bool = false,
        rawSourceLine: String? = nil,
        suggestedBuiltInCategory: ExpenseCategory? = nil,
        suggestedCustomCategoryID: UUID? = nil,
        categorizationConfidence: Double? = nil,
        categorizationReasons: [String]? = nil,
        categorizationSource: CategorizationSource? = nil,
        isCategorizationManuallyOverridden: Bool? = nil
    ) {
        self.id = id
        self.rawDescription = rawDescription
        self.normalizedDescription = normalizedDescription
        self.displayDescription = displayDescription
        self.amount = amount
        self.absoluteAmount = abs(amount)
        self.date = date
        self.currency = currency
        self.direction = direction
        self.category = category
        self.confidence = confidence
        self.warnings = warnings
        self.isSelected = isSelected
        self.isEdited = isEdited
        self.rawSourceLine = rawSourceLine
        self.suggestedBuiltInCategory = suggestedBuiltInCategory
        self.suggestedCustomCategoryID = suggestedCustomCategoryID
        self.categorizationConfidence = categorizationConfidence
        self.categorizationReasons = categorizationReasons
        self.categorizationSource = categorizationSource
        self.isCategorizationManuallyOverridden = isCategorizationManuallyOverridden
    }
}

enum TransactionBlockRejectionReason: String, Codable, CaseIterable {
    case missingOperationDate
    case missingAmount
    case missingDescription
    case unsupportedFormat
}

struct RawTransactionBlock: Equatable {
    var operationDateLine: String?
    var bookingDateLine: String?
    var titleLines: [String]
    var amountLine: String?
    var capturedLines: [String]
    var rejectionReason: TransactionBlockRejectionReason?

    init(
        operationDateLine: String? = nil,
        bookingDateLine: String? = nil,
        titleLines: [String] = [],
        amountLine: String? = nil,
        capturedLines: [String] = [],
        rejectionReason: TransactionBlockRejectionReason? = nil
    ) {
        self.operationDateLine = operationDateLine
        self.bookingDateLine = bookingDateLine
        self.titleLines = titleLines
        self.amountLine = amountLine
        self.capturedLines = capturedLines
        self.rejectionReason = rejectionReason
    }
}

struct StatementImportSession: Identifiable, Codable, Equatable {
    let id: UUID
    let statementFileID: UUID
    var status: StatementImportSessionStatus
    var parsedTransactions: [ParsedStatementTransaction]
    var selectedTransactionIDs: Set<UUID>
    var warnings: [String]
    var createdAt: Date
    var updatedAt: Date
    var importBatchID: UUID?

    init(
        id: UUID = UUID(),
        statementFileID: UUID,
        status: StatementImportSessionStatus = .created,
        parsedTransactions: [ParsedStatementTransaction] = [],
        selectedTransactionIDs: Set<UUID> = [],
        warnings: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        importBatchID: UUID? = nil
    ) {
        self.id = id
        self.statementFileID = statementFileID
        self.status = status
        self.parsedTransactions = parsedTransactions
        self.selectedTransactionIDs = selectedTransactionIDs
        self.warnings = warnings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.importBatchID = importBatchID
    }
}

struct DuplicateTransactionWarning: Identifiable, Equatable {
    let id = UUID()
    let parsedTransactionID: UUID
    let reason: String
}
