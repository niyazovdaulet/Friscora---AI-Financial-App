//
//  CategoryColorPalette.swift
//  Friscora
//
//  Curated chart colors for custom expense categories (matches app palette).
//

import SwiftUI

enum CategoryColorPalette {
    /// Default pick for new customs — first swatch in `curatedHexes` (not used by built-in category chart colors).
    static let defaultHex = "CB5F00"

    /// Custom-category-only swatches (no overlap with `AppColorTheme.chartColorHex` for built-in categories).
    static let curatedHexes: [String] = [
        "CB5F00", // deep orange
        "7C3AED", // violet
        "DB2777", // pink
        "0891B2", // cyan
        "65A30D", // lime
        "F43F5E", // rose red
        "78716C", // warm gray
        "CA8A04", // gold ochre
        "0D9488", // teal (distinct from built-in transport)
        "EC4899", // fuchsia
        "8B5CF6", // soft purple
        "06B6D4"  // sky cyan
    ]

    /// Built-in chart hexes — excluded from custom picker and from lock set.
    static var builtInChartHexSet: Set<String> {
        Set(ExpenseCategory.allCases.map { AppColorTheme.chartColorHex(for: $0).uppercased() })
    }

    /// Palette for editor, plus `selectedHex` when it’s legacy / off-palette so the selection stays visible.
    static func editorHexesIncludingSelection(_ selectedHex: String) -> [String] {
        let sel = selectedHex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        var list = curatedHexes
        guard sel.count == 6, !list.contains(where: { $0.uppercased() == sel }) else { return list }
        list.insert(selectedHex.uppercased(), at: 0)
        return list
    }
}

/// Hex values already taken by other custom categories (built-in colors are not in the picker).
enum CategoryColorReservation {
    static func lockedChartHexes(excludingCustomCategoryId: UUID?) -> Set<String> {
        var s = Set<String>()
        for c in CustomCategoryService.shared.customCategories {
            if let ex = excludingCustomCategoryId, c.id == ex { continue }
            s.insert(c.colorHex.uppercased())
        }
        return s
    }

    /// First palette color not used by another custom category (for new-category default).
    static func firstAvailableChartHex(excludingCustomCategoryId: UUID?) -> String {
        let locked = lockedChartHexes(excludingCustomCategoryId: excludingCustomCategoryId)
        for hex in CategoryColorPalette.curatedHexes where !locked.contains(hex.uppercased()) {
            return hex
        }
        return CategoryColorPalette.defaultHex
    }
}

extension CategoryDisplayInfo {
    /// Color for charts, KPI-style category rows, and legends.
    var chartTintColor: Color {
        if let cat = builtInCategory {
            return AppColorTheme.color(for: cat)
        }
        let hex = customColorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !hex.isEmpty {
            return Color(hex: hex)
        }
        return AppColorTheme.defaultCustomCategoryChartColor
    }
}
