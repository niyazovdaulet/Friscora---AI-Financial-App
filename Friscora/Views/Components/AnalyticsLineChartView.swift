//
//  AnalyticsLineChartView.swift
//  Friscora
//
//  Revolut-style premium fintech line chart: minimal when idle, informative on touch.
//  Single smooth line, tap-and-drag with vertical indicator and value overlay.
//

import SwiftUI
import Charts

// MARK: - Reusable analytics line chart (single month, 4 weeks)

struct AnalyticsLineChartView: View {
    /// Aggregated weekly data (exactly 4 points: weekIndex 0–3, label, value, income, expenses).
    let data: [WeekData]
    /// Formats the value for overlay (e.g. currency).
    let valueFormatter: (Decimal) -> String
    /// Optional accessibility label prefix, e.g. "Net balance".
    var valueKindLabel: String = "Value"
    /// Y-axis top label (e.g. monthly income). When set, Y-axis shows 0 at bottom and this at top.
    var yAxisMax: Double?
    /// Compact formatter for Y-axis labels (e.g. "844.2k KZT"). If nil, uses valueFormatter.
    var yAxisLabelFormatter: ((Decimal) -> String)?
    
    @State private var selectedWeek: WeekData?
    @State private var lineAppeared = false
    /// Drives "line drawing" animation: 0 = first point only, 1 = full line.
    @State private var lineDrawProgress: Double = 0
    
    private let chartHeight: CGFloat = 200
    private let indicatorLineWidth: CGFloat = 1.5
    
    var body: some View {
        if data.isEmpty {
            emptyState
        } else {
            chartWithOverlay
        }
    }
    
    private var emptyState: some View {
        Text(L10n("analytics.no_data"))
            .font(.subheadline)
            .foregroundColor(AppColorTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: chartHeight)
            .padding(.vertical, 24)
            .accessibilityLabel(L10n("analytics.no_data"))
    }
    
