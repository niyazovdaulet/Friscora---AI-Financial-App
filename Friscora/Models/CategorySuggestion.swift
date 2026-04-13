import Foundation

struct CategorySuggestion: Hashable {
    let category: CategoryReference
    let confidence: Double
    let reason: String
}
