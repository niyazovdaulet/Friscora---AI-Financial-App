//
//  HistoryView.swift
//  Friscora
//
//  Full-screen history view with search and filters
//

import SwiftUI
import UIKit

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case income = "Income"
    case expenses = "Expenses"
}

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var expenseService = ExpenseService.shared
    @StateObject private var incomeService = IncomeService.shared
    @StateObject private var goalService = GoalService.shared
    
    @State private var searchText: String = ""
    @State private var selectedFilter: TransactionFilter = .all
    @State private var selectedDateRange: DateRange = .thisMonth
    @State private var showDatePicker = false
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search and Filters Section
                    searchAndFiltersSection
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    // Transactions List
                    transactionsList
                }
            }
            .navigationTitle(L10n("history.title"))
            .navigationBarTitleDisplayMode(.large)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColorTheme.textSecondary)
                            .font(.title3)
                    }
                }
            }
        }
    }
    
    // MARK: - Search and Filters Section
    private var searchAndFiltersSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColorTheme.textSecondary)
                    .font(.subheadline)
                
                TextField("Search transactions...", text: $searchText)
                    .focused($isSearchFocused)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .font(.subheadline)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColorTheme.textTertiary)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColorTheme.cardBackground)
            .cornerRadius(12)
            
            // Filter Chips
            HStack(spacing: 12) {
                // Transaction Type Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(TransactionFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: {
                                    HapticHelper.selection()
                                    withAnimation(AppAnimation.standard) {
                                        selectedFilter = filter
                                    }
                                }
                            )
                        }
                    }
                }
                
                // Date Range Filter
                Button {
                    showDatePicker.toggle()
                    HapticHelper.lightImpact()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(selectedDateRange.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(AppColorTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(AppColorTheme.accent.opacity(0.15))
                    )
                }
            }
        }
        .padding(.vertical, 12)
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerView(
                selectedRange: Binding(
                    get: { selectedDateRange },
                    set: { newValue in
                        withAnimation(AppAnimation.listItem) {
                            selectedDateRange = newValue
                        }
                    }
                ),
                customStartDate: $customStartDate,
                customEndDate: $customEndDate
            )
            .presentationCornerRadius(24)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
    
    // MARK: - Transactions List
    private var transactionsList: some View {
        let filteredActivities = getFilteredActivities()
        let runningBalanceByDay = remainingBalanceByDay(for: filteredActivities)
        
        return ScrollView {
            LazyVStack(spacing: 12) {
                if filteredActivities.isEmpty {
                    emptyStateView
                        .padding(.top, 60)
                } else {
                    // Group by date
                    ForEach(groupedActivities(filteredActivities), id: \.key) { date, activities in
                        let balanceAtEndOfDay = runningBalanceByDay[date] ?? 0
                        VStack(alignment: .leading, spacing: 12) {
                            // Date header with remaining balance after this day
                            HStack {
                                Text(formatDateHeader(date))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColorTheme.textSecondary)
                                
                                Spacer()
                                
                                Text(formatRemainingBalance(balanceAtEndOfDay))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(balanceAtEndOfDay >= 0 ? AppColorTheme.positive : AppColorTheme.negative)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Activities for this date
                            ForEach(activities) { activity in
                                HistoryActivityRow(activity: activity)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            message: L10n("history.no_transactions"),
            detail: L10n("history.adjust_filters")
        )
    }
    
    // MARK: - Helper Methods
    private func getFilteredActivities() -> [ActivityItem] {
        let calendar = Calendar.current
        let goalService = GoalService.shared
        var activities: [ActivityItem] = []
        
        // Get all expenses
        let allExpenses = expenseService.expenses.map { ActivityItem(expense: $0) }
        activities.append(contentsOf: allExpenses)
        
        // Get all incomes
        let allIncomes = incomeService.incomes.map { ActivityItem(income: $0) }
        activities.append(contentsOf: allIncomes)
        
        // Get all goal contributions (money added to goals)
        for goalActivity in goalService.activities {
            let goalTitle = goalService.goals.first(where: { $0.id == goalActivity.goalId })?.title ?? L10n("dashboard.goals")
            activities.append(ActivityItem(goalActivity: goalActivity, goalTitle: goalTitle))
        }
        
        // Get merged balances (only for current month if applicable)
        if let mergedEntries = getMergedBalanceEntries() {
            activities.append(contentsOf: mergedEntries)
        }
        
        // Apply date filter
        let dateFiltered = activities.filter { activity in
            switch selectedDateRange {
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
                return activity.date >= customStartDate && activity.date <= customEndDate
            }
        }
        
        // Apply type filter
        let typeFiltered = dateFiltered.filter { activity in
            switch selectedFilter {
            case .all:
                return true
            case .income:
                return activity.isIncome || activity.isMergedBalance
            case .expenses:
                return !activity.isIncome && !activity.isMergedBalance && !activity.isGoalContribution
            }
        }
        
        // Apply search filter
        let searchFiltered = typeFiltered.filter { activity in
            if searchText.isEmpty {
                return true
            }
            
            let searchLower = searchText.lowercased()
            
            // Search in expense category/note
            if case .expense(let expense) = activity.type {
                if expense.categoryName().lowercased().contains(searchLower) {
                    return true
                }
                if let note = expense.note, note.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            // Search in income note
            if case .income(let income) = activity.type {
                if let note = income.note, note.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            // Search in merged balance month name
            if case .mergedBalance(let monthName, _, _) = activity.type {
                if monthName.lowercased().contains(searchLower) {
                    return true
                }
            }
            
            // Search in goal contribution title and note
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
        
        return searchFiltered.sorted { $0.date > $1.date }
    }
    
    private func getMergedBalanceEntries() -> [ActivityItem]? {
        // Only show merged balances if viewing current month context
        // For history view, we can show all merged months
        var entries: [ActivityItem] = []
        let calendar = Calendar.current
        
        // Load merged months directly from UserDefaults
        let mergedMonthsKey = "merged_months"
        var mergedMonths: Set<String> = []
        if let data = UserDefaults.standard.data(forKey: mergedMonthsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            mergedMonths = Set(decoded)
        }
        
        for monthKey in mergedMonths {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            if let monthDate = formatter.date(from: monthKey) {
                let monthIncome = IncomeService.shared.totalIncomeForMonth(monthDate)
                let monthExpenses = ExpenseService.shared.totalExpensesForMonth(monthDate)
                let monthGoalAllocations = GoalService.shared.totalGoalAllocationsForMonth(monthDate)
                let monthBalance = monthIncome - monthExpenses - monthGoalAllocations
                
                if monthBalance > 0 {
                    let monthStart = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
                    let monthName = LocalizationManager.shared.monthYearString(for: monthDate)
                    
                    let entry = ActivityItem(mergedBalance: monthName, amount: monthBalance, date: monthStart)
                    entries.append(entry)
                }
            }
        }
        
        return entries.isEmpty ? nil : entries
    }
    
    private func groupedActivities(_ activities: [ActivityItem]) -> [(key: Date, value: [ActivityItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
    
    /// Running balance at end of each day (chronological order: income/merged add, expense/goal subtract).
    private func remainingBalanceByDay(for activities: [ActivityItem]) -> [Date: Double] {
        let calendar = Calendar.current
        let sorted = activities.sorted { $0.date < $1.date }
        var running: Double = 0
        var result: [Date: Double] = [:]
        for activity in sorted {
            if activity.isIncome || activity.isMergedBalance {
                running += activity.amount
            } else {
                running -= activity.amount
            }
            let dayStart = calendar.startOfDay(for: activity.date)
            result[dayStart] = running
        }
        return result
    }
    
    private func formatRemainingBalance(_ balance: Double) -> String {
        return CurrencyFormatter.format(balance, currencyCode: UserProfileService.shared.profile.currency)
    }
}

// MARK: - Date Range Enum
enum DateRange: String, CaseIterable {
    case all = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case thisYear = "This Year"
    case custom = "Custom"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(AppColorTheme.accentGradient) : AnyShapeStyle(AppColorTheme.elevatedBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - History Activity Row
struct HistoryActivityRow: View {
    let activity: ActivityItem
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    
    private var canEdit: Bool {
        !activity.isMergedBalance && !activity.isGoalContribution
    }
    
    private var amountColor: Color {
        if activity.isMergedBalance || activity.isGoalContribution {
            return AppColorTheme.accent
        }
        return activity.isIncome ? AppColorTheme.positive : AppColorTheme.negative
    }
    
    var body: some View {
        Button {
            if canEdit {
                showEditSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                if activity.isMergedBalance {
                    ZStack {
                        Circle()
                            .fill(AppColorTheme.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundColor(AppColorTheme.accent)
                            .font(.system(size: 20))
                    }
                } else if activity.isGoalContribution {
                    ZStack {
                        Circle()
                            .fill(AppColorTheme.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "target")
                            .foregroundColor(AppColorTheme.accent)
                            .font(.system(size: 20, weight: .semibold))
                    }
                } else if activity.isIncome {
                    if case .income(let income) = activity.type, income.source?.isSalary == true {
                        ZStack {
                            Circle()
                                .fill(AppColorTheme.positive.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "briefcase.fill")
                                .foregroundColor(AppColorTheme.positive)
                                .font(.system(size: 20))
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(AppColorTheme.positive.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(AppColorTheme.positive)
                                .font(.system(size: 20))
                        }
                    }
                } else {
                    if case .expense(let expense) = activity.type {
                        ZStack {
                            Circle()
                                .fill(AppColorTheme.negative.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Text(expense.categoryIcon())
                                .font(.system(size: 20))
                        }
                    }
                }
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    if activity.isMergedBalance {
                        if case .mergedBalance(let monthName, _, _) = activity.type {
                            Text(String(format: L10n("history.merged_from"), monthName))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    } else if activity.isGoalContribution {
                        if case .goalContribution(_, let goalTitle) = activity.type {
                            Text(String(format: L10n("dashboard.to_goal"), goalTitle))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    } else if activity.isIncome {
                        if case .income(let income) = activity.type, income.source?.isSalary == true {
                            Text(L10n("activity.salary"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                        } else {
                            Text(L10n("history.added_income"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    } else {
                        if case .expense(let expense) = activity.type {
                            Text(expense.categoryName())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(AppColorTheme.textTertiary)
                        Text(activity.date, style: .time)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                    
                    if case .expense(let expense) = activity.type, let note = expense.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    if case .income(let income) = activity.type, let note = income.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    if case .goalContribution(let goalActivity, _) = activity.type, let note = goalActivity.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(activity.amount))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(amountColor)
                    
                    if !activity.isMergedBalance {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(AppColorTheme.negative.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(AppColorTheme.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .disabled(activity.isMergedBalance)
        .sheet(isPresented: $showEditSheet) {
            Group {
                if canEdit {
                    if case .expense(let expense) = activity.type {
                        EditExpenseView(expense: expense)
                    } else if case .income(let income) = activity.type {
                        EditIncomeView(income: income)
                    }
                }
            }
            .presentationCornerRadius(24)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .alert(L10n("common.delete"), isPresented: $showDeleteConfirmation) {
            Button(L10n("common.delete"), role: .destructive) {
                deleteActivity()
            }
            Button(L10n("common.cancel"), role: .cancel) { }
        } message: {
            if !activity.isMergedBalance {
                let typeLabel: String = {
                    if activity.isGoalContribution { return L10n("activity.goal_contribution") }
                    if case .income(let income) = activity.type, income.source?.isSalary == true { return L10n("activity.salary") }
                    if activity.isIncome { return L10n("activity.income") }
                    return L10n("activity.expense")
                }()
                Text(String(format: L10n("common.delete_confirm"), typeLabel))
            }
        }
    }
    
    private func deleteActivity() {
        HapticHelper.mediumImpact()
        switch activity.type {
        case .expense(let expense):
            ExpenseService.shared.deleteExpense(expense)
        case .income(let income):
            IncomeService.shared.deleteIncome(income)
        case .mergedBalance:
            break
        case .goalContribution(let goalActivity, _):
            GoalService.shared.removeActivity(goalActivity)
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

// MARK: - Date Range Picker View
struct DateRangePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedRange: DateRange
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                Form {
                    Section(L10n("history.quick_select")) {
                        ForEach(DateRange.allCases.filter { $0 != .custom }, id: \.self) { range in
                            Button {
                                selectedRange = range
                                dismiss()
                            } label: {
                                HStack {
                                    Text(range.displayName)
                                        .foregroundColor(AppColorTheme.textPrimary)
                                    Spacer()
                                    if selectedRange == range {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(AppColorTheme.accent)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section(L10n("history.custom_range")) {
                        DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                            .foregroundColor(AppColorTheme.textPrimary)
                        
                        DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                            .foregroundColor(AppColorTheme.textPrimary)
                        
                        Button {
                            selectedRange = .custom
                            dismiss()
                        } label: {
                            Text(L10n("history.apply_range"))
                                .foregroundColor(AppColorTheme.accent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("history.select_date_range"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n("common.done")) {
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
            }
        }
    }
}

