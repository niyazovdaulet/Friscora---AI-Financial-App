//
//  CategoryNaming.swift
//  Friscora
//
//  Validates custom category names against built-ins and other customs.
//

import Foundation

enum CategoryNaming {
    static func normalizedKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True if `name` matches any built-in (localized or English raw) or another custom category.
    static func isDuplicate(name: String, excludingCustomCategoryId: UUID?) -> Bool {
        let key = normalizedKey(name)
        guard !key.isEmpty else { return false }

        for builtin in ExpenseCategory.allCases {
            if normalizedKey(builtin.localizedName) == key { return true }
            if normalizedKey(builtin.rawValue) == key { return true }
        }

        for custom in CustomCategoryService.shared.customCategories {
            if let ex = excludingCustomCategoryId, custom.id == ex { continue }
            if normalizedKey(custom.name) == key { return true }
        }

        return false
    }
}
