//
//  HistoryBulkActions.swift
//  Friscora
//
//  Shared filtering and bulk-delete helpers for History.
//

import Foundation

/// Inputs mirroring HistoryView filter state so bulk operations use the same rules as the list.
struct HistoryFilterConfiguration {
    var searchText: String
    var selectedFilter: TransactionFilter
    var selectedDateRange: DateRange
    var customStartDate: Date
    var customEndDate: Date
    var amountMin: Double?
    var amountMax: Double?
}

enum HistoryBulkActions {
    /// Applies date, type, search, and amount filters (same pipeline as History list).
    static func filterActivities(
        _ activities: [ActivityItem],
        configuration c: HistoryFilterConfiguration
    ) -> [ActivityItem] {
        let calendar = Calendar.current
        
        let dateFiltered = activities.filter { activity in
            switch c.selectedDateRange {
            case .all:
                return true
            case .today:
                return calendar.isDateInToday(activity.date)
            case .thisWeek:
                return calendar.isDate(activity.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .thisMonth:
                return calendar.isDate(activity.date, equalTo: Date(), toGranularity: .month)
            case .thisYear:
                return calendar.isDate(activity.date, equalTo: Date(), toGranularity: .year)
            case .custom:
                return activity.date >= c.customStartDate && activity.date <= c.customEndDate
            }
        }
        
        let typeFiltered = dateFiltered.filter { activity in
            switch c.selectedFilter {
            case .all:
                return true
            case .income:
                return activity.isIncome || activity.isMergedBalance
            case .expenses:
                return !activity.isIncome && !activity.isMergedBalance && !activity.isGoalContribution
            }
        }
        
        let searchFiltered = typeFiltered.filter { activity in
            if c.searchText.isEmpty {
                return true
            }
            
            let searchLower = c.searchText.lowercased()
            
            if case .expense(let expense) = activity.type {
                if expense.categoryName().lowercased().contains(searchLower) {
                    return true
                }
                if let note = expense.note, note.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            if case .income(let income) = activity.type {
                if let note = income.note, note.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            if case .mergedBalance(let monthName, _, _) = activity.type {
                if monthName.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            if case .goalContribution(let goalActivity, let goalTitle) = activity.type {
                if goalTitle.lowercased().contains(searchLower) {
                    return true
                }
                if let note = goalActivity.note, note.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            return false
        }
        
        let amountFiltered = searchFiltered.filter { activity in
            let amt = activity.amount
            if let minV = c.amountMin, amt < minV { return false }
            if let maxV = c.amountMax, amt > maxV { return false }
            return true
        }
        
        return amountFiltered.sorted { $0.date > $1.date }
    }
    
    static func deletableActivities(from activities: [ActivityItem]) -> [ActivityItem] {
        activities.filter { $0.canBulkDeleteFromHistory }
    }
    
    static func countExpensesAndIncomes(_ activities: [ActivityItem]) -> (expenses: Int, incomes: Int) {
        var expenses = 0
        var incomes = 0
        for a in activities {
            switch a.type {
            case .expense:
                expenses += 1
            case .income:
                incomes += 1
            default:
                break
            }
        }
        return (expenses, incomes)
    }
    
    /// Human-readable confirmation line like "12 expenses and 3 incomes".
    static func deleteSummaryLine(expenseCount: Int, incomeCount: Int) -> String {
        switch (expenseCount, incomeCount) {
        case (0, 0):
            return ""
        case let (e, 0):
            return String(format: L10n("history.bulk_confirm_expenses_only"), e)
        case let (0, i):
            return String(format: L10n("history.bulk_confirm_incomes_only"), i)
        case let (e, i):
            return String(format: L10n("history.bulk_confirm_both"), e, i)
        }
    }
    
    static func deleteExpensesAndIncomes(_ activities: [ActivityItem]) {
        for activity in activities {
            switch activity.type {
            case .expense(let expense):
                ExpenseService.shared.deleteExpense(expense)
            case .income(let income):
                IncomeService.shared.deleteIncome(income)
            default:
                break
            }
        }
    }
}
