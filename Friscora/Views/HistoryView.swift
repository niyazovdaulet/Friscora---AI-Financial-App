//
//  HistoryView.swift
//  Friscora
//
//  Full-screen history view with search and filters
//

import SwiftUI
import UIKit

private struct HistoryBulkDeleteConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let perform: () -> Void
}

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case income = "Income"
    case expenses = "Expenses"
}

private enum HistoryTextFocus: Hashable {
    case search
    case amountMin
    case amountMax
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
    @FocusState private var textFocus: HistoryTextFocus?
    
    @State private var isSelectionMode = false
    @State private var selectedActivityIDs: Set<UUID> = []
    @State private var amountMinText = ""
    @State private var amountMaxText = ""
    @State private var showPickMonthSheet = false
    @State private var showPickBeforeDateSheet = false
    @State private var bulkDeleteMonthAnchor = Date()
    @State private var bulkDeleteBeforeDate = Date()
    @State private var bulkDeleteConfirmation: HistoryBulkDeleteConfirmation?
    
    private var filterConfiguration: HistoryFilterConfiguration {
        HistoryFilterConfiguration(
            searchText: searchText,
            selectedFilter: selectedFilter,
            selectedDateRange: selectedDateRange,
            customStartDate: customStartDate,
            customEndDate: customEndDate,
            amountMin: parsedAmount(from: amountMinText),
            amountMax: parsedAmount(from: amountMaxText)
        )
    }
    
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
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button(L10n("common.cancel")) {
                            dismissHistoryKeyboard()
                            HapticHelper.lightImpact()
                            isSelectionMode = false
                            selectedActivityIDs = []
                        }
                        .foregroundColor(AppColorTheme.accent)
                    } else {
                        Button(L10n("history.bulk_enter_select")) {
                            dismissHistoryKeyboard()
                            HapticHelper.selection()
                            isSelectionMode = true
                        }
                        .foregroundColor(AppColorTheme.accent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !isSelectionMode {
                            Menu {
                                Button(L10n("history.bulk_delete_visible"), role: .destructive) {
                                    dismissHistoryKeyboard()
                                    presentDeleteVisibleConfirmation()
                                }
                                Button(L10n("history.bulk_delete_month_menu")) {
                                    dismissHistoryKeyboard()
                                    bulkDeleteMonthAnchor = Date()
                                    showPickMonthSheet = true
                                    HapticHelper.lightImpact()
                                }
                                Button(L10n("history.bulk_delete_before_menu")) {
                                    dismissHistoryKeyboard()
                                    bulkDeleteBeforeDate = Date()
                                    showPickBeforeDateSheet = true
                                    HapticHelper.lightImpact()
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(AppColorTheme.accent)
                                    .font(.title3)
                            }
                        } else {
                            Button(L10n("history.bulk_select_all")) {
                                dismissHistoryKeyboard()
                                HapticHelper.lightImpact()
                                let ids = HistoryBulkActions.deletableActivities(from: getFilteredActivities()).map(\.id)
                                selectedActivityIDs = Set(ids)
                            }
                            .disabled(HistoryBulkActions.deletableActivities(from: getFilteredActivities()).isEmpty)
                            .foregroundColor(AppColorTheme.accent)
                        }
                        Button {
                            dismissHistoryKeyboard()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColorTheme.textSecondary)
                                .font(.title3)
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n("common.done")) {
                        dismissHistoryKeyboard()
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSelectionMode {
                    historyBulkSelectionBar
                }
            }
            .sheet(isPresented: $showPickMonthSheet) {
                historyPickMonthSheet
            }
            .sheet(isPresented: $showPickBeforeDateSheet) {
                historyPickBeforeDateSheet
            }
            .alert(item: $bulkDeleteConfirmation) { payload in
                Alert(
                    title: Text(payload.title),
                    message: Text(payload.message),
                    primaryButton: .destructive(Text(L10n("common.delete"))) {
                        payload.perform()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private func dismissHistoryKeyboard() {
        textFocus = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var historyBulkSelectionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColorTheme.textTertiary.opacity(0.3))
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    if selectedActivityIDs.isEmpty {
                        Text(L10n("history.bulk_select_hint"))
                            .font(.subheadline)
                            .foregroundColor(AppColorTheme.textSecondary)
                    } else {
                        Text(String(format: L10n("history.bulk_n_selected"), selectedActivityIDs.count))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColorTheme.textPrimary)
                    }
                }
                Spacer(minLength: 8)
                Button(role: .destructive) {
                    presentDeleteSelectedConfirmation()
                } label: {
                    Text(L10n("history.bulk_delete_selected"))
                        .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .disabled(selectedActivityIDs.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppColorTheme.cardBackground)
        }
    }
    
    private var historyPickMonthSheet: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                Form {
                    Section {
                        DatePicker(L10n("history.bulk_pick_month"), selection: $bulkDeleteMonthAnchor, displayedComponents: [.date])
                            .foregroundColor(AppColorTheme.textPrimary)
                    } footer: {
                        Text(L10n("history.bulk_month_footer"))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("history.bulk_delete_month_menu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        showPickMonthSheet = false
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("history.bulk_review_delete")) {
                        showPickMonthSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            presentDeleteMonthConfirmation(anchor: bulkDeleteMonthAnchor)
                        }
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
            }
        }
    }
    
    private var historyPickBeforeDateSheet: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                Form {
                    Section {
                        DatePicker(L10n("history.bulk_pick_before_date"), selection: $bulkDeleteBeforeDate, displayedComponents: [.date])
                            .foregroundColor(AppColorTheme.textPrimary)
                    } footer: {
                        Text(L10n("history.bulk_before_footer"))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("history.bulk_delete_before_menu"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        showPickBeforeDateSheet = false
                    }
                    .foregroundColor(AppColorTheme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("history.bulk_review_delete")) {
                        showPickBeforeDateSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            presentDeleteBeforeConfirmation(cutoff: bulkDeleteBeforeDate)
                        }
                    }
                    .foregroundColor(AppColorTheme.accent)
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
                    .onTapGesture { dismissHistoryKeyboard() }
                
                TextField("Search transactions...", text: $searchText)
                    .focused($textFocus, equals: .search)
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
                                    dismissHistoryKeyboard()
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
                    dismissHistoryKeyboard()
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
            
            // Optional amount range (combined with date, type, and search for list and bulk actions)
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(L10n("history.amount_min"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(width: 36, alignment: .leading)
                        .onTapGesture { dismissHistoryKeyboard() }
                    TextField(L10n("history.amount_min_placeholder"), text: $amountMinText)
                        .focused($textFocus, equals: .amountMin)
                        .keyboardType(.decimalPad)
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(8)
                }
                HStack(spacing: 8) {
                    Text(L10n("history.amount_max"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(width: 36, alignment: .leading)
                        .onTapGesture { dismissHistoryKeyboard() }
                    TextField(L10n("history.amount_max_placeholder"), text: $amountMaxText)
                        .focused($textFocus, equals: .amountMax)
                        .keyboardType(.decimalPad)
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(8)
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
                                HistoryActivityRow(
                                    activity: activity,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedActivityIDs.contains(activity.id),
                                    onBulkToggle: {
                                        toggleBulkSelection(for: activity)
                                    }
                                )
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
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture().onEnded { _ in
                dismissHistoryKeyboard()
            }
        )
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
    
    private func parsedAmount(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private func buildBaseActivities() -> [ActivityItem] {
        var activities: [ActivityItem] = []
        let allExpenses = expenseService.expenses.map { ActivityItem(expense: $0) }
        activities.append(contentsOf: allExpenses)
        let allIncomes = incomeService.incomes.map { ActivityItem(income: $0) }
        activities.append(contentsOf: allIncomes)
        for goalActivity in goalService.activities {
            let goalTitle = goalService.goals.first(where: { $0.id == goalActivity.goalId })?.title ?? L10n("dashboard.goals")
            activities.append(ActivityItem(goalActivity: goalActivity, goalTitle: goalTitle))
        }
        if let mergedEntries = getMergedBalanceEntries() {
            activities.append(contentsOf: mergedEntries)
        }
        return activities
    }
    
    private func getFilteredActivities() -> [ActivityItem] {
        HistoryBulkActions.filterActivities(buildBaseActivities(), configuration: filterConfiguration)
    }
    
    private func toggleBulkSelection(for activity: ActivityItem) {
        guard activity.canBulkDeleteFromHistory else {
            HapticHelper.lightImpact()
            return
        }
        HapticHelper.selection()
        if selectedActivityIDs.contains(activity.id) {
            selectedActivityIDs.remove(activity.id)
        } else {
            selectedActivityIDs.insert(activity.id)
        }
    }
    
    private func presentDeleteVisibleConfirmation() {
        let targets = HistoryBulkActions.deletableActivities(from: getFilteredActivities())
        guard !targets.isEmpty else {
            HapticHelper.lightImpact()
            return
        }
        let counts = HistoryBulkActions.countExpensesAndIncomes(targets)
        let summary = HistoryBulkActions.deleteSummaryLine(expenseCount: counts.expenses, incomeCount: counts.incomes)
        let message = String(format: L10n("history.bulk_delete_visible_message"), summary)
        bulkDeleteConfirmation = HistoryBulkDeleteConfirmation(
            title: L10n("history.bulk_delete_visible_title"),
            message: message,
            perform: {
                HapticHelper.mediumImpact()
                HistoryBulkActions.deleteExpensesAndIncomes(targets)
            }
        )
    }
    
    private func presentDeleteMonthConfirmation(anchor: Date) {
        let targets = deletableActivitiesInSameMonth(as: anchor)
        guard !targets.isEmpty else {
            HapticHelper.lightImpact()
            return
        }
        let counts = HistoryBulkActions.countExpensesAndIncomes(targets)
        let summary = HistoryBulkActions.deleteSummaryLine(expenseCount: counts.expenses, incomeCount: counts.incomes)
        let message = String(format: L10n("history.bulk_confirm_month_message"), summary)
        bulkDeleteConfirmation = HistoryBulkDeleteConfirmation(
            title: L10n("history.bulk_confirm_month_title"),
            message: message,
            perform: {
                HapticHelper.mediumImpact()
                HistoryBulkActions.deleteExpensesAndIncomes(targets)
            }
        )
    }
    
    private func presentDeleteBeforeConfirmation(cutoff: Date) {
        let targets = deletableActivitiesStrictlyBefore(cutoff)
        guard !targets.isEmpty else {
            HapticHelper.lightImpact()
            return
        }
        let counts = HistoryBulkActions.countExpensesAndIncomes(targets)
        let summary = HistoryBulkActions.deleteSummaryLine(expenseCount: counts.expenses, incomeCount: counts.incomes)
        let message = String(format: L10n("history.bulk_confirm_before_message"), summary)
        bulkDeleteConfirmation = HistoryBulkDeleteConfirmation(
            title: L10n("history.bulk_confirm_before_title"),
            message: message,
            perform: {
                HapticHelper.mediumImpact()
                HistoryBulkActions.deleteExpensesAndIncomes(targets)
            }
        )
    }
    
    private func presentDeleteSelectedConfirmation() {
        let visible = getFilteredActivities()
        let targets = visible.filter { selectedActivityIDs.contains($0.id) && $0.canBulkDeleteFromHistory }
        guard !targets.isEmpty else {
            HapticHelper.lightImpact()
            return
        }
        let counts = HistoryBulkActions.countExpensesAndIncomes(targets)
        let summary = HistoryBulkActions.deleteSummaryLine(expenseCount: counts.expenses, incomeCount: counts.incomes)
        let message = String(format: L10n("history.bulk_confirm_selected_message"), summary)
        bulkDeleteConfirmation = HistoryBulkDeleteConfirmation(
            title: L10n("history.bulk_confirm_selected_title"),
            message: message,
            perform: {
                performBulkDeleteSelected(targets: targets)
            }
        )
    }
    
    private func performBulkDeleteSelected(targets: [ActivityItem]) {
        HapticHelper.mediumImpact()
        HistoryBulkActions.deleteExpensesAndIncomes(targets)
        selectedActivityIDs = []
        isSelectionMode = false
    }
    
    private func deletableActivitiesInSameMonth(as anchor: Date) -> [ActivityItem] {
        let calendar = Calendar.current
        return buildBaseActivities().filter { activity in
            guard activity.canBulkDeleteFromHistory else { return false }
            return calendar.isDate(activity.date, equalTo: anchor, toGranularity: .month)
        }
    }
    
    private func deletableActivitiesStrictlyBefore(_ date: Date) -> [ActivityItem] {
        let start = Calendar.current.startOfDay(for: date)
        return buildBaseActivities().filter { activity in
            guard activity.canBulkDeleteFromHistory else { return false }
            return activity.date < start
        }
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
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onBulkToggle: (() -> Void)? = nil
    
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
        Group {
            if isSelectionMode {
                rowInner
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if activity.canBulkDeleteFromHistory {
                            onBulkToggle?()
                        } else {
                            HapticHelper.lightImpact()
                        }
                    }
            } else {
                Button {
                    if canEdit {
                        showEditSheet = true
                    }
                } label: {
                    rowInner
                }
                .buttonStyle(.plain)
                .disabled(activity.isMergedBalance)
            }
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
        .opacity(isSelectionMode && !activity.canBulkDeleteFromHistory ? 0.55 : 1)
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
                    if case .income(let income) = activity.type, income.source?.isCategoryDeletionRevert == true {
                        return L10n("deleted_category.income_title")
                    }
                    if case .income(let income) = activity.type, income.source?.isSalary == true { return L10n("activity.salary") }
                    if activity.isIncome { return L10n("activity.income") }
                    return L10n("activity.expense")
                }()
                Text(String(format: L10n("common.delete_confirm"), typeLabel))
            }
        }
    }
    
    private var rowInner: some View {
        HStack(spacing: 12) {
                if isSelectionMode {
                    if activity.canBulkDeleteFromHistory {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor(isSelected ? AppColorTheme.accent : AppColorTheme.textTertiary)
                            .frame(width: 28, alignment: .center)
                            .accessibilityLabel(isSelected ? L10n("history.bulk_accessibility_selected") : L10n("history.bulk_accessibility_unselected"))
                    } else {
                        Image(systemName: "circle.slash")
                            .font(.title3)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .frame(width: 28, alignment: .center)
                            .accessibilityLabel(L10n("history.bulk_accessibility_not_available"))
                    }
                }
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
                    if case .income(let income) = activity.type, income.source?.isCategoryDeletionRevert == true {
                        ZStack {
                            Circle()
                                .fill(AppColorTheme.positive.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "tray.and.arrow.up.fill")
                                .foregroundColor(AppColorTheme.positive)
                                .font(.system(size: 20, weight: .semibold))
                        }
                    } else if case .income(let income) = activity.type, income.source?.isSalary == true {
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
                        if case .income(let income) = activity.type, income.source?.isCategoryDeletionRevert == true {
                            Text(L10n("deleted_category.income_title"))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColorTheme.textPrimary)
                        } else if case .income(let income) = activity.type, income.source?.isSalary == true {
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
                    
                    if isSelectionMode && !activity.canBulkDeleteFromHistory {
                        Text(L10n("history.bulk_not_selectable_hint"))
                            .font(.caption2)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
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
                    Text(formatCurrency(for: activity))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(amountColor)
                    
                    if !activity.isMergedBalance && !isSelectionMode {
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
    
    private func formatCurrency(for activity: ActivityItem) -> String {
        switch activity.type {
        case .expense(let expense):
            return CurrencyFormatter.format(expense.amount, currencyCode: expense.currency)
        case .income(let income):
            return CurrencyFormatter.format(income.amount, currencyCode: income.currency)
        case .mergedBalance(_, let amount, _):
            return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
        case .goalContribution(let goalActivity, _):
            if let goal = GoalService.shared.goals.first(where: { $0.id == goalActivity.goalId }) {
                return CurrencyFormatter.format(goalActivity.amount, currencyCode: goal.effectiveCurrency)
            }
            return CurrencyFormatter.format(goalActivity.amount, currencyCode: UserProfileService.shared.profile.currency)
        }
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

