//
//  AnalyticsView.swift
//  Friscora
//
//  Analytics tab: period control, one primary spending chart, category detail, insights
//

import SwiftUI

struct AnalyticsView: View {
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
            }
            .onChange(of: viewModel.selectedMonth) { _, newMonth in
                HapticHelper.lightImpact()
                FeedbackService.shared.setLastAnalyticsMonth(newMonth)
                viewModel.updateData()
                selectedCategorySliceId = nil
                chartAnimated = false
                let slices = currentPieSlices()
                pieSliceProgress = Array(repeating: 0, count: slices.count)
                withAnimation(AppAnimation.analyticsHeroReveal) { chartAnimated = true }
                scheduleStaggeredPieFill(slices: slices)
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

    // MARK: - Trend strip (vs last month only — no raw amounts duplicated from Dashboard)

    private var analyticsTrendStrip: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            AnalyticsTrendOnlyCard(
                title: L10n("dashboard.income"),
                trend: viewModel.incomeTrend
            )
            .frame(maxWidth: .infinity)
            .opacity(trendStripAppeared ? 1 : 0)
            .animation(AppAnimation.quickUI.delay(0), value: trendStripAppeared)
            AnalyticsTrendOnlyCard(
                title: L10n("dashboard.expenses"),
                trend: viewModel.expensesTrend
            )
            .frame(maxWidth: .infinity)
            .opacity(trendStripAppeared ? 1 : 0)
            .animation(AppAnimation.quickUI.delay(0.05), value: trendStripAppeared)
            AnalyticsTrendOnlyCard(
                title: L10n("dashboard.allocated_savings"),
                trend: viewModel.savingsTrend
            )
            .frame(maxWidth: .infinity)
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
                categorySpendingHero(
                    grandTotal: grandTotal,
                    slices: slices,
                    legendItems: legendItems,
                    selectedSliceId: $selectedCategorySliceId
                )
                // Same horizontal inset as `EmptyStateView(compact:)` inside the card; vertical layout on phones avoids overflow.
                .padding(.horizontal, AppSpacing.m)
                .opacity(chartAnimated ? 1 : 0)
                .scaleEffect(chartAnimated ? 1 : 0.97)
                .animation(AppAnimation.analyticsHeroReveal, value: chartAnimated)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n("dashboard.spending_by_category"))
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
                title: L10n("dashboard.allocated_savings"),
                icon: "🎯",
                amount: savings,
                percent: pct,
                color: AppColorTheme.accent
            ))
        }
        return rows
    }

    @ViewBuilder
    private func categorySpendingHero(
        grandTotal: Double,
        slices: [CategoryPieSliceModel],
        legendItems: [CategoryLegendItem],
        selectedSliceId: Binding<String?>
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
            vertical: useVerticalPieLayout
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
        vertical: Bool
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

            if vertical {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AnalyticsPieSelectionDetailPanel(
                        legendItems: legendItems,
                        currencyCode: currency,
                        selectedSliceId: selectedSliceId
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    GeometryReader { geo in
                        let side = min(220, max(150, geo.size.width))
                        categoryPieBlock(
                            slices: slices,
                            sliceProgress: pieSliceProgress,
                            selectedSliceId: selectedSliceId,
                            diameter: side
                        )
                        .frame(width: side, height: side)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 248)
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.m) {
                    AnalyticsPieSelectionDetailPanel(
                        legendItems: legendItems,
                        currencyCode: currency,
                        selectedSliceId: selectedSliceId
                    )
                    .frame(width: 118, alignment: .leading)
                    categoryPieBlock(
                        slices: slices,
                        sliceProgress: pieSliceProgress,
                        selectedSliceId: selectedSliceId,
                        diameter: 220
                    )
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func categoryPieBlock(
        slices: [CategoryPieSliceModel],
        sliceProgress: [CGFloat],
        selectedSliceId: Binding<String?>,
        diameter: CGFloat = 220
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
                selectedSliceId: selectedSliceId
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
                color: AppColorTheme.accent,
                percent: pct
            ))
        }
        return out
    }

    private func categoryColor(_ categoryInfo: CategoryDisplayInfo) -> Color {
        if categoryInfo.isCustom {
            return AppColorTheme.chartBarFill
        }
        if categoryInfo.id.hasPrefix("standard_") {
            let raw = String(categoryInfo.id.dropFirst("standard_".count))
            if let category = ExpenseCategory(rawValue: raw) {
                return AppColorTheme.color(for: category)
            }
        }
        return AppColorTheme.chartBarFill
    }

}

// MARK: - Pie selection detail (Analytics hero)

private struct AnalyticsPieSelectionDetailPanel: View {
    let legendItems: [CategoryLegendItem]
    let currencyCode: String
    @Binding var selectedSliceId: String?

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

struct AnalyticsTrendOnlyCard: View {
    let title: String
    let trend: KPITrend

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            HStack(spacing: 2) {
                if trend.direction != .neutral {
                    Image(systemName: trend.direction == .up ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                if let pct = trend.percentChange {
                    Text(formatPercentSigned(pct))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(percentColor(pct))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                } else if trend.direction == .neutral {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                }
            }
            Text(L10n("analytics.vs_last_month"))
                .font(.system(size: 8))
                .foregroundColor(AppColorTheme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(AppSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColorTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: AppColorTheme.sapphire.opacity(0.12), radius: 24, x: 0, y: 12)
        )
    }

    private func percentColor(_ value: Double) -> Color {
        value >= 0 ? AppColorTheme.incomeIndicator : AppColorTheme.expenseIndicator
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
