import Foundation

struct CategorySuggestion: Hashable {
    let category: CategoryReference
    let confidence: Double
    /// Localization key for audit / categorization rationale (resolve with `L10n` in UI).
    let reasonLocalizationKey: String
}
