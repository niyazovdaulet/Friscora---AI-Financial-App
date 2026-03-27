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
    var createdDate: Date
    
    init(id: UUID = UUID(), name: String, icon: String, createdDate: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.createdDate = createdDate
    }
}

