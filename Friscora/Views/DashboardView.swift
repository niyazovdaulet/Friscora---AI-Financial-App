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
    /// Prior hero height before −40% trim; used to scale KPI overlap and spark inset.
    private enum HeroLayout {
        static let referenceHeight: CGFloat = 312
        /// 40% shorter than `referenceHeight` (60% of original).
        static let cardHeight: CGFloat = (referenceHeight * 0.6).rounded()
        static let kpiOverlap: CGFloat = (56 * (cardHeight / referenceHeight)).rounded()
        static let sparkBottomInset: CGFloat = (68 * (cardHeight / referenceHeight)).rounded()
    }

    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var expenseService = ExpenseService.shared
    @StateObject private var incomeService = IncomeService.shared
    @StateObject private var goalService = GoalService.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @Binding var selectedTab: Int
    @State private var showHistoryView = false
    @State private var showStatementImport = false
    @State private var showGoalsFromSavingsCard = false
    @State private var heroReveal = false
    @State private var sparklineEntranceTrigger = 0
    @State private var categorySectionReveal = false
    @State private var activitySectionReveal = false
    @State private var animatedRemaining: Double = 0
    @State private var animatedIncome: Double = 0
    @State private var animatedExpenses: Double = 0
    @State private var animatedSavings: Double = 0
    
    init(selectedTab: Binding<Int> = .constant(0)) {
        _selectedTab = selectedTab
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppColorTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.l) {
                        heroSection
                            .frame(height: HeroLayout.cardHeight)

                        kpiSection
                            .padding(.top, -HeroLayout.kpiOverlap)

                        spendingByCategorySection
                            .opacity(categorySectionReveal ? 1 : 0)
                            .offset(y: categorySectionReveal ? 0 : 18)

                        transactionsPreviewSection
                            .opacity(activitySectionReveal ? 1 : 0)
                            .offset(y: activitySectionReveal ? 0 : 18)
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.top, 18)
                    .padding(.bottom, AppSpacing.xl)
                }
                .scrollIndicators(.hidden, axes: .vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showStatementImport = true
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.caption)
                            Text(L10n("dashboard.toolbar.import"))
                                .font(AppTypography.captionMedium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Capsule().fill(AppColorTheme.ctaPrimary.opacity(0.15)))
                    }
                    .accessibilityLabel(L10n("dashboard.toolbar.import_a11y"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    monthPicker
                }
            }
            .refreshable {
                viewModel.refresh()
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
            .navigationDestination(isPresented: $showGoalsFromSavingsCard) {
                GoalsView()
            }
            .sheet(isPresented: $showStatementImport) {
                StatementImportHomeView(selectedTab: $selectedTab)
                    .presentationCornerRadius(24)
            }
            .onAppear {
                runEntranceAnimations()
                animateKPIValues()
            }
            .onChange(of: selectedTab) { _, newTab in
                guard newTab == 0 else { return }
                replayDashboardTabAnimations()
            }
            .onChange(of: viewModel.remainingBalance) { _, _ in animateKPIValues() }
            .onChange(of: viewModel.monthlyIncome) { _, _ in animateKPIValues() }
            .onChange(of: viewModel.totalExpenses) { _, _ in animateKPIValues() }
            .onChange(of: viewModel.goalAllocations) { _, _ in animateKPIValues() }
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
    
    private var heroSection: some View {
        let currency = UserProfileService.shared.profile.currency
        let heroChrome = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let borderColor = Color(red: 140 / 255, green: 100 / 255, blue: 255 / 255).opacity(0.25)
        let labelTint = Color(red: 200 / 255, green: 180 / 255, blue: 255 / 255)

        return ZStack(alignment: .topLeading) {
            heroChrome
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "1a2a6e"), location: 0),
                            .init(color: Color(hex: "2a1a7e"), location: 0.4),
                            .init(color: Color(hex: "4a1a8e"), location: 0.7),
                            .init(color: Color(hex: "6a1a7e"), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 180 / 255, green: 120 / 255, blue: 255 / 255).opacity(0.25),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 154
                            )
                        )
                        .frame(width: 220, height: 220)
                        .offset(x: 54, y: -54)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 80 / 255, green: 120 / 255, blue: 255 / 255).opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 112
                            )
                        )
                        .frame(width: 160, height: 160)
                        .offset(x: -40, y: 40)
                }
                .clipShape(heroChrome)
                .overlay {
                    heroChrome.stroke(borderColor, lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n("dashboard.hero.current_balance"))
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .tracking(1.35)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white)

                    Text(heroLastUpdatedText)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundStyle(labelTint.opacity(0.5))

                    DashboardHeroAmountRow(
                        amount: animatedRemaining,
                        currencyCode: currency,
                        majorFontSize: 31,
                        minorFontSize: 14,
                        majorTracking: -0.75
                    )
                    .contentTransition(.numericText())

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(labelTint.opacity(0.65))
                        Text(
                            String(
                                format: L10n("dashboard.hero.daily_average_format"),
                                CurrencyFormatter.format(dailyBudget, currencyCode: currency)
                            )
                        )
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundStyle(labelTint.opacity(0.65))
                    }
                    .padding(.top, 1)

                    Color.clear.frame(height: 6)

                    DashboardHeroSparkline(chartHeight: 26, lineStrokeWidth: 1.25, entranceTrigger: sparklineEntranceTrigger)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.s)
                .padding(.bottom, HeroLayout.sparkBottomInset)
                .opacity(heroReveal ? 1 : 0)
                .offset(y: heroReveal ? 0 : 16)
                .animation(AppAnimation.primaryTransition, value: heroReveal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                Image("app-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 8, x: 0, y: 4)
                    .padding(.top, AppSpacing.s)
                    .padding(.trailing, AppSpacing.s)
            }
        }
        .frame(maxWidth: .infinity)
        .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 12)
    }

    private var kpiSection: some View {
        let currency = UserProfileService.shared.profile.currency
        return HStack(spacing: AppSpacing.s) {
            PremiumKPICard(
                title: L10n("dashboard.income"),
                amount: animatedIncome,
                currencyCode: currency,
                accentColor: AppColorTheme.incomeIndicator
            ) {
                HapticHelper.mediumImpact()
                withAnimation(AppAnimation.primaryTransition) {
                    selectedTab = 1
                }
            }
            PremiumKPICard(
                title: L10n("dashboard.expenses"),
                amount: animatedExpenses,
                currencyCode: currency,
                accentColor: AppColorTheme.expenseIndicator
            ) {
                HapticHelper.mediumImpact()
                withAnimation(AppAnimation.sheetPresent) {
                    showHistoryView = true
                }
            }
            PremiumKPICard(
                title: L10n("dashboard.kpi.savings"),
                amount: animatedSavings,
                currencyCode: currency,
                accentColor: AppColorTheme.balanceIndicator
            ) {
                HapticHelper.mediumImpact()
                withAnimation(AppAnimation.primaryTransition) {
                    showGoalsFromSavingsCard = true
                }
            }
        }
    }

    private var spendingByCategorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(L10n("dashboard.spending_by_category"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.categoryBreakdown.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    message: L10n("dashboard.empty_categories"),
                    actionTitle: L10n("dashboard.add_expense"),
                    action: { selectedTab = 2 },
                    compact: true
                )
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.m)
                .background(spendingByCategoryCardChrome)
            } else {
                let fullRows = viewModel.orderedCategorySpendingForDashboard
                let visibleRows = Array(fullRows.prefix(4))
                let hasMoreCategories = fullRows.count > 4
                let totalSpending = max(viewModel.categoryBreakdown.values.reduce(0, +), 0.01)
                let locale = localizationManager.currentLocale
                VStack(spacing: 0) {
                    ForEach(Array(visibleRows.enumerated()), id: \.element.category.id) { index, row in
                        let share = row.amount / totalSpending
                        VStack(spacing: 0) {
                            PremiumCategoryRow(
                                category: row.category,
                                amount: row.amount,
                                progress: share,
                                currencyCode: UserProfileService.shared.profile.currency,
                                locale: locale,
                                index: index
                            )
                            .padding(.horizontal, AppSpacing.m)
                            .padding(.vertical, AppSpacing.s)

                            if index < visibleRows.count - 1 {
                                spendingByCategoryRowDivider
                            }
                        }
                    }
                    if hasMoreCategories {
                        HStack {
                            Spacer()
                            Button {
                                HapticHelper.lightImpact()
                                AnalyticsMonthHandoff.scheduleOpenAligningAnalytics(toMonth: viewModel.selectedMonth)
                                // Analytics tab index matches `MainTabView` / `CustomTabBar` (1 = chart / full breakdown).
                                withAnimation(AppAnimation.primaryTransition) {
                                    selectedTab = 1
                                }
                            } label: {
                                Text(L10n("dashboard.spending_by_category_show_more"))
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColorTheme.ctaPrimary)
                                    .padding(.horizontal, AppSpacing.s)
                                    .padding(.vertical, AppSpacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(AppColorTheme.ctaPrimary.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(L10n("dashboard.spending_by_category_show_more_a11y"))
                        }
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, AppSpacing.s)
                    }
                }
                .background(spendingByCategoryCardChrome)
            }
        }
    }

    private var spendingByCategoryCardChrome: some View {
        RoundedRectangle(cornerRadius: AppRadius.card)
            .fill(AppColorTheme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(AppColorTheme.cardBorder, lineWidth: 1)
            )
    }

    private var spendingByCategoryRowDivider: some View {
        Rectangle()
            .fill(AppColorTheme.rowDivider)
            .frame(height: 1)
            .padding(.horizontal, AppSpacing.m)
    }

    private var transactionsPreviewSection: some View {
        let preview = Array(getRecentActivities().prefix(4))
        return VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                Text(L10n("dashboard.recent_activity"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
                Button {
                    HapticHelper.lightImpact()
                    withAnimation(AppAnimation.sheetPresent) {
                        showHistoryView = true
                    }
                } label: {
                    Text(L10n("dashboard.view_all"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColorTheme.ctaPrimary)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColorTheme.ctaPrimary.opacity(0.12))
                        )
                }
            }

            if preview.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    message: L10n("dashboard.no_activity_yet"),
                    actionTitle: L10n("dashboard.view_all"),
                    action: { showHistoryView = true },
                    compact: true
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(preview) { activity in
                        TransactionPreviewRow(activity: activity)
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

    private var dailyBudget: Double {
        let days = Calendar.current.range(of: .day, in: .month, for: viewModel.selectedMonth)?.count ?? 30
        return viewModel.remainingBalance / Double(max(days, 1))
    }

    /// Latest date among expenses, incomes, and goal contributions (any month).
    private func latestDashboardActivityDate() -> Date? {
        var latest: Date?
        for expense in expenseService.expenses {
            if latest == nil || expense.date > latest! {
                latest = expense.date
            }
        }
        for income in incomeService.incomes {
            if latest == nil || income.date > latest! {
                latest = income.date
            }
        }
        for activity in goalService.activities {
            if latest == nil || activity.date > latest! {
                latest = activity.date
            }
        }
        return latest
    }

    private var heroLastUpdatedText: String {
        guard let latest = latestDashboardActivityDate() else {
            return L10n("dashboard.hero.no_activity")
        }
        let seconds = Date().timeIntervalSince(latest)
        if seconds < 60 {
            return L10n("dashboard.hero.updated_just_now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let locale = localizationManager.currentLocale
        formatter.locale = locale
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        formatter.calendar = calendar
        let relative = formatter.localizedString(for: latest, relativeTo: Date())
        return String(format: L10n("dashboard.hero.updated_format"), relative)
    }

    private func animateKPIValues() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
            animatedRemaining = viewModel.remainingBalance
            animatedIncome = viewModel.monthlyIncome
            animatedExpenses = viewModel.totalExpenses
            animatedSavings = viewModel.goalAllocations
        }
    }

    /// `MainTabView` keeps tab roots mounted (opacity stack), so `onAppear` does not run again when returning to Dashboard — reset KPI drivers then count up on next run loop.
    private func replayDashboardTabAnimations() {
        withAnimation(.none) {
            animatedRemaining = 0
            animatedIncome = 0
            animatedExpenses = 0
            animatedSavings = 0
        }
        sparklineEntranceTrigger += 1
        DispatchQueue.main.async {
            animateKPIValues()
        }
    }

    private func runEntranceAnimations() {
        guard !heroReveal else { return }
        withAnimation(AppAnimation.primaryTransition) { heroReveal = true }
        sparklineEntranceTrigger += 1
        withAnimation(AppAnimation.quickUI.delay(0.1)) { categorySectionReveal = true }
        withAnimation(AppAnimation.quickUI.delay(0.2)) { activitySectionReveal = true }
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

/// Hero balance: `CurrencyFormatter` comma/period split; Syne approximated with heavy rounded system at 48pt / 22pt suffix.
private struct DashboardHeroAmountRow: View {
    let amount: Double
    let currencyCode: String
    var majorFontSize: CGFloat = 48
    var minorFontSize: CGFloat = 22
    var majorTracking: CGFloat = -1

    private var components: AmountComponents {
        CurrencyFormatter.components(amount, currencyCode: currencyCode)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            splitLine
            compactLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var splitLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(components.major)
                .font(.system(size: majorFontSize, weight: .heavy, design: .rounded))
                .tracking(majorTracking)
                .foregroundStyle(Color.white)
                .monospacedDigit()
            if !components.minor.isEmpty {
                Text(components.minor)
                    .font(.system(size: minorFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .monospacedDigit()
            }
            Text(components.currency)
                .font(.system(size: minorFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .lineLimit(1)
    }

    private var compactLine: some View {
        let parts = CurrencyFormatter.compactAmountParts(amount, currencyCode: currencyCode)
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(parts.numeric)
                .font(.system(size: majorFontSize, weight: .heavy, design: .rounded))
                .tracking(majorTracking)
                .foregroundStyle(Color.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(parts.currency)
                .font(.system(size: minorFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .lineLimit(1)
        }
    }
}

private struct PremiumKPICard: View {
    let title: String
    let amount: Double
    let currencyCode: String
    let accentColor: Color
    var onTap: (() -> Void)? = nil
    @State private var isPressed = false

    var body: some View {
        Button {
            HapticHelper.lightImpact()
            if let onTap {
                onTap()
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 4, height: 16)

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AppColorTheme.textSecondary)
                }

                AmountView(amount: amount, style: .secondary, currencyCode: currencyCode)
                    .contentTransition(.numericText())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColorTheme.layer2Card.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                    )
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(AppAnimation.buttonPress, value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 25, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

private struct PremiumCategoryRow: View {
    let category: CategoryDisplayInfo
    let amount: Double
    /// Share of total spending (0...1); drives bar fill and the trailing percent.
    let progress: Double
    let currencyCode: String
    let locale: Locale
    let index: Int

    @State private var animatedProgress: Double = 0

    private static let iconWellSize: CGFloat = 38
    private static let iconWellCorner: CGFloat = 9

    private var formattedAmount: String {
        CurrencyFormatter.format(amount, currencyCode: currencyCode)
    }

    private var sharePercentText: String {
        let clamped = min(max(progress, 0), 1)
        return clamped.formatted(.percent.locale(locale).precision(.fractionLength(0...1)))
    }

    private var accessibilityCombinedLabel: String {
        String(
            format: L10n("dashboard.spending_by_category_row_a11y"),
            category.name,
            formattedAmount,
            sharePercentText
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            ZStack {
                RoundedRectangle(cornerRadius: Self.iconWellCorner, style: .continuous)
                    .fill(category.chartTintColor.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: Self.iconWellCorner, style: .continuous)
                            .stroke(category.chartTintColor.opacity(0.32), lineWidth: 1)
                    )
                    .frame(width: Self.iconWellSize, height: Self.iconWellSize)
                Text(category.icon)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(category.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColorTheme.chartBarBackground)
                        Capsule()
                            .fill(category.chartTintColor)
                            .frame(width: max(0, proxy.size.width * animatedProgress))
                    }
                }
                .frame(height: 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)

                Text(sharePercentText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .layoutPriority(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityCombinedLabel)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.9).delay(Double(index) * 0.06)) {
                animatedProgress = min(max(progress, 0), 1)
            }
        }
    }
}

private struct TransactionPreviewRow: View {
    let activity: ActivityItem

    private var iconSymbol: String {
        if activity.isGoalContribution { return "target" }
        if activity.isIncome { return "arrow.down" }
        return "arrow.up"
    }

    private var iconColor: Color {
        if activity.isGoalContribution { return AppColorTheme.savingsIndicator }
        if activity.isIncome { return AppColorTheme.incomeIndicator }
        return AppColorTheme.expenseIndicator
    }

    private var title: String {
        switch activity.type {
        case .expense(let expense):
            if expense.isImported, let note = expense.note, !note.isEmpty { return note }
            return expense.categoryName()
        case .income(let income):
            if income.isImported, let note = income.note, !note.isEmpty { return note }
            return L10n("dashboard.income")
        case .goalContribution(_, let goalTitle):
            return String(format: L10n("dashboard.to_goal"), goalTitle)
        case .mergedBalance(let monthName, _, _):
            return String(format: L10n("dashboard.merged_from"), monthName)
        }
    }

    private var amountString: String {
        switch activity.type {
        case .expense(let expense):
            return CurrencyFormatter.format(-expense.amount, currencyCode: expense.currency)
        case .income(let income):
            return CurrencyFormatter.format(income.amount, currencyCode: income.currency)
        case .goalContribution(let goalActivity, _):
            return CurrencyFormatter.format(-goalActivity.amount, currencyCode: UserProfileService.shared.profile.currency)
        case .mergedBalance(_, let amount, _):
            return CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(iconColor.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: iconSymbol)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(iconColor)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .lineLimit(1)
                Text(activity.date, style: .date)
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            Spacer()
            Text(amountString)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(iconColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColorTheme.layer3Elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
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

