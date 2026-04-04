//
//  CategoryIconReservation.swift
//  Friscora
//
//  Ensures custom category icons stay unique vs built-ins and other customs (same idea as chart colors).
//

import Foundation

enum CategoryIconReservation {
    /// Icons used by built-in expense categories.
    static var builtInIcons: Set<String> {
        Set(ExpenseCategory.allCases.map(\.icon))
    }

    /// Emojis unavailable for selection unless already the current choice (excluded row = this custom category).
    static func lockedEmojis(excludingCustomCategoryId: UUID?) -> Set<String> {
        var s = builtInIcons
        for c in CustomCategoryService.shared.customCategories {
            if let ex = excludingCustomCategoryId, c.id == ex { continue }
            s.insert(c.icon)
        }
        return s
    }

    /// First palette emoji not used by a built-in or another custom category.
    static func firstAvailableEmoji(excludingCustomCategoryId: UUID?) -> String {
        let locked = lockedEmojis(excludingCustomCategoryId: excludingCustomCategoryId)
        for e in CustomCategoryEditorConstants.emojiOptions where !locked.contains(e) {
            return e
        }
        return CustomCategoryEditorConstants.emojiOptions.first ?? "📝"
    }

    /// Grid list, keeping the current selection visible if it is off-palette (legacy data).
    static func editorEmojiOptionsIncludingSelection(_ selectedEmoji: String) -> [String] {
        var list = CustomCategoryEditorConstants.emojiOptions
        if !list.contains(selectedEmoji) {
            list.insert(selectedEmoji, at: 0)
        }
        return list
    }
}
