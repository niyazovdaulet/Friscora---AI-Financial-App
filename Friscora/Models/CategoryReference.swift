import Foundation

struct CategoryReference: Identifiable, Hashable {
    let id: String
    let source: CategorizationSource
    let builtInCategory: ExpenseCategory?
    let customCategoryID: UUID?
    let displayName: String
    let icon: String

    init(builtIn category: ExpenseCategory) {
        self.id = "builtin:\(category.rawValue)"
        self.source = .builtIn
        self.builtInCategory = category
        self.customCategoryID = nil
        self.displayName = category.localizedName
        self.icon = category.icon
    }

    init(custom category: CustomCategory) {
        self.id = "custom:\(category.id.uuidString)"
        self.source = .custom
        self.builtInCategory = nil
        self.customCategoryID = category.id
        self.displayName = category.name
        self.icon = category.icon
    }
}
