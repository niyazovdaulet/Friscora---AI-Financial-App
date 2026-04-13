//
//  Income.swift
//  Friscora
//
//  Income model representing a single income entry
//

import Foundation

// MARK: - Income source (for deduplication and display)

/// How this income was created. Used to sync Work salary to Dashboard and avoid duplicates.
enum IncomeSource: Codable, Equatable {
    case manual
    /// Synthetic income when a custom category is deleted and linked expenses are removed (balance restored).
    case categoryDeletionRevert
    case salary(jobId: UUID, paymentDate: Date)
    case statementImport(statementID: UUID, batchID: UUID)
    
    enum CodingKeys: String, CodingKey {
        case type
        case jobId
        case paymentDate
        case statementID
        case batchID
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        if type == "salary" {
            let jobId = try c.decode(UUID.self, forKey: .jobId)
            let paymentDate = try c.decode(Date.self, forKey: .paymentDate)
            self = .salary(jobId: jobId, paymentDate: paymentDate)
        } else if type == "statementImport" {
            let statementID = try c.decode(UUID.self, forKey: .statementID)
            let batchID = try c.decode(UUID.self, forKey: .batchID)
            self = .statementImport(statementID: statementID, batchID: batchID)
        } else if type == "categoryDeletionRevert" {
            self = .categoryDeletionRevert
        } else {
            self = .manual
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            try c.encode("manual", forKey: .type)
        case .categoryDeletionRevert:
            try c.encode("categoryDeletionRevert", forKey: .type)
        case .salary(let jobId, let paymentDate):
            try c.encode("salary", forKey: .type)
            try c.encode(jobId, forKey: .jobId)
            try c.encode(paymentDate, forKey: .paymentDate)
        case .statementImport(let statementID, let batchID):
            try c.encode("statementImport", forKey: .type)
            try c.encode(statementID, forKey: .statementID)
            try c.encode(batchID, forKey: .batchID)
        }
    }
    
    var isSalary: Bool {
        if case .salary = self { return true }
        return false
    }

    var isCategoryDeletionRevert: Bool {
        if case .categoryDeletionRevert = self { return true }
        return false
    }

    var isStatementImport: Bool {
        if case .statementImport = self { return true }
        return false
    }
}

// MARK: - Income model

/// Income model
struct Income: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var date: Date
    var note: String?
    var currency: String // Currency code when income was created
    /// When set to `.salary(jobId, paymentDate)`, this income was synced from Work; used for deduplication and display.
    var source: IncomeSource?
    var sourceStatementID: UUID?
    var importBatchID: UUID?
    var originalImportedDescription: String?
    var isImported: Bool
    var importConfidence: Double?
    
    init(
        id: UUID = UUID(),
        amount: Double,
        date: Date,
        note: String? = nil,
        currency: String? = nil,
        source: IncomeSource? = nil,
        sourceStatementID: UUID? = nil,
        importBatchID: UUID? = nil,
        originalImportedDescription: String? = nil,
        isImported: Bool = false,
        importConfidence: Double? = nil
    ) {
        self.id = id
        self.amount = CurrencyFormatter.roundToTwoDecimals(amount)
        self.date = date
        self.note = note
        self.currency = currency ?? UserProfileService.shared.profile.currency
        self.source = source
        self.sourceStatementID = sourceStatementID
        self.importBatchID = importBatchID
        self.originalImportedDescription = originalImportedDescription
        self.isImported = isImported
        self.importConfidence = importConfidence
    }

    /// False for bookkeeping income that mirrors removed category expenses (balance effect is from deleting those expenses only).
    var countsTowardBalance: Bool {
        !(source?.isCategoryDeletionRevert ?? false)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, amount, date, note, currency, source
        case sourceStatementID, importBatchID, originalImportedDescription, isImported, importConfidence
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amount = CurrencyFormatter.roundToTwoDecimals(try c.decode(Double.self, forKey: .amount))
        date = try c.decode(Date.self, forKey: .date)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        currency = try c.decode(String.self, forKey: .currency)
        source = try c.decodeIfPresent(IncomeSource.self, forKey: .source)
        sourceStatementID = try c.decodeIfPresent(UUID.self, forKey: .sourceStatementID)
        importBatchID = try c.decodeIfPresent(UUID.self, forKey: .importBatchID)
        originalImportedDescription = try c.decodeIfPresent(String.self, forKey: .originalImportedDescription)
        isImported = try c.decodeIfPresent(Bool.self, forKey: .isImported) ?? false
        importConfidence = try c.decodeIfPresent(Double.self, forKey: .importConfidence)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(amount, forKey: .amount)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(currency, forKey: .currency)
        try c.encodeIfPresent(source, forKey: .source)
        try c.encodeIfPresent(sourceStatementID, forKey: .sourceStatementID)
        try c.encodeIfPresent(importBatchID, forKey: .importBatchID)
        try c.encodeIfPresent(originalImportedDescription, forKey: .originalImportedDescription)
        try c.encode(isImported, forKey: .isImported)
        try c.encodeIfPresent(importConfidence, forKey: .importConfidence)
    }
}
