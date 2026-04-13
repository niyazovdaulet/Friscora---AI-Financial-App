//
//  AnalyticsView.swift
//  Friscora
//
//  Analytics tab: period control, one primary spending chart, category detail, insights
//

import SwiftUI

/// Amounts below this are treated as zero for analytics trend placeholders (avoids noisy −100% MoM).
private let analyticsTrendMetricZeroEpsilon: Double = 0.005

private enum IncomeSplitSegmentKind: Equatable {
    case expenses
    case savings
    case remaining
}

struct AnalyticsView: View {
    @Binding var selectedTab: Int
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var chartAnimated = false
    /// Per-slice sweep 0 → 1 (order matches `combinedPieSlices`; staggered animation).
    @State private var pieSliceProgress: [CGFloat] = []
    /// Invalidates in-flight wedge animations when month changes.
    @State private var pieAnimationToken = 0
    @State private var trendStripAppeared = false
    /// Selected pie slice id (matches `CategoryPieSliceModel.id`, including `analytics_savings_slice`).
    @State private var selectedCategorySliceId: String? = nil
    /// Selected slice on the income split capsule (tooltip + legend sync).
    @State private var incomeSplitSelectedSegment: IncomeSplitSegmentKind? = nil
    /// Animates segment widths (`AppAnimation.incomeSplitSegmentReveal`).
    @State private var incomeSplitBarReveal: CGFloat = 0
    @State private var showAdviserView = false
    @State private var pendingAIQuestion: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        analyticsTrendStrip
                        savingsRateCaption
                        primaryCategorySpendingSection
                        insightsSection
                    }
                    // Match `DashboardView` scroll content insets (screen-edge margins).
                    .padding(AppSpacing.m)
                }
                .scrollIndicators(.hidden, axes: .vertical)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(AppAnimation.sheetPresent) {
                            showAdviserView = true
                        }
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(AppColorTheme.goldAccent)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(L10n("chat.title"))
                    .accessibilityHint(L10n("analytics.ai.open_hint"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    monthPickerToolbar
                }
            }
            .onAppear {
                viewModel.updateData()
                chartAnimated = false
                trendStripAppeared = true
                let slices = currentPieSlices()
                pieSliceProgress = Array(repeating: 0, count: slices.count)
                withAnimation(AppAnimation.analyticsHeroReveal) { chartAnimated = true }
                scheduleStaggeredPieFill(slices: slices)
                scheduleIncomeSplitBarReveal()
            }
            .onChange(of: viewModel.selectedMonth) { _, newMonth in
                HapticHelper.lightImpact()
                FeedbackService.shared.setLastAnalyticsMonth(newMonth)
                viewModel.updateData()
                selectedCategorySliceId = nil
                incomeSplitSelectedSegment = nil
                incomeSplitBarReveal = 0
                chartAnimated = false
                let slices = currentPieSlices()
                pieSliceProgress = Array(repeating: 0, count: slices.count)
                withAnimation(AppAnimation.analyticsHeroReveal) { chartAnimated = true }
                scheduleStaggeredPieFill(slices: slices)
                scheduleIncomeSplitBarReveal()
            }
            .onReceive(ExpenseService.shared.$expenses) { _ in viewModel.updateData() }
            .onReceive(IncomeService.shared.$incomes) { _ in viewModel.updateData() }
            .onReceive(GoalService.shared.$goals) { _ in viewModel.updateData() }
            .onReceive(GoalService.shared.$activities) { _ in viewModel.updateData() }
            .onChange(of: selectedTab) { _, newTab in
                guard newTab != 1 else { return }
                dismissAnalyticsSelections(animated: false)
            }
            .fullScreenCover(isPresented: $showAdviserView, onDismiss: {
                pendingAIQuestion = nil
            }) {
                ChatView(referenceMonth: $viewModel.selectedMonth, initialQuestion: pendingAIQuestion)
            }
        }
    }

    private func dismissAnalyticsSelections(animated: Bool = true) {
        guard selectedCategorySliceId != nil || incomeSplitSelectedSegment != nil else { return }
        if animated {
            withAnimation(AppAnimation.snappy) {
                selectedCategorySliceId = nil
                incomeSplitSelectedSegment = nil
            }
        } else {
            selectedCategorySliceId = nil
            incomeSplitSelectedSegment = nil
        }
    }

    private func clearPieSelectionOnly(animated: Bool = true) {
        guard selectedCategorySliceId != nil else { return }
        if animated {
            withAnimation(AppAnimation.snappy) { selectedCategorySliceId = nil }
        } else {
            selectedCategorySliceId = nil
        }
    }

    private func clearIncomeSplitSelectionOnly(animated: Bool = true) {
        guard incomeSplitSelectedSegment != nil else { return }
        if animated {
            withAnimation(AppAnimation.incomeSplitCallout) { incomeSplitSelectedSegment = nil }
        } else {
            incomeSplitSelectedSegment = nil
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

    private func currentPieSlices() -> [CategoryPieSliceModel] {
        let expenses = viewModel.totalExpenses
        let savings = viewModel.goalAllocations
        let grandTotal = expenses + savings
        guard grandTotal > 0 else { return [] }
        let sorted = viewModel.categoryBreakdown.sorted { $0.value > $1.value }
        let pairs = sorted.map { ($0.key, $0.value) }
        return combinedPieSlices(categoryPairs: pairs, savings: savings, grandTotal: grandTotal)
    }

    private func scheduleStaggeredPieFill(slices: [CategoryPieSliceModel]) {
        guard !slices.isEmpty else {
            pieSliceProgress = []
            return
        }
        pieAnimationToken += 1
        let token = pieAnimationToken
        let count = slices.count
        pieSliceProgress = Array(repeating: 0, count: count)
        let order = slices.indices.sorted { slices[$0].percent > slices[$1].percent }
        let lead = AppAnimation.analyticsPieLeadDelay
        let stagger = AppAnimation.analyticsPieStagger
        let sweepDuration = AppAnimation.analyticsPieSliceSweepDuration
        for (seq, sliceIdx) in order.enumerated() {
            let delay = lead + Double(seq) * stagger
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard token == pieAnimationToken else { return }
                guard sliceIdx < pieSliceProgress.count else { return }
                withAnimation(.easeOut(duration: sweepDuration)) {
                    var next = pieSliceProgress
                    next[sliceIdx] = 1
                    pieSliceProgress = next
                }
            }
        }
    }

    private func scheduleIncomeSplitBarReveal() {
        incomeSplitBarReveal = 0
        DispatchQueue.main.async {
            withAnimation(AppAnimation.incomeSplitSegmentReveal) {
                incomeSplitBarReveal = 1
            }
        }
    }

    // MARK: - Trend strip (vs last month only — no raw amounts duplicated from Dashboard)

    private var analyticsTrendStrip: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            AnalyticsTrendOnlyCard(
                title: L10n("dashboard.income"),
                trend: viewModel.incomeTrend,
                percentSemantics: .higherIsBetter,
                emptyCaption: viewModel.monthlyIncome < analyticsTrendMetricZeroEpsilon
                    ? L10n("analytics.trend.empty_income")
                    : nil
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { dismissAnalyticsSelections() }
            .opacity(trendStripAppeared ? 1 : 0)
            .animation(AppAnimation.quickUI.delay(0), value: trendStripAppeared)
            AnalyticsTrendOnlyCard(
                title: L10n("dashboard.expenses"),
                trend: viewModel.expensesTrend,
                percentSemantics: .higherIsWorse,
                emptyCaption: viewModel.totalExpenses < analyticsTrendMetricZeroEpsilon
                    ? L10n("analytics.trend.empty_expenses")
                    : nil
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { dismissAnalyticsSelections() }
            .opacity(trendStripAppeared ? 1 : 0)
            .animation(AppAnimation.quickUI.delay(0.05), value: trendStripAppeared)
            AnalyticsTrendOnlyCard(
                title: L10n("analytics.pie.savings"),
                trend: viewModel.savingsTrend,
                percentSemantics: .higherIsBetter,
                favorableTrendColor: AppColorTheme.savingsIndicator,
                emptyCaption: viewModel.goalAllocations < analyticsTrendMetricZeroEpsilon
                    ? L10n("analytics.trend.empty_savings")
                    : nil
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { dismissAnalyticsSelections() }
            .opacity(trendStripAppeared ? 1 : 0)
            .animation(AppAnimation.quickUI.delay(0.1), value: trendStripAppeared)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 72)
        .padding(.bottom, AppSpacing.s)
    }

    private var savingsRateCaption: some View {
        Group {
            if viewModel.monthlyIncome > 0 {
                let rate = min(100, max(0, viewModel.goalAllocations / viewModel.monthlyIncome * 100))
                Text(String(format: L10n("analytics.savings_rate_caption"), Int(round(rate))))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissAnalyticsSelections() }
            }
        }
    }

    // Hero: pie = expenses by category + allocated savings slice when > 0; tap for detail readout.

    private var primaryCategorySpendingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            let expenses = viewModel.totalExpenses
            let savings = viewModel.goalAllocations
            let grandTotal = expenses + savings
            if grandTotal <= 0 {
                EmptyStateView(
                    icon: "chart.pie",
                    message: L10n("analytics.no_data"),
                    compact: true
                )
                .padding(.vertical, AppSpacing.s)
                .frame(minHeight: 320, maxHeight: 320)
                .frame(maxWidth: .infinity)
            } else {
                let sorted = viewModel.categoryBreakdown.sorted { $0.value > $1.value }
                let pairs = sorted.map { ($0.key, $0.value) }
                let slices = combinedPieSlices(categoryPairs: pairs, savings: savings, grandTotal: grandTotal)
                let legendItems = combinedLegendItems(from: pairs, savings: savings, grandTotal: grandTotal)
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 0) {
                        categorySpendingHero(
                            grandTotal: grandTotal,
                            slices: slices,
                            legendItems: legendItems,
                            selectedSliceId: $selectedCategorySliceId,
                            onSliceSelectionCommitted: { clearIncomeSplitSelectionOnly() }
                        )
                        // Same horizontal inset as `EmptyStateView(compact:)` inside the card; vertical layout on phones avoids overflow.
                        .padding(.horizontal, AppSpacing.m)
                        .opacity(chartAnimated ? 1 : 0)
                        .scaleEffect(chartAnimated ? 1 : 0.97)
                        .animation(AppAnimation.analyticsHeroReveal, value: chartAnimated)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L10n("dashboard.spending_by_category"))

                    AnalyticsIncomeSplitSection(
                        selectedSegment: $incomeSplitSelectedSegment,
                        barRevealProgress: $incomeSplitBarReveal,
                        currencyCode: UserProfileService.shared.profile.currency,
                        monthlyIncome: viewModel.monthlyIncome,
                        expenses: expenses,
                        savings: savings,
                        remaining: viewModel.incomeSplitUnallocated,
                        showRemainingBar: viewModel.incomeSplitShowsRemainingBar,
                        segmentDenominator: viewModel.incomeSplitSegmentDenominator,
                        showOverflowHint: viewModel.incomeSplitShowsOverflowHint,
                        allocatedOutflows: viewModel.incomeSplitAllocatedOutflows,
                        dismissPieOnIncomeControlTap: { clearPieSelectionOnly() },
                        dismissSelectionsOnTapOutsideBar: { dismissAnalyticsSelections() },
                        dismissIncomeCalloutFromTooltipTap: { clearIncomeSplitSelectionOnly() }
                    )
                    .padding(.horizontal, AppSpacing.m)
                    .opacity(chartAnimated ? 1 : 0)
                    .animation(AppAnimation.analyticsHeroReveal, value: chartAnimated)

                    if let explainPrompt = explainPromptForSelectedSlice(legendItems: legendItems) {
                        Button {
                            pendingAIQuestion = explainPrompt
                            withAnimation(AppAnimation.sheetPresent) {
                                showAdviserView = true
                            }
                        } label: {
                            Text(L10n("analytics.ai.explain_category"))
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColorTheme.accent)
                                .padding(.horizontal, AppSpacing.s)
                                .padding(.vertical, AppSpacing.xs)
                                .frame(minHeight: 44)
                                .background(
                                    Capsule()
                                        .fill(AppColorTheme.accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppSpacing.m)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColorTheme.sapphire.opacity(0.45),
                                    AppColorTheme.accent.opacity(0.25),
                                    AppColorTheme.sapphire.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: AppColorTheme.sapphire.opacity(0.12), radius: 24, x: 0, y: 12)
        )
    }

    private func combinedLegendItems(
        from pairs: [(CategoryDisplayInfo, Double)],
        savings: Double,
        grandTotal: Double
    ) -> [CategoryLegendItem] {
        var rows: [CategoryLegendItem] = pairs.map { info, value in
            let pct = grandTotal > 0 ? Int(round(100.0 * value / grandTotal)) : 0
            return CategoryLegendItem(
                id: info.id,
                title: info.name,
                icon: info.icon,
                amount: value,
                percent: pct,
                color: categoryColor(info)
            )
        }
        if savings > 0 {
            let pct = grandTotal > 0 ? Int(round(100.0 * savings / grandTotal)) : 0
            rows.append(CategoryLegendItem(
                id: "analytics_savings_slice",
                title: L10n("analytics.pie.savings"),
                icon: "🎯",
                amount: savings,
                percent: pct,
                color: AppColorTheme.savingsIndicator
            ))
        }
        return rows
    }

    @ViewBuilder
    private func categorySpendingHero(
        grandTotal: Double,
        slices: [CategoryPieSliceModel],
        legendItems: [CategoryLegendItem],
        selectedSliceId: Binding<String?>,
        onSliceSelectionCommitted: @escaping () -> Void
    ) -> some View {
        let currency = UserProfileService.shared.profile.currency
        // ScrollView proposes infinite width, so `ViewThatFits` would always pick the wide HStack and overflow on phones.
        let useVerticalPieLayout = horizontalSizeClass == .compact
        categorySpendingHeroColumn(
            grandTotal: grandTotal,
            currency: currency,
            slices: slices,
            legendItems: legendItems,
            selectedSliceId: selectedSliceId,
            vertical: useVerticalPieLayout,
            onSliceSelectionCommitted: onSliceSelectionCommitted
        )
        .frame(minHeight: useVerticalPieLayout ? 300 : 248)
    }

    @ViewBuilder
    private func categorySpendingHeroColumn(
        grandTotal: Double,
        currency: String,
        slices: [CategoryPieSliceModel],
        legendItems: [CategoryLegendItem],
        selectedSliceId: Binding<String?>,
        vertical: Bool,
        onSliceSelectionCommitted: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n("dashboard.spending_by_category"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColorTheme.textTertiary)
                    .tracking(1.2)
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(CurrencyFormatter.format(grandTotal, currencyCode: currency))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColorTheme.textPrimary, AppColorTheme.iceBlue.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(L10n("analytics.pie_hero_period"))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .contentShape(Rectangle())
            .onTapGesture { dismissAnalyticsSelections() }

            if vertical {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AnalyticsPieSelectionDetailPanel(
                        legendItems: legendItems,
                        currencyCode: currency,
                        selectedSliceId: selectedSliceId,
                        onDismiss: { dismissAnalyticsSelections() }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    GeometryReader { geo in
                        ZStack {
                            Color.clear
                                .contentShape(Rectangle())
                                .frame(width: geo.size.width, height: geo.size.height)
                                .onTapGesture { dismissAnalyticsSelections() }
                            let side = min(220, max(150, geo.size.width))
                            categoryPieBlock(
                                slices: slices,
                                sliceProgress: pieSliceProgress,
                                selectedSliceId: selectedSliceId,
                                diameter: side,
                                onSliceSelectionCommitted: onSliceSelectionCommitted
                            )
                            .frame(width: side, height: side)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(height: 248)
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.m) {
                    AnalyticsPieSelectionDetailPanel(
                        legendItems: legendItems,
                        currencyCode: currency,
                        selectedSliceId: selectedSliceId,
                        onDismiss: { dismissAnalyticsSelections() }
                    )
                    .frame(width: 118, alignment: .leading)
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { dismissAnalyticsSelections() }
                        HStack {
                            Spacer(minLength: 0)
                            categoryPieBlock(
                                slices: slices,
                                sliceProgress: pieSliceProgress,
                                selectedSliceId: selectedSliceId,
                                diameter: 220,
                                onSliceSelectionCommitted: onSliceSelectionCommitted
                            )
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func categoryPieBlock(
        slices: [CategoryPieSliceModel],
        sliceProgress: [CGFloat],
        selectedSliceId: Binding<String?>,
        diameter: CGFloat = 220,
        onSliceSelectionCommitted: @escaping () -> Void = {}
    ) -> some View {
        let scale = diameter / 220
        let inner = diameter * (196 / 220)
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppColorTheme.sapphire.opacity(0.35),
                            AppColorTheme.accent.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20 * scale,
                        endRadius: 130 * scale
                    )
                )
                .frame(width: diameter, height: diameter)
                .blur(radius: 18 * scale)
                .opacity(0.9)
            CategorySpendingPieChart(
                slices: slices,
                sliceProgress: sliceProgress,
                selectedSliceId: selectedSliceId,
                onSliceSelectionCommitted: onSliceSelectionCommitted
            )
            .frame(width: inner, height: inner)
            .shadow(color: Color.black.opacity(0.35), radius: 16 * scale, x: 0, y: 8 * scale)
        }
        .frame(width: diameter, height: diameter)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        Group {
            if !viewModel.insights.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppColorTheme.goldAccent)
                        Text(L10n("analytics.insights_title"))
                            .font(AppTypography.cardTitle)
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
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColorTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(AppSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { dismissAnalyticsSelections() }
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

    /// Pie = expense categories (by amount) + optional savings slice; angles use `grandTotal` (expenses + savings).
    private func combinedPieSlices(
        categoryPairs: [(CategoryDisplayInfo, Double)],
        savings: Double,
        grandTotal: Double
    ) -> [CategoryPieSliceModel] {
        guard grandTotal > 0 else { return [] }
        var start = -90.0
        var out: [CategoryPieSliceModel] = []
        for (info, value) in categoryPairs {
            guard value > 0 else { continue }
            let sweep = 360.0 * value / grandTotal
            let pct = Int(round(100.0 * value / grandTotal))
            out.append(CategoryPieSliceModel(
                id: info.id,
                startDegrees: start,
                endDegrees: start + sweep,
                color: categoryColor(info),
                percent: pct
            ))
            start += sweep
        }
        if savings > 0 {
            let sweep = 360.0 * savings / grandTotal
            let pct = Int(round(100.0 * savings / grandTotal))
            out.append(CategoryPieSliceModel(
                id: "analytics_savings_slice",
                startDegrees: start,
                endDegrees: start + sweep,
                color: AppColorTheme.savingsIndicator,
                percent: pct
            ))
        }
        return out
    }

    private func categoryColor(_ categoryInfo: CategoryDisplayInfo) -> Color {
        categoryInfo.chartTintColor
    }
    
    private func explainPromptForSelectedSlice(legendItems: [CategoryLegendItem]) -> String? {
        guard let selectedCategorySliceId else { return nil }
        guard selectedCategorySliceId != "analytics_savings_slice" else { return nil }
        guard let selectedItem = legendItems.first(where: { $0.id == selectedCategorySliceId }) else { return nil }
        return String(format: L10n("analytics.ai.explain_category_prompt"), selectedItem.title)
    }

}

// MARK: - Income split (below pie, same card)

/// iOS Storage–style capsule: summary line, tappable segments with callout, compact legend (amounts on tap only).
private struct AnalyticsIncomeSplitSection: View {
    @Binding var selectedSegment: IncomeSplitSegmentKind?
    @Binding var barRevealProgress: CGFloat
    let currencyCode: String
    let monthlyIncome: Double
    let expenses: Double
    let savings: Double
    let remaining: Double
    let showRemainingBar: Bool
    let segmentDenominator: Double
    let showOverflowHint: Bool
    let allocatedOutflows: Double
    let dismissPieOnIncomeControlTap: () -> Void
    let dismissSelectionsOnTapOutsideBar: () -> Void
    let dismissIncomeCalloutFromTooltipTap: () -> Void

    private var incomeFormatted: String {
        CurrencyFormatter.format(monthlyIncome, currencyCode: currencyCode)
    }

    private var allocatedFormatted: String {
        CurrencyFormatter.format(allocatedOutflows, currencyCode: currencyCode)
    }

    private var denomCGFloat: CGFloat {
        CGFloat(max(segmentDenominator, analyticsTrendMetricZeroEpsilon))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Divider()
                    .background(AppColorTheme.cardBorder.opacity(0.85))
                    .padding(.bottom, AppSpacing.xs)

                if showRemainingBar {
                    Text(String(format: L10n("analytics.income_split.summary_spent_of_income"), allocatedFormatted, incomeFormatted))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColorTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel(
                            String(format: L10n("analytics.income_split.summary_spent_of_income"), allocatedFormatted, incomeFormatted)
                        )
                } else {
                    Text(String(format: L10n("analytics.income_split.summary_allocated_only"), allocatedFormatted))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColorTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }

                if !showRemainingBar {
                    Text(L10n("analytics.income_split.no_income_hint"))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { dismissSelectionsOnTapOutsideBar() }

            IncomeSplitSegmentedBar(
                totalWidthReveal: barRevealProgress,
                selectedSegment: $selectedSegment,
                expenses: expenses,
                savings: savings,
                remaining: remaining,
                showRemaining: showRemainingBar,
                denominator: denomCGFloat,
                expenseColor: AppColorTheme.expenseIndicator,
                savingsColor: AppColorTheme.savingsIndicator,
                remainingColor: AppColorTheme.sapphire,
                expenseLabel: L10n("analytics.pie.expenses"),
                savingsLabel: L10n("analytics.pie.savings"),
                remainingLabel: L10n("analytics.pie.remaining"),
                currencyCode: currencyCode,
                dismissPieOnIncomeControlTap: dismissPieOnIncomeControlTap
            )
            .accessibilityElement(children: .contain)
            .accessibilityHint(incomeSplitBarAccessibilitySummary())
            .overlay(alignment: .top) {
                IncomeSplitSegmentCallout(
                    selection: selectedSegment,
                    expenses: expenses,
                    savings: savings,
                    remaining: remaining,
                    expenseTitle: L10n("analytics.pie.expenses"),
                    savingsTitle: L10n("analytics.pie.savings"),
                    remainingTitle: L10n("analytics.pie.remaining"),
                    currencyCode: currencyCode,
                    onTapDismiss: dismissIncomeCalloutFromTooltipTap
                )
                .animation(AppAnimation.incomeSplitCallout, value: selectedSegment)
                .offset(y: -incomeSplitCalloutAboveBarOffset)
            }
            // Matches previous `VStack(spacing: 10)` top inset when the callout had zero height.
            .padding(.top, 10)

            if showOverflowHint {
                Text(L10n("analytics.income_split.overflow_hint"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppColorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissSelectionsOnTapOutsideBar() }
            }

            HStack(alignment: .center, spacing: 8) {
                incomeSplitLegendChip(
                    kind: .expenses,
                    color: AppColorTheme.expenseIndicator,
                    title: L10n("analytics.pie.expenses"),
                    amount: expenses
                )
                incomeSplitLegendChip(
                    kind: .savings,
                    color: AppColorTheme.savingsIndicator,
                    title: L10n("analytics.pie.savings"),
                    amount: savings
                )
                if showRemainingBar {
                    incomeSplitLegendChip(
                        kind: .remaining,
                        color: AppColorTheme.sapphire,
                        title: L10n("analytics.pie.remaining"),
                        amount: remaining
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }

    private func incomeSplitBarAccessibilitySummary() -> String {
        let e = CurrencyFormatter.format(expenses, currencyCode: currencyCode)
        let s = CurrencyFormatter.format(savings, currencyCode: currencyCode)
        let r = CurrencyFormatter.format(remaining, currencyCode: currencyCode)
        let inc = incomeFormatted
        if showRemainingBar {
            return String(format: L10n("analytics.income_split.a11y.segmented_summary"), e, s, r, inc)
        }
        return String(format: L10n("analytics.income_split.a11y.segmented_summary_no_remaining"), e, s)
    }

    private func incomeSplitLegendChip(kind: IncomeSplitSegmentKind, color: Color, title: String, amount: Double) -> some View {
        let formatted = CurrencyFormatter.format(amount, currencyCode: currencyCode)
        let isOn = selectedSegment == kind
        return Button {
            HapticHelper.lightImpact()
            dismissPieOnIncomeControlTap()
            withAnimation(AppAnimation.incomeSplitCallout) {
                selectedSegment = selectedSegment == kind ? nil : kind
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Color.white.opacity(isOn ? 0.35 : 0.12), lineWidth: isOn ? 1.5 : 1))
                Text(title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isOn ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? AppColorTheme.layer3Elevated.opacity(0.55) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: L10n("analytics.income_split.a11y.bar_label"), title, formatted))
    }
}

/// Minimal callout above the capsule: **Name · amount** (currency in formatted string).
private struct IncomeSplitSegmentCallout: View {
    let selection: IncomeSplitSegmentKind?
    let expenses: Double
    let savings: Double
    let remaining: Double
    let expenseTitle: String
    let savingsTitle: String
    let remainingTitle: String
    let currencyCode: String
    let onTapDismiss: () -> Void

    var body: some View {
        Group {
            if let sel = selection {
                let titleAmount: (String, Double) = {
                    switch sel {
                    case .expenses: return (expenseTitle, expenses)
                    case .savings: return (savingsTitle, savings)
                    case .remaining: return (remainingTitle, remaining)
                    }
                }()
                let formatted = CurrencyFormatter.format(titleAmount.1, currencyCode: currencyCode)
                Text("\(titleAmount.0) · \(formatted)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColorTheme.grayDark.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 5)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture {
                        HapticHelper.lightImpact()
                        onTapDismiss()
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)).combined(with: .offset(y: 6)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
                        )
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private let incomeSplitBarTrackHeight: CGFloat = 22
/// Vertical lift for the segment tooltip so it sits above the capsule without participating in layout (avoids pushing the bar down).
private let incomeSplitCalloutAboveBarOffset: CGFloat = 52

/// Storage-style segmented capsule with hairline dividers; tap toggles selection (shows callout).
private struct IncomeSplitSegmentedBar: View {
    let totalWidthReveal: CGFloat
    @Binding var selectedSegment: IncomeSplitSegmentKind?
    let expenses: Double
    let savings: Double
    let remaining: Double
    let showRemaining: Bool
    let denominator: CGFloat
    let expenseColor: Color
    let savingsColor: Color
    let remainingColor: Color
    let expenseLabel: String
    let savingsLabel: String
    let remainingLabel: String
    let currencyCode: String
    let dismissPieOnIncomeControlTap: () -> Void

    private var eps: Double { analyticsTrendMetricZeroEpsilon }

    var body: some View {
        GeometryReader { geo in
            let track = geo.size.width
            let scale = max(denominator, CGFloat(eps))
            let fE = CGFloat(expenses) / scale
            let fS = CGFloat(savings) / scale
            let fR = showRemaining ? CGFloat(remaining) / scale : 0
            let wE = max(0, track * fE * totalWidthReveal)
            let wS = max(0, track * fS * totalWidthReveal)
            let wR = max(0, track * fR * totalWidthReveal)
            let hasE = expenses > eps
            let hasS = savings > eps
            let hasR = showRemaining && remaining > eps
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColorTheme.chartBarBackground.opacity(0.72))
                HStack(spacing: 0) {
                    if hasE {
                        segmentCell(
                            width: wE,
                            colors: [expenseColor, expenseColor.opacity(0.82)],
                            kind: .expenses,
                            label: expenseLabel,
                            amount: expenses,
                            showTrailingDivider: hasS || hasR,
                            dismissPieOnIncomeControlTap: dismissPieOnIncomeControlTap
                        )
                    }
                    if hasS {
                        segmentCell(
                            width: wS,
                            colors: [savingsColor, savingsColor.opacity(0.82)],
                            kind: .savings,
                            label: savingsLabel,
                            amount: savings,
                            showTrailingDivider: hasR,
                            dismissPieOnIncomeControlTap: dismissPieOnIncomeControlTap
                        )
                    }
                    if hasR {
                        segmentCell(
                            width: wR,
                            colors: [remainingColor, remainingColor.opacity(0.82)],
                            kind: .remaining,
                            label: remainingLabel,
                            amount: remaining,
                            showTrailingDivider: false,
                            dismissPieOnIncomeControlTap: dismissPieOnIncomeControlTap
                        )
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: incomeSplitBarTrackHeight)
        }
        .frame(height: incomeSplitBarTrackHeight)
    }

    private func segmentCell(
        width: CGFloat,
        colors: [Color],
        kind: IncomeSplitSegmentKind,
        label: String,
        amount: Double,
        showTrailingDivider: Bool,
        dismissPieOnIncomeControlTap: @escaping () -> Void
    ) -> some View {
        let formatted = CurrencyFormatter.format(amount, currencyCode: currencyCode)
        let isSelected = selectedSegment == kind
        return Button {
            HapticHelper.selection()
            dismissPieOnIncomeControlTap()
            withAnimation(AppAnimation.incomeSplitCallout) {
                selectedSegment = selectedSegment == kind ? nil : kind
            }
        } label: {
            ZStack(alignment: .trailing) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(isSelected ? 0.12 : 0))
                    )
                if showTrailingDivider {
                    Rectangle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }
            }
            .frame(width: max(0, width))
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: L10n("analytics.income_split.a11y.bar_label"), label, formatted))
    }
}

// MARK: - Pie selection detail (Analytics hero)

private struct AnalyticsPieSelectionDetailPanel: View {
    let legendItems: [CategoryLegendItem]
    let currencyCode: String
    @Binding var selectedSliceId: String?
    let onDismiss: () -> Void

    private var selectedItem: CategoryLegendItem? {
        guard let id = selectedSliceId else { return nil }
        return legendItems.first { $0.id == id }
    }

    var body: some View {
        Group {
            if let item = selectedItem {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [item.color, item.color.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(item.title)
                                .foregroundColor(AppColorTheme.textPrimary)
                            Text("-")
                                .foregroundColor(AppColorTheme.textTertiary)
                            Text("\(item.percent)%")
                                .foregroundColor(item.color)
                        }
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(CurrencyFormatter.format(item.amount, currencyCode: currencyCode))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                .padding(AppSpacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .fill(AppColorTheme.layer3Elevated.opacity(0.78))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.button)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .leading)))
                .id(item.id)
            } else {
                Text(L10n("analytics.pie_tap_hint"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .animation(AppAnimation.standard, value: selectedSliceId)
    }
}

private enum AnalyticsSpendingPieHitTest {
    static func sliceId(at location: CGPoint, in size: CGSize, slices: [CategoryPieSliceModel]) -> String? {
        guard !slices.isEmpty else { return nil }
        let cx = Double(size.width / 2)
        let cy = Double(size.height / 2)
        let dx = Double(location.x) - cx
        let dy = Double(location.y) - cy
        let rPie = Double(min(size.width, size.height) / 2)
        let dist = hypot(dx, dy)
        if dist > rPie { return nil }
        if dist < 14 { return nil }

        if slices.count == 1, let only = slices.first {
            let span = only.endDegrees - only.startDegrees
            if abs(abs(span) - 360) < 1 || abs(span) > 359 { return only.id }
        }

        let touchNorm = (atan2(dx, -dy) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        for s in slices {
            let startNorm = (s.startDegrees + 90 + 3600).truncatingRemainder(dividingBy: 360)
            let endNorm = (s.endDegrees + 90 + 3600).truncatingRemainder(dividingBy: 360)
            let span = abs(s.endDegrees - s.startDegrees)
            if span >= 359.5 { return s.id }
            if endNorm > startNorm {
                if touchNorm >= startNorm && touchNorm < endNorm { return s.id }
            } else if endNorm < startNorm {
                if touchNorm >= startNorm || touchNorm < endNorm { return s.id }
            }
        }
        return nil
    }
}

// MARK: - Category pie metadata (detail panel)

private struct CategoryLegendItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let amount: Double
    let percent: Int
    let color: Color
}

// MARK: - Category pie (Analytics)

private struct CategoryPieSliceModel: Identifiable {
    let id: String
    let startDegrees: Double
    let endDegrees: Double
    let color: Color
    /// Rounded share of grand total (expenses + savings); shown on-slice when large enough.
    let percent: Int
}

private struct CategorySpendingPieChart: View {
    let slices: [CategoryPieSliceModel]
    let sliceProgress: [CGFloat]
    @Binding var selectedSliceId: String?
    let onSliceSelectionCommitted: () -> Void
    /// Omit labels on hairline slices to avoid overlap (hidden entirely while a slice is selected).
    private var minPercentToShowLabel: Int { 6 }

    private var hasSelection: Bool { selectedSliceId != nil }

    private var allSlicesFullyRevealed: Bool {
        guard slices.count == sliceProgress.count, !slices.isEmpty else { return false }
        return sliceProgress.allSatisfy { $0 >= 0.98 }
    }

    private func progress(forIndex index: Int) -> CGFloat {
        guard sliceProgress.indices.contains(index) else { return 0 }
        return sliceProgress[index]
    }

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            ZStack {
                if slices.isEmpty {
                    Circle()
                        .stroke(AppColorTheme.chartBarBackground, lineWidth: 18)
                    Text("—")
                        .font(.title2)
                        .foregroundColor(AppColorTheme.textTertiary)
                        .position(x: cx, y: cy)
                } else {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                        let isSelected = selectedSliceId == slice.id
                        let dimOthers = hasSelection && !isSelected
                        PieSliceShape(
                            startAngle: .degrees(slice.startDegrees),
                            endAngle: .degrees(slice.endDegrees),
                            progress: progress(forIndex: index)
                        )
                        .fill(slice.color)
                        .saturation(dimOthers ? 0.32 : 1)
                        .opacity(dimOthers ? 0.42 : 1)
                        .scaleEffect(isSelected ? 1.06 : 1, anchor: .center)
                        .animation(AppAnimation.snappy, value: selectedSliceId)
                    }
                    if !hasSelection, allSlicesFullyRevealed {
                        ForEach(slices) { slice in
                            if slice.percent >= minPercentToShowLabel {
                                let midDeg = (slice.startDegrees + slice.endDegrees) / 2
                                let rad = (midDeg + 90) * .pi / 180
                                let labelR = Double(r) * 0.52
                                let ox = CGFloat(sin(rad) * labelR)
                                let oy = CGFloat(-cos(rad) * labelR)
                                Text("\(slice.percent)%")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColorTheme.textPrimary)
                                    .shadow(color: Color.black.opacity(0.65), radius: 2, x: 0, y: 1)
                                    .shadow(color: slice.color.opacity(0.4), radius: 6, x: 0, y: 0)
                                    .position(x: cx + ox, y: cy + oy)
                            }
                        }
                    }
                    Color.clear
                        .contentShape(Circle())
                        .frame(width: geo.size.width, height: geo.size.height)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    let loc = value.location
                                    guard let hit = AnalyticsSpendingPieHitTest.sliceId(at: loc, in: geo.size, slices: slices) else { return }
                                    let prev = selectedSliceId
                                    let next: String? = (prev == hit) ? nil : hit
                                    guard prev != next else { return }
                                    HapticHelper.selection()
                                    onSliceSelectionCommitted()
                                    withAnimation(AppAnimation.snappy) {
                                        selectedSliceId = next
                                    }
                                }
                        )
                }
            }
        }
    }
}

private struct PieSliceShape: Shape {
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

// MARK: - Trend-only card (percent change vs last month; no raw currency totals)

/// Whether a positive percent change is “good” (green) or “bad” (red) for this metric.
enum AnalyticsTrendPercentSemantics {
    case higherIsBetter
    case higherIsWorse
}

struct AnalyticsTrendOnlyCard: View {
    let title: String
    let trend: KPITrend
    var percentSemantics: AnalyticsTrendPercentSemantics = .higherIsBetter
    /// “Good” direction tint (e.g. savings uses `savingsIndicator` vs income emerald).
    var favorableTrendColor: Color = AppColorTheme.incomeIndicator
    /// When set, hides MoM % (no misleading −100%) and shows calm placeholder copy for this metric.
    var emptyCaption: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppColorTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            if let caption = emptyCaption {
                Text("—")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(AppColorTheme.textTertiary.opacity(0.9))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                Text(caption)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppColorTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    if trend.direction != .neutral {
                        Image(systemName: trend.direction == .up ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(percentForeground)
                    }
                    if let pct = trend.percentChange {
                        Text(formatPercentSigned(pct))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(percentForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    } else if trend.direction == .neutral {
                        Text("0%")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColorTheme.textTertiary)
                    } else {
                        Text("—")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColorTheme.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity)

                Text(L10n("analytics.vs_last_month"))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppColorTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.button)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.button)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: AppColorTheme.sapphire.opacity(0.12), radius: 24, x: 0, y: 12)
        )
        .accessibilityElement(children: .combine)
    }

    private var percentForeground: Color {
        if let pct = trend.percentChange {
            return percentColor(pct)
        }
        if trend.direction == .neutral {
            return AppColorTheme.textTertiary
        }
        return AppColorTheme.textTertiary
    }

    private func percentColor(_ value: Double) -> Color {
        let good = favorableTrendColor
        let bad = AppColorTheme.expenseIndicator
        switch percentSemantics {
        case .higherIsBetter:
            return value >= 0 ? good : bad
        case .higherIsWorse:
            return value >= 0 ? bad : good
        }
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
