//
//  AnalyticsView.swift
//  Friscora
//
//  Analytics tab: KPIs with trends, interactive charts, insights, category breakdown
//

import SwiftUI

// MARK: - Selected segment for interactive pie
enum IncomeBreakdownSegment: String, CaseIterable {
    case expenses
    case savings
    case remaining
}

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedSegment: IncomeBreakdownSegment?
    @State private var chartAnimated = false
    /// Bar chart only: 0 → 1 so progress bars animate from empty to full.
    @State private var barChartFillProgress: CGFloat = 0
    @State private var kpiCardsAppeared = false
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        summarySection
                        chartTypeToggle
                        breakdownChartSection
                        categoryBreakdownSection
                        insightsSection
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.vertical, AppSpacing.xl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    monthPickerToolbar
                }
            }
            .onAppear {
                viewModel.updateData()
                chartAnimated = false
                if viewModel.chartType == .bar { barChartFillProgress = 0 }
                kpiCardsAppeared = true
                withAnimation(AppAnimation.chartReveal) { chartAnimated = true }
                if viewModel.chartType == .bar {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(AppAnimation.chartBarReveal) { barChartFillProgress = 1 }
                    }
                }
            }
            .onChange(of: viewModel.selectedMonth) { _, newMonth in
                HapticHelper.lightImpact()
                FeedbackService.shared.setLastAnalyticsMonth(newMonth)
                viewModel.updateData()
                selectedSegment = nil
                chartAnimated = false
                if viewModel.chartType == .bar { barChartFillProgress = 0 }
                withAnimation(AppAnimation.chartReveal) { chartAnimated = true }
                if viewModel.chartType == .bar {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(AppAnimation.chartBarReveal) { barChartFillProgress = 1 }
                    }
                }
            }
            .onChange(of: viewModel.chartType) { _, newType in
                chartAnimated = false
                if newType == .bar { barChartFillProgress = 0 }
                DispatchQueue.main.async {
                    withAnimation(AppAnimation.chartReveal) { chartAnimated = true }
                    if viewModel.chartType == .bar {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(AppAnimation.chartBarReveal) { barChartFillProgress = 1 }
                        }
                    } else {
                        barChartFillProgress = 0
                    }
                }
            }
            .onReceive(ExpenseService.shared.$expenses) { _ in viewModel.updateData() }
            .onReceive(IncomeService.shared.$incomes) { _ in viewModel.updateData() }
            .onReceive(GoalService.shared.$goals) { _ in viewModel.updateData() }
            .onReceive(GoalService.shared.$activities) { _ in viewModel.updateData() }
        }
    }
    
    private var monthPickerToolbar: some View {
        Menu {
            ForEach(viewModel.availableMonths, id: \.self) { month in
                Button {
                    viewModel.selectedMonth = month
                } label: {
                    HStack {
                        Text(viewModel.monthString(for: month))
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
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(L10n("dashboard.select_month"))
        .accessibilityHint("Double tap to change period")
    }
    
    // MARK: - Summary KPIs with trend (vs last month)
    private var summarySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                AnalyticsSummaryCard(
                    title: L10n("dashboard.income"),
                    amount: viewModel.monthlyIncome,
                    color: AppColorTheme.incomeIndicator,
                    trend: viewModel.incomeTrend
                )
                .opacity(kpiCardsAppeared ? 1 : 0)
                .animation(AppAnimation.quickUI.delay(0), value: kpiCardsAppeared)
                AnalyticsSummaryCard(
                    title: L10n("dashboard.expenses"),
                    amount: viewModel.totalExpenses,
                    color: AppColorTheme.expenseIndicator,
                    trend: viewModel.expensesTrend
                )
                .opacity(kpiCardsAppeared ? 1 : 0)
                .animation(AppAnimation.quickUI.delay(0.05), value: kpiCardsAppeared)
            }
            .frame(height: 88)
            HStack(spacing: 16) {
                AnalyticsSummaryCard(
                    title: L10n("dashboard.allocated_savings"),
                    amount: viewModel.goalAllocations,
                    color: AppColorTheme.accent,
                    trend: viewModel.savingsTrend
                )
                .opacity(kpiCardsAppeared ? 1 : 0)
                .animation(AppAnimation.quickUI.delay(0.1), value: kpiCardsAppeared)
                AnalyticsSummaryCard(
                    title: L10n("dashboard.remaining_balance"),
                    amount: viewModel.remainingBalance,
                    color: viewModel.remainingBalance >= 0 ? AppColorTheme.balanceIndicator : AppColorTheme.warning,
                    trend: viewModel.remainingTrend
                )
                .opacity(kpiCardsAppeared ? 1 : 0)
                .animation(AppAnimation.quickUI.delay(0.15), value: kpiCardsAppeared)
            }
            .frame(height: 88)
        }
    }
    
    // MARK: - Insights card
    private var insightsSection: some View {
        Group {
            if !viewModel.insights.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColorTheme.goldAccent)
                        Text(L10n("analytics.insights_title"))
                            .font(.headline)
                            .foregroundColor(AppColorTheme.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.insights) { insight in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(AppColorTheme.goldAccent.opacity(0.4))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 7)
                                Text(insight.localizedMessage())
                                    .font(.subheadline)
                                    .foregroundColor(AppColorTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(AppSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppColorTheme.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Chart type toggle
    private var chartTypeToggle: some View {
        HStack(spacing: 10) {
            ForEach(AnalyticsChartType.allCases, id: \.rawValue) { type in
                let isSelected = viewModel.chartType == type
                Button {
                    HapticHelper.selection()
                    withAnimation(AppAnimation.segmentToggle) {
                        viewModel.chartType = type
                    }
                } label: {
                    Text(chartTypeTitle(type))
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundColor(isSelected ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? AppColorTheme.accent.opacity(0.25) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? AppColorTheme.accent : Color.clear, lineWidth: 1.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
    
    private func chartTypeTitle(_ type: AnalyticsChartType) -> String {
        switch type {
        case .pie: return L10n("analytics.chart.pie")
        case .bar: return L10n("analytics.chart.bar")
        }
    }
    
    // MARK: - Breakdown chart (Pie / Bar)
    private var breakdownChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if viewModel.monthlyIncome <= 0 && viewModel.totalExpenses <= 0 && viewModel.goalAllocations <= 0 {
                EmptyStateView(
                    icon: "chart.pie",
                    message: L10n("analytics.no_data"),
                    compact: true
                )
                .padding(.vertical, AppSpacing.s)
            } else {
                Group {
                    switch viewModel.chartType {
                    case .pie:
                        interactivePieContent
                    case .bar:
                        categoryBarChartContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(viewModel.chartType)
                .opacity(chartAnimated ? 1 : 0)
                .scaleEffect(chartAnimated ? 1 : 0.92)
                .animation(AppAnimation.chartReveal, value: chartAnimated)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(chartAccessibilitySummary())
        .accessibilityHint("Double tap to explore segments")
    }
    
    private func chartAccessibilitySummary() -> String {
        let currency = UserProfileService.shared.profile.currency
        let exp = CurrencyFormatter.format(viewModel.totalExpenses, currencyCode: currency)
        let sav = CurrencyFormatter.format(viewModel.goalAllocations, currencyCode: currency)
        let rem = CurrencyFormatter.format(max(0, viewModel.remainingBalance), currencyCode: currency)
        return "Income breakdown: expenses \(exp), savings \(sav), remaining \(rem)."
    }
    
    private var interactivePieContent: some View {
        HStack(alignment: .center, spacing: AppSpacing.l) {
            IncomeBreakdownPieChart(
                expenses: viewModel.totalExpenses,
                savings: viewModel.goalAllocations,
                remaining: max(0, viewModel.remainingBalance),
                totalIncome: viewModel.monthlyIncome,
                selectedSegment: $selectedSegment
            )
            .frame(width: 108, height: 108)
            .accessibilityLabel("Pie chart. Double tap to explore expenses, savings, and remaining segments.")
            
            // Fixed-width right panel so card width stays consistent (Remaining / Expenses / Savings)
            ZStack(alignment: .leading) {
                // Legend (no segment selected) – always present for layout
                VStack(alignment: .leading, spacing: 10) {
                    legendRow(L10n("analytics.pie.expenses"), viewModel.totalExpenses, AppColorTheme.expenseIndicator)
                    legendRow(L10n("analytics.pie.savings"), viewModel.goalAllocations, AppColorTheme.accent)
                    legendRow(L10n("analytics.pie.remaining"), max(0, viewModel.remainingBalance), AppColorTheme.balanceIndicator)
                }
                .frame(minWidth: breakdownPanelMinWidth, maxWidth: .infinity, alignment: .leading)
                .opacity(selectedSegment == nil ? 1 : 0)
                .animation(AppAnimation.quickUI, value: selectedSegment)
                
                if let seg = selectedSegment {
                    segmentOverlayLabel(segment: seg)
                        .frame(minWidth: breakdownPanelMinWidth, maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity
                        ))
                        .animation(AppAnimation.quickUI, value: selectedSegment)
                }
            }
            .frame(minWidth: breakdownPanelMinWidth, maxWidth: .infinity, alignment: .leading)
            .animation(AppAnimation.quickUI, value: selectedSegment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AppSpacing.xs)
    }
    
    /// Min width for pie right panel when segment overlay is shown; legend can use remaining space so amounts fit.
    private var breakdownPanelMinWidth: CGFloat { 140 }
    
    private func segmentOverlayLabel(segment: IncomeBreakdownSegment) -> some View {
        let (label, value, pct) = segmentInfo(segment)
        let color = segmentColor(segment)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColorTheme.textPrimary)
                .lineLimit(1)
            Text(formatCurrency(value))
                .font(AppTypography.heroNumber)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if pct >= 0 {
                Text("\(pct)%")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .fill(AppColorTheme.layer3Elevated)
        )
    }
    
    private func segmentInfo(_ segment: IncomeBreakdownSegment) -> (String, Double, Int) {
        let total = viewModel.totalExpenses + viewModel.goalAllocations + max(0, viewModel.remainingBalance)
        switch segment {
        case .expenses:
            let pct = total > 0 ? Int(100 * viewModel.totalExpenses / total) : 0
            return (L10n("analytics.pie.expenses"), viewModel.totalExpenses, pct)
        case .savings:
            let pct = total > 0 ? Int(100 * viewModel.goalAllocations / total) : 0
            return (L10n("analytics.pie.savings"), viewModel.goalAllocations, pct)
        case .remaining:
            let r = max(0, viewModel.remainingBalance)
            let pct = total > 0 ? Int(100 * r / total) : 0
            return (L10n("analytics.pie.remaining"), r, pct)
        }
    }
    
    private func segmentColor(_ segment: IncomeBreakdownSegment) -> Color {
        switch segment {
        case .expenses: return AppColorTheme.expenseIndicator
        case .savings: return AppColorTheme.accent
        case .remaining: return AppColorTheme.balanceIndicator
        }
    }
    
    private func legendRow(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColorTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: AppSpacing.xs)
            Text(formatCurrency(value))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(minHeight: 20)
    }
    
    /// Bar chart shows the same income breakdown as the Pie: Expenses, Savings, Remaining
    private var categoryBarChartContent: some View {
        let expenses = viewModel.totalExpenses
        let savings = viewModel.goalAllocations
        let remaining = max(0, viewModel.remainingBalance)
        let total = expenses + savings + remaining
        let items: [(label: String, value: Double, color: Color)] = [
            (L10n("analytics.pie.expenses"), expenses, AppColorTheme.expenseIndicator),
            (L10n("analytics.pie.savings"), savings, AppColorTheme.accent),
            (L10n("analytics.pie.remaining"), remaining, AppColorTheme.balanceIndicator)
        ]
        return Group {
            if total <= 0 {
                EmptyStateView(
                    icon: "chart.pie",
                    message: L10n("analytics.no_data"),
                    compact: true
                )
                .padding(.vertical, AppSpacing.s)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        let pct = item.value / total
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.label)
                                    .font(.subheadline)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                Spacer()
                                Text(formatCurrency(item.value))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColorTheme.textSecondary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColorTheme.chartBarBackground)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(item.color)
                                        .frame(width: max(0, geo.size.width * CGFloat(pct) * barChartFillProgress))
                                }
                            }
                            .frame(height: 8)
                            .animation(AppAnimation.chartBarReveal.delay(Double(index) * 0.1), value: barChartFillProgress)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    /// Compact currency for chart labels: 15000 → "15k", 2850 → "2.9k"
    /// Compact currency for chart axes: 15000 → "15k", -2500 → "-2.5k"
    private func compactCurrency(_ value: Double) -> String {
        let currency = UserProfileService.shared.profile.currency
        let absVal = abs(value)
        if absVal >= 1_000_000 {
            return String(format: "%.1fM %@", value / 1_000_000, currency)
        }
        if absVal >= 1_000 {
            return String(format: "%.0fk %@", value / 1_000, currency)
        }
        return CurrencyFormatter.format(value, currencyCode: currency)
    }
    
    // MARK: - Category breakdown with progress bars
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n("dashboard.spending_by_category"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
            
            if viewModel.categoryBreakdown.isEmpty {
                EmptyStateView(
                    icon: "chart.bar",
                    message: L10n("dashboard.empty_categories"),
                    compact: true
                )
                .padding(.vertical, AppSpacing.s)
            } else {
                let sorted = viewModel.categoryBreakdown.sorted { $0.value > $1.value }
                let total = viewModel.categoryBreakdown.values.reduce(0, +)
                VStack(spacing: 0) {
                    ForEach(Array(sorted.enumerated()), id: \.element.key.id) { index, item in
                        let progress = total > 0 ? item.value / total : 0
                        HStack(spacing: 12) {
                            Text(item.key.icon)
                                .font(.system(size: 18))
                            Text(item.key.name)
                                .font(.subheadline)
                                .foregroundColor(AppColorTheme.textPrimary)
                            Spacer()
                            Text(formatCurrency(item.value))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textSecondary)
                            Text("\(Int(100 * progress))%")
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.vertical, 10)
                        ProgressView(value: progress)
                            .tint(categoryColor(item.key))
                            .padding(.leading, 30)
                        if index < sorted.count - 1 {
                            Divider()
                                .background(AppColorTheme.rowDivider)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
    }
    
    private func categoryColor(_ categoryInfo: CategoryDisplayInfo) -> Color {
        if categoryInfo.isCustom {
            return AppColorTheme.chartBarFill
        }
        if let category = ExpenseCategory(rawValue: categoryInfo.name) {
            return AppColorTheme.color(for: category)
        }
        return AppColorTheme.chartBarFill
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        CurrencyFormatter.format(amount, currencyCode: UserProfileService.shared.profile.currency)
    }
}

// MARK: - Summary card with trend
struct AnalyticsSummaryCard: View {
    let title: String
    let amount: Double
    let color: Color
    var trend: KPITrend?
    
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColorTheme.textSecondary)
                Text(CurrencyFormatter.formatCompact(amount, currencyCode: UserProfileService.shared.profile.currency))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let t = trend {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if t.direction != .neutral {
                                Image(systemName: t.direction == .up ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            if let pct = t.percentChange {
                                Text(formatPercentSigned(pct))
                                    .font(.caption2)
                                    .foregroundColor(percentColor(pct))
                            } else if t.direction == .neutral {
                                Text("0%")
                                    .font(.caption2)
                                    .foregroundColor(AppColorTheme.textTertiary)
                            } else {
                                Text("—")
                                    .font(.caption2)
                                    .foregroundColor(AppColorTheme.textTertiary)
                            }
                        }
                        .foregroundColor(trendIconColor(t))
                        Text(L10n("analytics.vs_last_month"))
                            .font(.system(size: 9))
                            .foregroundColor(AppColorTheme.textTertiary)
                    }
                }
            }
            Spacer()
        }
        .padding(AppSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
    }
    
    /// Percentage text and arrow: positive = green, negative = red
    private func percentColor(_ value: Double) -> Color {
        value >= 0 ? AppColorTheme.incomeIndicator : AppColorTheme.expenseIndicator
    }
    
    private func trendIconColor(_ t: KPITrend) -> Color {
        guard let pct = t.percentChange else { return AppColorTheme.textTertiary }
        return percentColor(pct)
    }
    
    private func formatPercentSigned(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : ""
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let num = formatter.string(from: NSNumber(value: Int(round(value)))) ?? "\(Int(round(value)))"
        return "\(sign)\(num)%"
    }
}

// MARK: - Interactive pie chart
struct IncomeBreakdownPieChart: View {
    let expenses: Double
    let savings: Double
    let remaining: Double
    let totalIncome: Double
    @Binding var selectedSegment: IncomeBreakdownSegment?
    
    private var safeRemaining: Double { max(0, remaining) }
    private var totalOutcome: Double { expenses + savings + safeRemaining }
    
    private var normalizedExpenses: Double {
        guard totalOutcome > 0 else { return 0 }
        return expenses / totalOutcome
    }
    private var normalizedSavings: Double {
        guard totalOutcome > 0 else { return 0 }
        return savings / totalOutcome
    }
    private var normalizedRemaining: Double {
        guard totalOutcome > 0 else { return 0 }
        return safeRemaining / totalOutcome
    }
    
    var body: some View {
        ZStack {
            if totalOutcome <= 0 {
                Circle()
                    .stroke(AppColorTheme.chartBarBackground, lineWidth: 20)
                    .frame(width: 108, height: 108)
                Text("—")
                    .font(.title3)
                    .foregroundColor(AppColorTheme.textTertiary)
            } else {
                PieChartShape(
                    expensesShare: normalizedExpenses,
                    savingsShare: normalizedSavings,
                    remainingShare: normalizedRemaining,
                    selectedSegment: $selectedSegment
                )
                .frame(width: 108, height: 108)
            }
        }
    }
}

struct PieChartShape: View {
    let expensesShare: Double
    let savingsShare: Double
    let remainingShare: Double
    @Binding var selectedSegment: IncomeBreakdownSegment?
    @State private var fillProgress: CGFloat = 0
    
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                if expensesShare > 0 {
                    sliceView(
                        start: -90,
                        end: -90 + 360 * expensesShare,
                        color: AppColorTheme.expenseIndicator,
                        segment: .expenses,
                        size: size,
                        center: center
                    )
                }
                if savingsShare > 0 {
                    sliceView(
                        start: -90 + 360 * expensesShare,
                        end: -90 + 360 * (expensesShare + savingsShare),
                        color: AppColorTheme.accent,
                        segment: .savings,
                        size: size,
                        center: center
                    )
                }
                if remainingShare > 0 {
                    sliceView(
                        start: -90 + 360 * (expensesShare + savingsShare),
                        end: -90 + 360 * (expensesShare + savingsShare + remainingShare),
                        color: AppColorTheme.balanceIndicator,
                        segment: .remaining,
                        size: size,
                        center: center
                    )
                }
            }
        }
        .id("\(expensesShare)-\(savingsShare)-\(remainingShare)")
        .onAppear {
            fillProgress = 0
            withAnimation(AppAnimation.chartPieReveal) { fillProgress = 1 }
        }
    }
    
    private func sliceView(
        start: Double,
        end: Double,
        color: Color,
        segment: IncomeBreakdownSegment,
        size: CGFloat,
        center: CGPoint
    ) -> some View {
        let isSelected = selectedSegment == segment
        return PieSliceShape(startAngle: .degrees(start), endAngle: .degrees(end), progress: fillProgress)
            .fill(color)
            .overlay(
                PieSliceShape(startAngle: .degrees(start), endAngle: .degrees(end), progress: fillProgress)
                    .fill(Color.white.opacity(isSelected ? 0.15 : 0))
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
            .frame(width: size, height: size)
            .position(center)
            .contentShape(PieSliceShape(startAngle: .degrees(start), endAngle: .degrees(end), progress: 1))
            .onTapGesture {
                HapticHelper.selection()
                withAnimation(AppAnimation.standard) {
                    selectedSegment = selectedSegment == segment ? nil : segment
                }
            }
    }
}

struct PieSliceShape: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var progress: CGFloat = 1
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let sweep = endAngle.degrees - startAngle.degrees
        let effectiveEnd = startAngle.degrees + sweep * Double(progress)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: r, startAngle: startAngle, endAngle: .degrees(effectiveEnd), clockwise: false)
        path.closeSubpath()
        return path
    }
}
