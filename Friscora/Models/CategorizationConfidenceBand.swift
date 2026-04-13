import Foundation

enum CategorizationConfidenceBand: String, Hashable {
    case high
    case medium
    case low
}

enum CategorizationThresholds {
    /// Central confidence policy used by categorization UI and commit behavior.
    /// Update this in one place to keep classification bands consistent.
    static let highLowerBound: Double = 0.85
    static let mediumLowerBound: Double = 0.60
    static let fallbackConfidence: Double = 0.35

    static func band(for confidence: Double) -> CategorizationConfidenceBand {
        if confidence >= highLowerBound { return .high }
        if confidence >= mediumLowerBound { return .medium }
        return .low
    }
}
