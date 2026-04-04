//
//  CustomCategory.swift
//  Friscora
//
//  Custom category model for user-created expense categories
//

import Foundation

/// Custom category created by user
struct CustomCategory: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String // Emoji icon
    /// 6-digit RGB hex for charts (no `#`); persisted for older data via decode fallback.
    var colorHex: String
    var createdDate: Date

    enum CodingKeys: String, CodingKey {
        case id, name, icon, colorHex, createdDate
    }

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String = CategoryColorPalette.defaultHex, createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = Self.normalizedHex(colorHex) ?? CategoryColorPalette.defaultHex
        self.createdDate = createdDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        icon = try c.decode(String.self, forKey: .icon)
        createdDate = try c.decode(Date.self, forKey: .createdDate)
        if let raw = try c.decodeIfPresent(String.self, forKey: .colorHex),
           let normalized = Self.normalizedHex(raw) {
            colorHex = normalized
        } else {
            colorHex = CategoryColorPalette.defaultHex
        }
    }

    private static func normalizedHex(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6 else { return nil }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return trimmed.uppercased()
    }
}

