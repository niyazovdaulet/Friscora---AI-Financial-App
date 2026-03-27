//
//  Goal.swift
//  Friscora
//
//  Goal model for tracking financial goals
//

import Foundation

/// Goal model
struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var deadline: Date?
    var isCompleted: Bool
    var createdDate: Date
    var currency: String? // Currency code when goal was created (optional for backward compatibility)
    
    /// Get the currency, defaulting to current profile currency if not set
    var effectiveCurrency: String {
        currency ?? UserProfileService.shared.profile.currency
    }
    
    init(id: UUID = UUID(), 
         title: String, 
         targetAmount: Double, 
         currentAmount: Double = 0, 
         deadline: Date? = nil,
         isCompleted: Bool = false,
         createdDate: Date = Date(),
         currency: String? = nil) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.isCompleted = isCompleted
        self.createdDate = createdDate
        self.currency = currency ?? UserProfileService.shared.profile.currency
    }
    
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(currentAmount / targetAmount, 1.0)
    }
    
    /// Calculate pace indicator based on deadline and progress
    /// Returns: "On track", "Behind", or "Ahead"
    var paceIndicator: String? {
        guard let deadline = deadline, !isCompleted else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let totalDays = calendar.dateComponents([.day], from: createdDate, to: deadline).day ?? 0
        let elapsedDays = calendar.dateComponents([.day], from: createdDate, to: now).day ?? 0
        
        guard totalDays > 0, elapsedDays > 0 else { return nil }
        
        let expectedProgress = Double(elapsedDays) / Double(totalDays)
        let actualProgress = progress
        
        // Calculate difference
        let difference = actualProgress - expectedProgress
        
        // Thresholds: within 5% is "On track"
        if difference >= 0.05 {
            return "Ahead"
        } else if difference <= -0.05 {
            return "Behind"
        } else {
            return "On track"
        }
    }
}

