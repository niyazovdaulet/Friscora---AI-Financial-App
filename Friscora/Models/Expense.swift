//
//  Expense.swift
//  Friscora
//
//  Expense model representing a single expense entry
//

import Foundation

/// Expense category enum
enum ExpenseCategory: String, CaseIterable, Codable {
    case food = "Food"
    case transport = "Transport"
    case rent = "Rent"
    case entertainment = "Entertainment"
    case subscriptions = "Subscriptions"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .food: return "🍔"
        case .transport: return "🚗"
        case .rent: return "🏠"
        case .entertainment: return "🎬"
        case .subscriptions: return "📱"
        case .other: return "📦"
        }
    }
    
    /// Localized display name for the current app language.
    var localizedName: String {
        switch self {
        case .food: return L10n("category.food")
        case .transport: return L10n("category.transport")
        case .rent: return L10n("category.rent")
        case .entertainment: return L10n("category.entertainment")
        case .subscriptions: return L10n("category.subscriptions")
        case .other: return L10n("category.other")
        }
    }
}


/// Unified category display information for both standard and custom categories
struct CategoryDisplayInfo: Hashable, Identifiable {
    let id: String // Unique identifier
    let name: String
    let icon: String
    let isCustom: Bool
    /// Built-in category when not custom; stable key for colors (localized `name` is not).
    let builtInCategory: ExpenseCategory?
    /// Chart color for custom categories (RGB hex, no `#`).
    let customColorHex: String

    /// Create from standard ExpenseCategory (name is localized)
    init(category: ExpenseCategory) {
        self.id = "standard_\(category.rawValue)"
        self.name = category.localizedName
        self.icon = category.icon
        self.isCustom = false
        self.builtInCategory = category
        self.customColorHex = ""
    }

    /// Create from custom category
    init(customCategory: CustomCategory) {
        self.id = "custom_\(customCategory.id.uuidString)"
        self.name = customCategory.name
        self.icon = customCategory.icon
        self.isCustom = true
        self.builtInCategory = nil
        self.customColorHex = customCategory.colorHex
    }

    /// Custom category row was deleted but expenses still reference this id.
    init(orphanCustomCategoryId: UUID) {
        self.id = "deleted_custom_\(orphanCustomCategoryId.uuidString)"
        self.name = L10n("deleted_category.expense_label")
        self.icon = "📂"
        self.isCustom = true
        self.builtInCategory = nil
        self.customColorHex = CategoryColorPalette.defaultHex
    }
}

/// Expense model
struct Expense: Identifiable, Codable {
    let id: UUID
    var amount: Double
    var category: ExpenseCategory
    var customCategoryId: UUID? // Optional custom category ID
    var date: Date
    var note: String?
    var currency: String // Currency code when expense was created
    
    init(id: UUID = UUID(), amount: Double, category: ExpenseCategory, customCategoryId: UUID? = nil, date: Date, note: String? = nil, currency: String? = nil) {
        self.id = id
        self.amount = CurrencyFormatter.roundToTwoDecimals(amount)
        self.category = category
        self.customCategoryId = customCategoryId
        self.date = date
        self.note = note
        self.currency = currency ?? UserProfileService.shared.profile.currency
    }
    
    enum CodingKeys: String, CodingKey {
        case id, amount, category, customCategoryId, date, note, currency
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        amount = CurrencyFormatter.roundToTwoDecimals(try c.decode(Double.self, forKey: .amount))
        category = try c.decode(ExpenseCategory.self, forKey: .category)
        customCategoryId = try c.decodeIfPresent(UUID.self, forKey: .customCategoryId)
        date = try c.decode(Date.self, forKey: .date)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        currency = try c.decode(String.self, forKey: .currency)
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(amount, forKey: .amount)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(customCategoryId, forKey: .customCategoryId)
        try c.encode(date, forKey: .date)
        try c.encodeIfPresent(note, forKey: .note)
        try c.encode(currency, forKey: .currency)
    }
    
    /// Get the display name for the category (localized for standard categories)
    func categoryName(customCategoryService: CustomCategoryService = .shared) -> String {
        if let customId = customCategoryId {
            if let customCategory = customCategoryService.customCategories.first(where: { $0.id == customId }) {
                return customCategory.name
            }
            return L10n("deleted_category.expense_label")
        }
        return category.localizedName
    }
    
    /// Get the icon for the category
    func categoryIcon(customCategoryService: CustomCategoryService = .shared) -> String {
        if let customId = customCategoryId {
            if let customCategory = customCategoryService.customCategories.first(where: { $0.id == customId }) {
                return customCategory.icon
            }
            return "📂"
        }
        return category.icon
    }
}

