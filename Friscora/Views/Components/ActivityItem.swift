//
//  ActivityItem.swift
//  Friscora
//
//  Unified model for displaying expenses and incomes in Recent Activity
//

import Foundation

enum ActivityType {
    case expense(Expense)
    case income(Income)
    case mergedBalance(month: String, amount: Double, date: Date)
    case goalContribution(GoalActivity, goalTitle: String)
}

struct ActivityItem: Identifiable {
    let id: UUID
    let type: ActivityType
    let date: Date
    
    var amount: Double {
        switch type {
        case .expense(let expense):
            return expense.amount
        case .income(let income):
            return income.amount
        case .mergedBalance(_, let amount, _):
            return amount
        case .goalContribution(let activity, _):
            return activity.amount
        }
    }
    
    var isIncome: Bool {
        if case .income = type {
            return true
        }
        return false
    }
    
    var isMergedBalance: Bool {
        if case .mergedBalance = type {
            return true
        }
        return false
    }
    
    var isGoalContribution: Bool {
        if case .goalContribution = type {
            return true
        }
        return false
    }
    
    /// Merged balances and goal rows are excluded from History bulk delete; use their own flows.
    var canBulkDeleteFromHistory: Bool {
        switch type {
        case .expense, .income:
            return true
        case .mergedBalance, .goalContribution:
            return false
        }
    }
    
    init(expense: Expense) {
        self.id = expense.id
        self.type = .expense(expense)
        self.date = expense.date
    }
    
    init(income: Income) {
        self.id = income.id
        self.type = .income(income)
        self.date = income.date
    }
    
    init(mergedBalance month: String, amount: Double, date: Date) {
        self.id = UUID() // Generate unique ID for merged balance
        self.type = .mergedBalance(month: month, amount: amount, date: date)
        self.date = date
    }
    
    init(goalActivity: GoalActivity, goalTitle: String) {
        self.id = goalActivity.id
        self.type = .goalContribution(goalActivity, goalTitle: goalTitle)
        self.date = goalActivity.date
    }
}