    private var chartWithOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            topValueOverlaySection
            chartSection
            customWeekLabelsRow
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight + 20)
        .onAppear { animateLineIn() }
        .onChange(of: data.first?.id) { _ in animateMonthChange() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityChartLabel)
        .accessibilityHint("Drag to explore weekly values")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }
    
    /// Custom row of 4 week labels so the fourth (Feb 22-28) is always visible; chart's built-in x-axis clips it.
    private var customWeekLabelsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(data.enumerated()), id: \.element.id) { _, week in
                Text(week.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColorTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 14)
    }
    
    @ViewBuilder
    private var topValueOverlaySection: some View {
        if let week = selectedWeek {
            valueOverlay(week: week)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(AppAnimation.lineChartInteraction, value: selectedWeek?.id)
                .zIndex(1)
        }
    }
    
    private var chartSection: some View {
        Group {
            if let maxVal = yAxisMax, maxVal > 0 {
                chartWithYAxis(maxValue: maxVal)
            } else {
                chartWithYAxisHidden
            }
        }
    }
    
    private var chartWithYAxisHidden: some View {
        lineChart
            .chartYScale(domain: yDomain)
            .chartXScale(domain: 0...3)
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .opacity(lineAppeared ? 1 : 0)
            .chartOverlay { proxy in GeometryReader { geometry in chartOverlayContent(proxy: proxy, geometry: geometry) } }
    }
    
    private func chartWithYAxis(maxValue: Double) -> some View {
        let yLabelFormatter = yAxisLabelFormatter ?? valueFormatter
        return lineChart
            .chartYScale(domain: yDomain)
            .chartXScale(domain: 0...3)
            .chartYAxis {
                AxisMarks(values: [0, maxValue]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(yLabelFormatter(Decimal(v)))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis(.hidden)
            .opacity(lineAppeared ? 1 : 0)
            .chartOverlay { proxy in GeometryReader { geometry in chartOverlayContent(proxy: proxy, geometry: geometry) } }
    }
    
    /// Data visible for "line drawing" effect: progress 0→1 reveals points left to right.
    private var displayedData: [WeekData] {
        let count = data.count
        guard count > 0 else { return [] }
        let n = max(1, min(count, Int(round(lineDrawProgress * Double(count)))))
        return Array(data.prefix(n))
    }
    
    private var lineChart: some View {
        Chart(displayedData) { point in
            let yValue = max(0, nsDecimalToDouble(point.value))
            LineMark(
                x: .value("Week", point.weekIndex),
                y: .value("Value", yValue)
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .foregroundStyle(AppColorTheme.incomeIndicator)
        }
        .animation(AppAnimation.lineChartDraw, value: lineDrawProgress)
    }
    
    private func chartOverlayContent(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        let plotFrame = geometry[proxy.plotAreaFrame]
        return ZStack(alignment: .topLeading) {
            dragGestureLayer(plotFrame: plotFrame, proxy: proxy, geometry: geometry)
            verticalIndicatorIfNeeded(plotFrame: plotFrame, proxy: proxy)
        }
    }
    
    private func dragGestureLayer(plotFrame: CGRect, proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(minWidth: 44, minHeight: 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(location: value.location, plotFrame: plotFrame, proxy: proxy, geometry: geometry)
                    }
                    .onEnded { _ in handleDragEnded() }
            )
    }
    
    @ViewBuilder
    private func verticalIndicatorIfNeeded(plotFrame: CGRect, proxy: ChartProxy) -> some View {
        if let week = selectedWeek,
           let xPosition = proxy.position(forX: week.weekIndex) {
            let lineX = plotFrame.minX + xPosition
            Rectangle()
                .fill(AppColorTheme.textTertiary.opacity(0.8))
                .frame(width: indicatorLineWidth, height: plotFrame.height)
                .position(x: lineX, y: plotFrame.midY)
                .animation(AppAnimation.lineChartInteraction, value: selectedWeek?.id)
        }
    }
    
    private func animateLineIn() {
        lineDrawProgress = 0
        withAnimation(AppAnimation.lineChartIndicator) {
            lineAppeared = true
        }
        withAnimation(AppAnimation.lineChartDraw) {
            lineDrawProgress = 1
        }
    }
    
    private func animateMonthChange() {
        withAnimation(AppAnimation.lineChartIndicator) {
            selectedWeek = nil
            lineAppeared = false
        }
        lineDrawProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(AppAnimation.lineChartIndicator) {
                lineAppeared = true
            }
            withAnimation(AppAnimation.lineChartDraw) {
                lineDrawProgress = 1
            }
        }
    }
    
    private func handleDragChanged(
        location: CGPoint,
        plotFrame: CGRect,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        // Convert gesture location to chart-relative X (plot area)
        let origin = geometry[proxy.plotAreaFrame].origin
        let relativeX = location.x - origin.x
        guard relativeX >= 0, relativeX <= plotFrame.width else {
            withAnimation(AppAnimation.lineChartIndicator) { selectedWeek = nil }
            return
        }
        // Map X position to data-space (continuous), then snap to nearest week index 0–3
        let xValue: Int? = proxy.value(atX: relativeX, as: Int.self)
            ?? proxy.value(atX: relativeX, as: Double.self).map { Int(round($0)) }
        let index = nearestWeekIndex(from: xValue)
        guard index >= 0, index < data.count else { return }
        withAnimation(AppAnimation.lineChartInteraction) {
            selectedWeek = data[index]
        }
    }
    
    private func handleDragEnded() {
        withAnimation(AppAnimation.lineChartIndicator) {
            selectedWeek = nil
        }
    }
    
    /// Snap to nearest week index 0–3 (no jumps).
    private func nearestWeekIndex(from value: Int?) -> Int {
        guard let v = value else { return 0 }
        return min(max(v, 0), data.count - 1)
    }
    
    private func valueOverlay(week: WeekData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(week.label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColorTheme.textSecondary)
            HStack(spacing: 12) {
                Label(valueFormatter(week.income), systemImage: "arrow.down.circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColorTheme.incomeIndicator)
                Label(valueFormatter(week.expenses), systemImage: "arrow.up.circle.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColorTheme.expenseIndicator)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColorTheme.layer3Elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                )
        )
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(week.label), Income \(valueFormatter(week.income)), Expense \(valueFormatter(week.expenses))")
    }
    
    /// Y domain: 0 at bottom (no negative – transactions can't be below zero), max at top. Small top padding so line doesn't touch axis.
    private var yDomain: ClosedRange<Double> {
        if let maxVal = yAxisMax, maxVal > 0 {
            let topPadding = maxVal * 0.04
            return 0...(maxVal + topPadding)
        }
        let values = data.map { nsDecimalToDouble($0.value) }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let padding = 0.15
        let span = max(maxVal - minVal, 1) * (1 + padding)
        let mid = (maxVal + minVal) / 2
        return (mid - span / 2)...(mid + span / 2)
    }
    
    private var accessibilityChartLabel: String {
        guard !data.isEmpty else { return L10n("analytics.no_data") }
        let parts = data.enumerated().map { index, week in
            "\(week.label), \(valueFormatter(week.value))"
        }
        return "\(valueKindLabel): " + parts.joined(separator: "; ")
    }
}

// MARK: - Helpers

private func nsDecimalToDouble(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
}
