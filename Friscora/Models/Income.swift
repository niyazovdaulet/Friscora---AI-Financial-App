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
    case salary(jobId: UUID, paymentDate: Date)
    
    enum CodingKeys: String, CodingKey {
        case type
        case jobId
        case paymentDate
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        if type == "salary" {
            let jobId = try c.decode(UUID.self, forKey: .jobId)
            let paymentDate = try c.decode(Date.self, forKey: .paymentDate)
            self = .salary(jobId: jobId, paymentDate: paymentDate)
        } else {
            self = .manual
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .manual:
            try c.encode("manual", forKey: .type)
        case .salary(let jobId, let paymentDate):
            try c.encode("salary", forKey: .type)
            try c.encode(jobId, forKey: .jobId)
            try c.encode(paymentDate, forKey: .paymentDate)
        }
    }
    
    var isSalary: Bool {
        if case .salary = self { return true }
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
    
    init(id: UUID = UUID(), amount: Double, date: Date, note: String? = nil, currency: String? = nil, source: IncomeSource? = nil) {
        self.id = id
        self.amount = CurrencyFormatter.roundToTwoDecimals(amount)
        self.date = date
        self.note = note
        self.currency = currency ?? UserProfileService.shared.profile.currency
        self.source = source
    }
    
    enum CodingKeys: String, CodingKey {
        case id, amount, date, note, currency, source
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amount = CurrencyFormatter.roundToTwoDecimals(try c.decode(Double.self, forKey: .amount))
        date = try c.decode(Date.self, forKey: .date)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        currency = try c.decode(String.self, forKey: .currency)
        source = try c.decodeIfPresent(IncomeSource.self, forKey: .source)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(amount, forKey: .amount)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(currency, forKey: .currency)
        try c.encodeIfPresent(source, forKey: .source)
    }
}
