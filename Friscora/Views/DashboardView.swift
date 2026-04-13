//
//  DashboardView.swift
//  Friscora
//
//  Main dashboard showing financial overview
//

import SwiftUI
import Combine
import UIKit

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var expenseService = ExpenseService.shared
    @StateObject private var incomeService = IncomeService.shared
    @StateObject private var goalService = GoalService.shared
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @Binding var selectedTab: Int
    @State private var isButtonPressed = false
    @AppStorage("friscora.dashboard.spendingByCategoryExpanded") private var isCategorySectionExpanded = true
    @AppStorage("friscora.dashboard.allocatedSavingsExpanded") private var isAllocatedSavingsExpanded = true
    @State private var showHistoryView = false
    @State private var showStatementImport = false
    @State private var dashboardEntranceDone = false
    @State private var navigateToGoalsView = false
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        summarySection

                        // Category breakdown (stagger after KPI grid)
                        categorySection
                            .opacity(dashboardEntranceDone ? 1 : 0)
                            .offset(y: dashboardEntranceDone ? 0 : 16)
                            .animation(AppAnimation.quickUI.delay(0.2), value: dashboardEntranceDone)

                        // Goals section
                        goalsSection
                            .opacity(dashboardEntranceDone ? 1 : 0)
                            .offset(y: dashboardEntranceDone ? 0 : 16)
                            .animation(AppAnimation.quickUI.delay(0.25), value: dashboardEntranceDone)

                        // Recent expenses
                        recentExpensesSection
                            .opacity(dashboardEntranceDone ? 1 : 0)
                            .offset(y: dashboardEntranceDone ? 0 : 16)
                            .animation(AppAnimation.quickUI.delay(0.3), value: dashboardEntranceDone)
                    }
                    .padding(AppSpacing.m)
                    .onAppear {
                        dashboardEntranceDone = true
                    }
                }
                .scrollIndicators(.hidden, axes: .vertical)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showStatementImport = true
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.caption)
                            Text("Import")
                                .font(AppTypography.captionMedium)
                        }
                        .foregroundColor(AppColorTheme.ctaPrimary)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Capsule().fill(AppColorTheme.ctaPrimary.opacity(0.15)))
                    }
                    .accessibilityLabel("Statement Import")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Merge/Unmerge button (only for past months)
                        if viewModel.isPastMonth {
                            Button {
                                viewModel.toggleMergeMonth()
                            } label: {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: viewModel.isMonthMerged(viewModel.selectedMonth) ? "arrow.uturn.backward" : "arrow.right.circle")
                                        .font(.caption)
                                    Text(viewModel.isMonthMerged(viewModel.selectedMonth) ? L10n("dashboard.unmerge") : L10n("dashboard.merge"))
                                        .font(AppTypography.captionMedium)
                                }
                                .foregroundColor(viewModel.isMonthMerged(viewModel.selectedMonth) ? AppColorTheme.negative : AppColorTheme.ctaPrimary)
                                .padding(.horizontal, AppSpacing.s)
                                .padding(.vertical, AppSpacing.xs)
                                .frame(minHeight: 44)
                                .background(
                                    Capsule()
                                        .fill(viewModel.isMonthMerged(viewModel.selectedMonth) ? AppColorTheme.negative.opacity(0.15) : AppColorTheme.ctaPrimary.opacity(0.15))
                                )
                            }
                            .accessibilityLabel(viewModel.isMonthMerged(viewModel.selectedMonth) ? L10n("dashboard.unmerge") : L10n("dashboard.merge"))
                            .accessibilityHint("Double tap to merge or unmerge month with current")
                        }
                        
                        monthPicker
                    }
                }
            }
            .refreshable {
                viewModel.refresh()
            }
            .onChange(of: viewModel.selectedMonth) { _, _ in
                withAnimation(AppAnimation.standard) {}
            }
            .onReceive(expenseService.$expenses) { _ in
                viewModel.updateDataAsync()
            }
            .onReceive(incomeService.$incomes) { _ in
                viewModel.updateDataAsync()
            }
            .fullScreenCover(isPresented: $showHistoryView) {
                HistoryView()
            }
            .sheet(isPresented: $showStatementImport) {
                StatementImportHomeView()
                    .presentationCornerRadius(24)
            }
        }
    }
    
    private var monthPicker: some View {
        Menu {
            ForEach(viewModel.availableMonths, id: \.self) { month in
                Button {
                    viewModel.selectedMonth = month
                } label: {
                    HStack {
                        Text(viewModel.monthString(for: month))
                        // Show checkmark for selected month, not current month
                        if viewModel.calendar.isDate(month, equalTo: viewModel.selectedMonth, toGranularity: .month) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(viewModel.monthString(for: viewModel.selectedMonth))
                    .font(AppTypography.bodySemibold)
                    .foregroundColor(AppColorTheme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(L10n("dashboard.select_month"))
        .accessibilityHint("Double tap to change month")
    }
    
    private var summarySection: some View {
        let currency = UserProfileService.shared.profile.currency
        let columns = [
            GridItem(.flexible(), spacing: AppSpacing.s),
            GridItem(.flexible(), spacing: AppSpacing.s)
        ]
        return LazyVGrid(columns: columns, spacing: AppSpacing.s) {
            DashboardKPICard(
                title: L10n("dashboard.income"),
                amount: viewModel.monthlyIncome,
                currencyCode: currency,
                accentColor: AppColorTheme.incomeIndicator,
                entranceIndex: 0,
                entranceReady: dashboardEntranceDone
            )

            DashboardKPICard(
                title: L10n("dashboard.expenses"),
                amount: viewModel.totalExpenses,
                currencyCode: currency,
                accentColor: AppColorTheme.expenseIndicator,
                entranceIndex: 1,
                entranceReady: dashboardEntranceDone
            )

            DashboardKPICard(
                title: L10n("dashboard.kpi.savings"),
                amount: viewModel.goalAllocations,
                currencyCode: currency,
                accentColor: AppColorTheme.savingsIndicator,
                entranceIndex: 2,
                entranceReady: dashboardEntranceDone
            )

            DashboardKPICard(
                title: L10n("dashboard.kpi.balance"),
                amount: viewModel.remainingBalance,
                currencyCode: currency,
                accentColor: viewModel.remainingBalance >= 0 ? AppColorTheme.balanceIndicator : AppColorTheme.warning,
                entranceIndex: 3,
                entranceReady: dashboardEntranceDone,
                surfaceBackground: AppColorTheme.kpiBalanceCardBackground,
                surfaceBorder: AppColorTheme.kpiBalanceCardBorder
            )
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: tappable to collapse/expand when there is data
            Button {
                guard !viewModel.categoryBreakdown.isEmpty else { return }
                HapticHelper.lightImpact()
                withAnimation(AppAnimation.cardExpand) {
                    isCategorySectionExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(L10n("dashboard.spending_by_category"))
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                    Spacer()
                    if !viewModel.categoryBreakdown.isEmpty {
                        Image(systemName: isCategorySectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.categoryBreakdown.isEmpty)
            
            if isCategorySectionExpanded || viewModel.categoryBreakdown.isEmpty {
                if viewModel.categoryBreakdown.isEmpty {
                    EmptyStateView(
                        icon: "chart.pie",
                        message: L10n("dashboard.empty_categories"),
                        actionTitle: L10n("dashboard.add_expense"),
                        action: { navigateToAddTab() },
                        compact: true
                    )
                } else {
                    CategoryChartView(categoryBreakdown: viewModel.categoryBreakdown)
                }
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
    }
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Button {
                    HapticHelper.lightImpact()
                    withAnimation(AppAnimation.cardExpand) {
                        isAllocatedSavingsExpanded.toggle()
                    }
                } label: {
                    Text(L10n("dashboard.allocated_savings"))
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                NavigationLink(destination: GoalsView()) {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.system(size: 14))
                        Text(L10n("dashboard.goals"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColorTheme.ctaPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColorTheme.ctaPrimary.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    HapticHelper.lightImpact()
                    withAnimation(AppAnimation.cardExpand) {
                        isAllocatedSavingsExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isAllocatedSavingsExpanded ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(minWidth: 32, minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isAllocatedSavingsExpanded ? L10n("dashboard.allocated_savings_a11y.collapse") : L10n("dashboard.allocated_savings_a11y.expand"))
            }
            
            if isAllocatedSavingsExpanded {
                if viewModel.activeGoals.isEmpty {
                    EmptyStateView(
                        icon: "target",
                        message: L10n("dashboard.no_active_savings"),
                        actionTitle: L10n("dashboard.create_goal"),
                        action: { navigateToGoalsView = true },
                        compact: true
                    )
                    .background(
                        NavigationLink(destination: GoalsView(), isActive: $navigateToGoalsView) {
                            EmptyView()
                        }
                        .hidden()
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.activeGoals.prefix(3)) { goal in
                            GoalSummaryCard(goal: goal)
                        }
                        
                        if viewModel.activeGoals.count > 3 {
                            NavigationLink(destination: GoalsView()) {
                                HStack {
                                    Text(L10n("dashboard.view_all_goals"))
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(AppColorTheme.ctaPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(AppColorTheme.layer3Elevated)
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, isAllocatedSavingsExpanded ? AppSpacing.m : AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
    }
    
    private var recentActivities: [ActivityItem] {
        getRecentActivities()
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
    
    private func navigateToAddTab() {
        HapticHelper.lightImpact()
        
        // Button press animation
        withAnimation(AppAnimation.buttonPress) {
            isButtonPressed = true
        }
        
        // Smooth transition to Add tab
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(AppAnimation.primaryTransition) {
                selectedTab = 2
            }
            
            // Reset button state after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(AppAnimation.standard) {
                    isButtonPressed = false
                }
            }
        }
    }
    
    private var recentExpensesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text(L10n("dashboard.recent_activity"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Spacer()
                
                HStack(spacing: AppSpacing.s) {
                    Button {
                        HapticHelper.lightImpact()
                        withAnimation(AppAnimation.sheetPresent) {
                            showHistoryView = true
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Text(L10n("dashboard.view_all"))
                                .font(AppTypography.captionMedium)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColorTheme.ctaPrimary)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.xs)
                        .frame(minHeight: 44)
                        .background(
                            Capsule()
                                .fill(AppColorTheme.ctaPrimary.opacity(0.12))
                        )
                    }
                    .accessibilityLabel(L10n("dashboard.view_all"))
                    .accessibilityHint("Double tap to open full transaction history")
                }
            }
            
            if recentActivities.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    message: L10n("dashboard.no_activity_yet"),
                    actionTitle: L10n("dashboard.view_all"),
                    action: {
                        HapticHelper.lightImpact()
                        withAnimation(AppAnimation.sheetPresent) { showHistoryView = true }
                    },
                    compact: true
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivities.enumerated()), id: \.element.id) { index, activity in
                        ActivityRowView(activity: activity, isPastMonth: viewModel.isPastMonth)
                        
                        if index < recentActivities.count - 1 {
                            Divider()
                                .background(AppColorTheme.rowDivider)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
    }
    
    private func getRecentActivities() -> [ActivityItem] {
        let calendar = Calendar.current
        let goalService = GoalService.shared
        var activities: [ActivityItem] = []
        
        // Get expenses and incomes for the selected month
        let expenses = ExpenseService.shared.expenses
            .filter { calendar.isDate($0.date, equalTo: viewModel.selectedMonth, toGranularity: .month) }
            .map { ActivityItem(expense: $0) }
        let incomes = IncomeService.shared.incomes
            .filter { calendar.isDate($0.date, equalTo: viewModel.selectedMonth, toGranularity: .month) }
            .map { ActivityItem(income: $0) }
        
        activities.append(contentsOf: expenses)
        activities.append(contentsOf: incomes)
        
        // Get goal contributions (money added to goals) for the selected month
        let goalActivities = goalService.activitiesForMonth(viewModel.selectedMonth)
        for goalActivity in goalActivities {
            let goalTitle = goalService.goals.first(where: { $0.id == goalActivity.goalId })?.title ?? L10n("dashboard.goals")
            activities.append(ActivityItem(goalActivity: goalActivity, goalTitle: goalTitle))
        }
        
        // Add merged balance entries if viewing current month
        if viewModel.isCurrentMonth {
            let mergedEntries = getMergedBalanceEntries()
            activities.append(contentsOf: mergedEntries)
        }
        
        return Array(activities.sorted { $0.date > $1.date }.prefix(6))
    }
    
    private func getMergedBalanceEntries() -> [ActivityItem] {
        var entries: [ActivityItem] = []
        let calendar = Calendar.current
        let currentCurrency = UserProfileService.shared.profile.currency
        
        for monthKey in viewModel.mergedMonths {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            if let monthDate = formatter.date(from: monthKey) {
                // Calculate remaining balance for that month
                let monthIncome = IncomeService.shared.totalIncomeForMonth(monthDate)
                let monthExpenses = ExpenseService.shared.totalExpensesForMonth(monthDate)
                let monthGoalAllocations = GoalService.shared.totalGoalAllocationsForMonth(monthDate)
                let monthBalance = monthIncome - monthExpenses - monthGoalAllocations
                
                if monthBalance > 0 {
                    // Use the first day of the month as the date for display
                    let monthStart = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
                    
                    // Format month name for display (nominative, e.g. "Февраль" not "февраля")
                    let monthName = LocalizationManager.shared.monthYearString(for: monthDate)
                    
                    let entry = ActivityItem(mergedBalance: monthName, amount: monthBalance, date: monthStart)
                    entries.append(entry)
                }
            }
        }
        
        return entries
    }
}

/// Dashboard 2×2 KPI tile: accent bar, title, and `AmountView` (secondary scale).
private struct DashboardKPICard: View {
    let title: String
    let amount: Double
    let currencyCode: String
    let accentColor: Color
    let entranceIndex: Int
    let entranceReady: Bool
    /// Defaults match other KPI tiles; Balance passes sapphire-tinted surfaces.
    let surfaceBackground: Color
    let surfaceBorder: Color

    init(
        title: String,
        amount: Double,
        currencyCode: String,
        accentColor: Color,
        entranceIndex: Int,
        entranceReady: Bool,
        surfaceBackground: Color = AppColorTheme.cardBackground,
        surfaceBorder: Color = AppColorTheme.cardBorder
    ) {
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.accentColor = accentColor
        self.entranceIndex = entranceIndex
        self.entranceReady = entranceReady
        self.surfaceBackground = surfaceBackground
        self.surfaceBorder = surfaceBorder
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)

                AmountView(amount: amount, style: .secondary, currencyCode: currencyCode)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.xs)
        .padding(.horizontal, AppSpacing.s)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(surfaceBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(surfaceBorder, lineWidth: 1)
                )
        )
        .opacity(entranceReady ? 1 : 0)
        .offset(y: entranceReady ? 0 : 12)
        .animation(AppAnimation.quickUI.delay(Double(entranceIndex) * 0.05), value: entranceReady)
        .accessibilityElement(children: .combine)
    }
}

struct CategoryChartView: View {
    let categoryBreakdown: [CategoryDisplayInfo: Double]
    
    var body: some View {
        let sortedCategories = categoryBreakdown.sorted { $0.value > $1.value }
        let total = categoryBreakdown.values.reduce(0, +)
        
        VStack(spacing: 0) {
            ForEach(Array(sortedCategories.enumerated()), id: \.element.key.id) { index, item in
                let categoryInfo = item.key
                let amount = item.value
                
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Icon with subtle background
                        ZStack {
                            Circle()
                                .fill(categoryColor(categoryInfo).opacity(0.15))
                                .frame(width: 36, height: 36)
                            
                            Text(categoryInfo.icon)
                                .font(.system(size: 16))
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(categoryInfo.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                
                                Spacer()
                                
                                Text(formatCurrency(amount))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColorTheme.textPrimary)
                            }
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColorTheme.chartBarBackground)
                                        .frame(height: 6)
                                    
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(categoryColor(categoryInfo))
                                        .frame(width: geometry.size.width * CGFloat(amount / total), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                    .padding(.vertical, 12)
                    
                    // Subtle divider (except for last item)
                    if index < sortedCategories.count - 1 {
                        Divider()
                            .background(AppColorTheme.rowDivider)
                    }
                }
            }
        }
    }
    
    private func categoryColor(_ categoryInfo: CategoryDisplayInfo) -> Color {
        categoryInfo.chartTintColor
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

struct GoalSummaryCard: View {
    let goal: Goal
    @StateObject private var goalService = GoalService.shared
    
    var body: some View {
        NavigationLink(destination: GoalsView()) {
            HStack(spacing: 12) {
                // Goal icon with subtle accent
                ZStack {
                    Circle()
                        .fill(AppColorTheme.savingsIndicator.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "target")
                        .foregroundColor(AppColorTheme.savingsIndicator)
                        .font(.system(size: 18))
                }
                
                // Goal info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(goal.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColorTheme.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(Int(goal.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColorTheme.savingsIndicator)
                    }
                    
                    // Thinner progress bar (4px)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColorTheme.chartBarBackground)
                                .frame(height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColorTheme.savingsIndicator)
                                .frame(width: geometry.size.width * CGFloat(goal.progress), height: 4)
                        }
                    }
                    .frame(height: 4)
                    
                    HStack(spacing: 2) {
                        Text(formatCurrency(goal.currentAmount))
                            .font(.caption2)
                            .foregroundColor(AppColorTheme.textSecondary)
                        Text("/")
                            .font(.caption2)
                            .foregroundColor(AppColorTheme.textTertiary)
                        Text(formatCurrency(goal.targetAmount))
                            .font(.caption2)
                            .foregroundColor(AppColorTheme.textTertiary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColorTheme.layer3Elevated)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

struct ActivityRowView: View {
    let activity: ActivityItem
    let isPastMonth: Bool
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    
    /// Icon color based on activity type
    private var iconColor: Color {
        if activity.isMergedBalance {
            return AppColorTheme.savingsIndicator
        } else if activity.isGoalContribution {
            return AppColorTheme.savingsIndicator
        } else if activity.isIncome {
            return AppColorTheme.incomeIndicator
        } else {
            return AppColorTheme.expenseIndicator
        }
    }
    
    /// Amount text color (muted for calm appearance)
    private var amountColor: Color {
        if activity.isMergedBalance || activity.isGoalContribution {
            return AppColorTheme.savingsIndicator
        } else if activity.isIncome {
            return AppColorTheme.positive.opacity(0.9)
        } else {
            return AppColorTheme.negativeMuted
        }
    }
    
    private var canEdit: Bool {
        !activity.isMergedBalance && !activity.isGoalContribution
    }
    
    var body: some View {
        Button {
            if canEdit {
                showEditSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                // Icon with subtle colored circle background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    
                    if activity.isMergedBalance {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(iconColor)
                    } else if activity.isGoalContribution {
                        Image(systemName: "target")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    } else if activity.isIncome {
                        if case .income(let income) = activity.type, income.source?.isCategoryDeletionRevert == true {
                            Image(systemName: "tray.and.arrow.up.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(iconColor)
                        } else if case .income(let income) = activity.type, income.source?.isSalary == true {
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(iconColor)
                        } else {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(iconColor)
                        }
                    } else {
                        if case .expense(let expense) = activity.type {
                            Text(expense.categoryIcon())
                                .font(.system(size: 16))
                        }
                    }
                }
                
                // Details
                VStack(alignment: .leading, spacing: 3) {
                    if activity.isMergedBalance {
                        if case .mergedBalance(let monthName, _, _) = activity.type {
                            Text(String(format: L10n("dashboard.merged_from"), monthName))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    } else if activity.isGoalContribution {
                        if case .goalContribution(_, let goalTitle) = activity.type {
                            Text(String(format: L10n("dashboard.to_goal"), goalTitle))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    } else if activity.isIncome {
                        if case .income(let income) = activity.type, income.source?.isCategoryDeletionRevert == true {
                            Text(L10n("deleted_category.income_title"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textPrimary)
                        } else if case .income(let income) = activity.type, income.isImported, let importedDescription = income.note, !importedDescription.isEmpty {
                            Text(importedDescription)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textPrimary)
                        } else if case .income(let income) = activity.type, income.source?.isSalary == true {
                            Text(L10n("activity.salary"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textPrimary)
                        } else {
                            Text(L10n("dashboard.income_label"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    } else {
                        if case .expense(let expense) = activity.type {
                            if expense.isImported, let importedDescription = expense.note, !importedDescription.isEmpty {
                                Text(importedDescription)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColorTheme.textPrimary)
                            } else {
                                Text(expense.categoryName())
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColorTheme.textPrimary)
                            }
                        }
                    }
                    
                    Text(activity.date, style: .date)
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                    
                    if case .expense(let expense) = activity.type, let note = expense.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .lineLimit(1)
                    }
                    
                    if case .income(let income) = activity.type, let note = income.note, !note.isEmpty {
                        Text(income.isImported ? "Imported from statement" : note)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .lineLimit(1)
                    }
                    
                    if case .goalContribution(let goalActivity, _) = activity.type, let note = goalActivity.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Amount with muted color
                Text(formatCurrencyForActivity())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(amountColor)
                
                // Delete button - gray by default, subtle
                if !activity.isMergedBalance {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(AppColorTheme.inactiveIndicator)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
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
                    if case .income(let income) = activity.type, income.source?.isCategoryDeletionRevert == true {
                        return L10n("deleted_category.income_title")
                    }
                    if case .income(let income) = activity.type, income.source?.isSalary == true {
                        return L10n("activity.salary")
                    }
                    if activity.isIncome { return L10n("activity.income") }
                    return L10n("activity.expense")
                }()
                Text(String(format: L10n("common.delete_confirm"), typeLabel))
            }
        }
    }
    
    private func deleteActivity() {
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
    
    private func formatCurrencyForActivity() -> String {
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

struct EditExpenseView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String
    @State private var selectedCategory: ExpenseCategory
    @State private var date: Date
    @State private var note: String
    
    init(expense: Expense) {
        self.expense = expense
        _amount = State(initialValue: String(format: "%.2f", expense.amount))
        _selectedCategory = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
        _note = State(initialValue: expense.note ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()

                Form {
                    Section(L10n("common.amount")) {
                        HStack {
                            Text(UserProfileService.shared.profile.currency)
                                .foregroundColor(AppColorTheme.textSecondary)
                            TextField("0", text: Binding(
                                get: { CurrencyFormatter.formatAmountForDisplay(amount) },
                                set: { amount = CurrencyFormatter.stripAmountFormatting($0) }
                            ))
                                .keyboardType(.decimalPad)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    }
                    
                    Section(L10n("common.category")) {
                        Picker(L10n("common.category"), selection: $selectedCategory) {
                            ForEach(ExpenseCategory.allCases, id: \.self) { category in
                                HStack {
                                    Text(category.icon)
                                    Text(category.localizedName)
                                }
                                .tag(category)
                            }
                        }
                    }
                    
                    Section(L10n("common.date")) {
                        DatePicker(L10n("common.date"), selection: $date, displayedComponents: .date)
                    }
                    
                    Section(L10n("common.note")) {
                        TextField(L10n("add_transaction.add_note_placeholder"), text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(AppColorTheme.textPrimary)
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(AppColorTheme.cardBackground)
                .tint(AppColorTheme.negative)
                .foregroundStyle(AppColorTheme.textPrimary)
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("dashboard.edit_expense"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(AppColorTheme.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveExpense()
                    }
                    .foregroundStyle(AppColorTheme.negative)
                }
            }
        }
    }
    
    private func saveExpense() {
        guard let expenseAmount = CurrencyFormatter.parsedAmount(from: amount), expenseAmount > 0 else { return }
        
        let updatedExpense = Expense(
            id: expense.id,
            amount: expenseAmount,
            category: selectedCategory,
            customCategoryId: expense.customCategoryId,
            date: date,
            note: note.isEmpty ? nil : note,
            currency: expense.currency,
            sourceType: expense.sourceType,
            sourceStatementID: expense.sourceStatementID,
            importBatchID: expense.importBatchID,
            originalImportedDescription: expense.originalImportedDescription,
            isImported: expense.isImported,
            importConfidence: expense.importConfidence
        )
        
        ExpenseService.shared.deleteExpense(expense)
        ExpenseService.shared.addExpense(updatedExpense)
        dismiss()
    }
}

struct EditIncomeView: View {
    let income: Income
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: String
    @State private var date: Date
    @State private var note: String
    
    init(income: Income) {
        self.income = income
        _amount = State(initialValue: String(format: "%.2f", income.amount))
        _date = State(initialValue: income.date)
        _note = State(initialValue: income.note ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()

                Form {
                    Section(L10n("common.amount")) {
                        HStack {
                            Text(UserProfileService.shared.profile.currency)
                                .foregroundColor(AppColorTheme.textSecondary)
                            TextField("0", text: Binding(
                                get: { CurrencyFormatter.formatAmountForDisplay(amount) },
                                set: { amount = CurrencyFormatter.stripAmountFormatting($0) }
                            ))
                                .keyboardType(.decimalPad)
                                .foregroundColor(AppColorTheme.textPrimary)
                        }
                    }
                    
                    Section(L10n("common.date")) {
                        AutoDismissDatePicker(selection: $date, displayedComponents: .date)
                    }
                    
                    Section(L10n("common.note")) {
                        TextField(L10n("add_transaction.add_note_placeholder"), text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(AppColorTheme.textPrimary)
                    }
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(AppColorTheme.cardBackground)
                .tint(AppColorTheme.positive)
                .foregroundStyle(AppColorTheme.textPrimary)
            }
            .dismissKeyboardOnTap()
            .navigationTitle(L10n("dashboard.edit_income"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(AppColorTheme.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveIncome()
                    }
                    .foregroundStyle(AppColorTheme.positive)
                }
            }
        }
    }
    
    private func saveIncome() {
        guard let incomeAmount = CurrencyFormatter.parsedAmount(from: amount), incomeAmount > 0 else { return }
        
        let updatedIncome = Income(
            id: income.id,
            amount: incomeAmount,
            date: date,
            note: note.isEmpty ? nil : note,
            currency: income.currency,
            source: income.source,
            sourceStatementID: income.sourceStatementID,
            importBatchID: income.importBatchID,
            originalImportedDescription: income.originalImportedDescription,
            isImported: income.isImported,
            importConfidence: income.importConfidence
        )
        
        IncomeService.shared.updateIncome(updatedIncome)
        dismiss()
    }
}

