//
//  SmartScheduleModels.swift
//  Friscora
//
//  Work patterns, bulk apply history, and earning-aware suggestions.
//

import Foundation

struct WorkPattern: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let jobId: UUID
    let shiftId: UUID?
    /// 1 = Monday … 7 = Sunday (`ScheduleWeekday.appWeekday`)
    var weekdays: [Int]
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    let createdAt: Date
    var lastAppliedAt: Date?
    var totalDaysGenerated: Int
}

struct BulkOperation: Identifiable, Codable, Equatable {
    /// Same id as `WorkDay.bulkOperationId` for rows created in that apply.
    let id: UUID
    let jobId: UUID
    let shiftId: UUID?
    let patternId: UUID?
    let appliedAt: Date
    let dayCount: Int
    let replacedCount: Int
    let skippedCount: Int
    var label: String
}

/// Published when the detector finds a repeatable schedule worth saving as a pattern.
struct SchedulePatternSuggestion: Identifiable, Equatable {
    let id: UUID
    let jobId: UUID
    let shiftId: UUID?
    let weekdays: [Int]
    /// Hourly jobs only; `nil` when not meaningful (e.g. fixed monthly — do not fake euros).
    let estimatedMonthlyEarnings: Double?
    let isFixedMonthlyJob: Bool
}

/// Presents work pattern creation from an undo banner, detector card, or work settings.
enum WorkPatternCreationContext: Identifiable {
    case fromUndoBulk(BulkOperation)
    case fromSuggestion(SchedulePatternSuggestion)
    case manual
    
    var id: String {
        switch self {
        case .fromUndoBulk(let b): return "undo-\(b.id.uuidString)"
        case .fromSuggestion(let s): return "sug-\(s.id.uuidString)"
        case .manual: return "manual-new"
        }
    }
}
