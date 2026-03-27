//
//  UserProfile.swift
//  Friscora
//
//  User profile model containing financial information
//

import Foundation

/// Financial goal type
enum FinancialGoal: String, CaseIterable, Codable {
    case saveMore = "Save More"
    case payDebt = "Pay Debts"
    case controlSpending = "Control Spending"
}

/// User profile model
struct UserProfile: Codable {
    var primaryGoal: FinancialGoal
    var hasCompletedOnboarding: Bool
    var currency: String // Currency code like "PLN", "USD", "EUR"
    var appInstallationDate: Date // Date when app was first installed
    var isAuthenticationEnabled: Bool // Authentication toggle
    var notificationSchedule: NotificationSchedule? // Notification preferences
    
    init(primaryGoal: FinancialGoal = .saveMore,
         hasCompletedOnboarding: Bool = false,
         currency: String = "PLN",
         appInstallationDate: Date = Date(),
         isAuthenticationEnabled: Bool = false,
         notificationSchedule: NotificationSchedule? = nil) {
        self.primaryGoal = primaryGoal
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.currency = currency
        self.appInstallationDate = appInstallationDate
        self.isAuthenticationEnabled = isAuthenticationEnabled
        self.notificationSchedule = notificationSchedule
    }
}

