//
//  LastUsedExpenseCategory.swift
//  Friscora
//
//  Persists last-selected expense category (built-in and custom) for faster repeat entry.
//

import Foundation
import Combine

enum LastUsedExpenseCategory {
    private static let categoryKey = "friscora.lastExpenseCategory"
    private static let customIdKey = "friscora.lastCustomCategoryId"

    /// Restores last selection; falls back to `.other` and no custom id if data is missing or invalid.
    static func load(customCategories: [CustomCategory]) -> (ExpenseCategory, UUID?) {
        if let idStr = UserDefaults.standard.string(forKey: customIdKey),
           let uuid = UUID(uuidString: idStr),
           customCategories.contains(where: { $0.id == uuid }) {
            return (.other, uuid)
        }
        if let raw = UserDefaults.standard.string(forKey: categoryKey),
           let cat = ExpenseCategory(rawValue: raw) {
            return (cat, nil)
        }
        return (.other, nil)
    }

    static func save(category: ExpenseCategory, customId: UUID?) {
        if let customId = customId {
            UserDefaults.standard.set(customId.uuidString, forKey: customIdKey)
            UserDefaults.standard.set(ExpenseCategory.other.rawValue, forKey: categoryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: customIdKey)
            UserDefaults.standard.set(category.rawValue, forKey: categoryKey)
        }
    }
}
