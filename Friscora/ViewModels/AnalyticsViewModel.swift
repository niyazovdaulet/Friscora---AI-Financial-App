//
//  AnalyticsViewModel.swift
//  Friscora
//
//  ViewModel for Analytics tab. Structured for summary, breakdown, categories, and insights.
//

import Foundation
import Combine

// MARK: - Trend direction for KPIs
enum TrendDirection {
    case up
    case down
    case neutral
}

// MARK: - KPI trend (vs previous period)
struct KPITrend {
    let percentChange: Double?
    let direction: TrendDirection
    
    var isPositive: Bool {
        switch direction {
        case .up: return true
        case .down: return false
        case .neutral: return false
        }
    }
}

// MARK: - Single insight (rule-based, localizable)
struct AnalyticsInsight: Identifiable {
    let id: String
    let messageKey: String
    let formatArguments: [CVarArg]
    
    func localizedMessage() -> String {
        let template = L10n(messageKey)
        if formatArguments.isEmpty {
            return template
        }
        return String(format: template, arguments: formatArguments)
    }
}

// MARK: - Monthly data point (kept for any future use)
struct MonthlyDataPoint: Identifiable {
    let id: String
    let month: Date
    let income: Double
    let expenses: Double
    let savings: Double
    let remaining: Double
    
    var netBalance: Double { income - expenses }
}

// MARK: - Weekly data point for line chart (fixed intra-month ranges: 1–7, 8–14, 15–21, 22–last)
struct WeeklyDataPoint: Identifiable {
    let id: String
    /// Display label e.g. "Feb 1–7", "Feb 22–28"
    let label: String
    let weekIndex: Int
    let income: Double
    let expenses: Double
    
    var netBalance: Double { income - expenses }
}

// MARK: - Chart input: value + income/expense per week (for line chart and tooltip)
struct WeekData: Identifiable {
    let id: String
    let weekIndex: Int
    let label: String
    let value: Decimal
    let income: Decimal
    let expenses: Decimal
}

// MARK: - ViewModel
class AnalyticsViewModel: ObservableObject {
    @Published var selectedMonth: Date = Date()
    @Published var monthlyIncome: Double = 0
    @Published var totalExpenses: Double = 0
    @Published var goalAllocations: Double = 0
    @Published var remainingBalance: Double = 0
    @Published var categoryBreakdown: [CategoryDisplayInfo: Double] = [:]
    
    // Previous period (for trend)
    @Published var previousMonthIncome: Double = 0
    @Published var previousMonthExpenses: Double = 0
    @Published var previousMonthSavings: Double = 0
    @Published var previousMonthRemaining: Double = 0
    
    // Computed trends (percent change vs last month)
    var incomeTrend: KPITrend { trend(from: previousMonthIncome, to: monthlyIncome, higherIsBetter: true) }
    var expensesTrend: KPITrend { trend(from: previousMonthExpenses, to: totalExpenses, higherIsBetter: false) }
    var savingsTrend: KPITrend { trend(from: previousMonthSavings, to: goalAllocations, higherIsBetter: true) }
    var remainingTrend: KPITrend { trend(from: previousMonthRemaining, to: remainingBalance, higherIsBetter: true) }
    
    // Rule-based insights
    @Published var insights: [AnalyticsInsight] = []
    
    // Weekly trend within selected month for Line chart (4 segments: 1–7, 8–14, 15–21, 22–last)
    @Published var weeklyTrendData: [WeeklyDataPoint] = []
    
    /// Aggregated weekly data for the line chart (net balance + income/expense per week for tooltip).
    var weekDataForLineChart: [WeekData] {
        weeklyTrendData.map { point in
            WeekData(
                id: point.id,
                weekIndex: point.weekIndex,
                label: point.label,
                value: Decimal(point.netBalance),
                income: Decimal(point.income),
                expenses: Decimal(point.expenses)
            )
        }
    }
    
    private let expenseService = ExpenseService.shared
    private let incomeService = IncomeService.shared
    private let goalService = GoalService.shared
    private let userProfileService = UserProfileService.shared
    let calendar = Calendar.current
    
    var availableMonths: [Date] {
        let installationDate = userProfileService.profile.appInstallationDate
        let currentDate = Date()
        var months: [Date] = []
        var date = calendar.dateInterval(of: .month, for: installationDate)?.start ?? installationDate
        while date <= currentDate {
            months.append(date)
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: date) else { break }
            date = nextMonth
        }
        return months.reversed()
    }
    
    func monthString(for date: Date) -> String {
        LocalizationManager.shared.monthYearString(for: date)
    }
    
    /// Short label for trend chart: "Feb 26'", "Jan 26'", "Dec 25'"
    func shortMonthYear(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date) + "'"
    }
    
    func updateData() {
        monthlyIncome = incomeService.totalIncomeForMonth(selectedMonth)
        totalExpenses = expenseService.totalExpensesForMonth(selectedMonth)
        goalAllocations = goalService.totalGoalAllocationsForMonth(selectedMonth)
        categoryBreakdown = expenseService.expensesByCategoryDisplayForMonth(selectedMonth)
        
        // Match Dashboard: remaining = this month's income - expenses - goals only (no automatic carryover).
        remainingBalance = monthlyIncome - totalExpenses - goalAllocations
        
        // Previous month stats
        if let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            previousMonthIncome = incomeService.totalIncomeForMonth(prevMonth)
            previousMonthExpenses = expenseService.totalExpensesForMonth(prevMonth)
            previousMonthSavings = goalService.totalGoalAllocationsForMonth(prevMonth)
            let prevCarryover = previousMonthRemainingBalance(for: prevMonth)
            previousMonthRemaining = previousMonthIncome + prevCarryover - previousMonthExpenses - previousMonthSavings
        } else {
            previousMonthIncome = 0
            previousMonthExpenses = 0
            previousMonthSavings = 0
            previousMonthRemaining = 0
        }
        
        generateInsights()
        loadWeeklyTrendData()
    }
    
    private func trend(from previous: Double, to current: Double, higherIsBetter: Bool) -> KPITrend {
        guard previous > 0 else {
            if current > 0 { return KPITrend(percentChange: nil, direction: .up) }
            return KPITrend(percentChange: nil, direction: .neutral)
        }
        let delta = ((current - previous) / previous) * 100
        let direction: TrendDirection
        if abs(delta) < 0.5 { direction = .neutral }
        else if delta > 0 { direction = higherIsBetter ? .up : .down }
        else { direction = higherIsBetter ? .down : .up }
        return KPITrend(percentChange: delta, direction: direction)
    }
    
    private func previousMonthRemainingBalance(for month: Date? = nil) -> Double {
        let target = month ?? selectedMonth
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: target) else {
            return 0
        }
        let installationDate = userProfileService.profile.appInstallationDate
        if previousMonth < calendar.dateInterval(of: .month, for: installationDate)?.start ?? installationDate {
            return 0
        }
        let prevIncome = incomeService.totalIncomeForMonth(previousMonth)
        let prevExpenses = expenseService.totalExpensesForMonth(previousMonth)
        let prevGoalAllocations = goalService.totalGoalAllocationsForMonth(previousMonth)
        let prevBalance = prevIncome - prevExpenses - prevGoalAllocations
        return max(0, prevBalance)
    }
    
    private func generateInsights() {
        var result: [AnalyticsInsight] = []
        
        // Top category share
        let sorted = categoryBreakdown.sorted { $0.value > $1.value }
        let totalExp = totalExpenses
        if totalExp > 0, let top = sorted.first {
            let pct = Int(100 * top.value / totalExp)
            if pct >= 50 {
                result.append(AnalyticsInsight(
                    id: "top_category",
                    messageKey: "analytics.insight.top_category_high",
                    formatArguments: [top.key.name, pct]
                ))
            } else if pct >= 20 {
                result.append(AnalyticsInsight(
                    id: "top_category",
                    messageKey: "analytics.insight.top_category",
                    formatArguments: [top.key.name, pct]
                ))
            }
        }
        
        // Expense month-over-month is shown in the trend strip; omit here to avoid repeating the same figure.
        
        // Zero savings nudge
        if goalAllocations <= 0 && monthlyIncome > 0 {
            result.append(AnalyticsInsight(
                id: "no_savings",
                messageKey: "analytics.insight.consider_savings_goal",
                formatArguments: []
            ))
        }
        
        // Over budget
        if remainingBalance < 0 {
            result.append(AnalyticsInsight(
                id: "over_budget",
                messageKey: "analytics.insight.over_budget",
                formatArguments: []
            ))
        }
        
        insights = result
    }
    
    /// Fixed intra-month week ranges: 1–7, 8–14, 15–21, 22–last day. Works for 28/29/30/31 days.
    private func loadWeeklyTrendData() {
        let monthStart = calendar.dateInterval(of: .month, for: selectedMonth)?.start ?? selectedMonth
        guard let dayRange = calendar.range(of: .day, in: .month, for: selectedMonth) else {
            weeklyTrendData = []
            return
        }
        let lastDay = dayRange.upperBound - 1
        let monthExpenses = expenseService.expensesForMonth(selectedMonth)
        let monthIncomes = incomeService.incomesForMonth(selectedMonth)
        let currentCurrency = userProfileService.profile.currency
        
        let weekRanges: [(startDay: Int, endDay: Int)] = [
            (1, 7),
            (8, 14),
            (15, 21),
            (22, lastDay)
        ]
        
        let monthSymbol = shortMonthLabel(for: selectedMonth)
        var points: [WeeklyDataPoint] = []
        
        for (index, range) in weekRanges.enumerated() {
            let income = sumIncomes(in: monthIncomes, fromDay: range.startDay, toDay: range.endDay, currency: currentCurrency)
            let expenses = sumExpenses(in: monthExpenses, fromDay: range.startDay, toDay: range.endDay, currency: currentCurrency)
            let label = weekRangeLabel(monthSymbol: monthSymbol, start: range.startDay, end: range.endDay)
            points.append(WeeklyDataPoint(
                id: "\(index)",
                label: label,
                weekIndex: index,
                income: income,
                expenses: expenses
            ))
        }
        weeklyTrendData = points
    }
    
    private func shortMonthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func weekRangeLabel(monthSymbol: String, start: Int, end: Int) -> String {
        "\(monthSymbol) \(start)–\(end)"
    }
    
    /// Day of month (1–31) in the calendar's timezone. Uses startOfDay so time-of-day doesn't shift the day.
    private func dayOfMonth(for date: Date) -> Int {
        calendar.component(.day, from: calendar.startOfDay(for: date))
    }
    
    private func sumExpenses(in expenses: [Expense], fromDay start: Int, toDay end: Int, currency: String) -> Double {
        expenses
            .filter { let d = dayOfMonth(for: $0.date); return d >= start && d <= end }
            .reduce(0) { $0 + ($1.currency == currency ? $1.amount : $1.amount) }
    }
    
    private func sumIncomes(in incomes: [Income], fromDay start: Int, toDay end: Int, currency: String) -> Double {
        incomes
            .filter { $0.countsTowardBalance }
            .filter { let d = dayOfMonth(for: $0.date); return d >= start && d <= end }
            .reduce(0) { $0 + ($1.currency == currency ? $1.amount : $1.amount) }
    }
    
    /// Maps drag X position to nearest trend data index for tooltip (0..<data.count).
    func trendIndex(forDragX x: CGFloat, in dataCount: Int, chartWidth: CGFloat) -> Int? {
        guard dataCount > 0, chartWidth > 0 else { return nil }
        let index = Int((x / chartWidth) * CGFloat(dataCount))
        return min(max(index, 0), dataCount - 1)
    }

    // MARK: - Income split (Analytics hero)

    /// Same “near zero” threshold as analytics trend placeholders (`AnalyticsView`).
    private static let incomeSplitEpsilon: Double = 0.005

    /// Bar scale: recorded monthly income when positive (bars = share of income); otherwise expenses + savings so relative sizes stay honest without implying a remainder vs income.
    var incomeSplitScaleMax: Double {
        if monthlyIncome > Self.incomeSplitEpsilon { return monthlyIncome }
        let sum = totalExpenses + goalAllocations
        return sum > Self.incomeSplitEpsilon ? sum : 1
    }

    /// Unallocated income (not shown as a bar when there is no recorded income).
    var incomeSplitUnallocated: Double {
        guard monthlyIncome > Self.incomeSplitEpsilon else { return 0 }
        return max(0, monthlyIncome - totalExpenses - goalAllocations)
    }

    var incomeSplitShowsRemainingBar: Bool {
        monthlyIncome > Self.incomeSplitEpsilon
    }

    /// Expenses plus goal allocations (money assigned from income perspective).
    var incomeSplitAllocatedOutflows: Double {
        totalExpenses + goalAllocations
    }

    /// Denominator for segmented bar segment widths.
    ///
    /// **Normal:** `monthlyIncome` when recorded — segments are fractions of income (expenses + savings + remaining = income when under budget).
    ///
    /// **Overflow:** When expenses + savings exceed income, remaining is 0 and `expenses + savings > income`. We use `max(income, expenses + savings + remaining)` so the bar fills 100% and proportions match actual outflows (Storage-style “used space” that can exceed the nominal quota). UI may show a short overflow hint.
    ///
    /// **No income:** Same as `incomeSplitScaleMax` (expenses + savings, or 1).
    var incomeSplitSegmentDenominator: Double {
        let eps = Self.incomeSplitEpsilon
        let e = totalExpenses
        let s = goalAllocations
        let r = incomeSplitUnallocated
        if monthlyIncome > eps {
            return max(monthlyIncome, e + s + r)
        }
        return incomeSplitScaleMax
    }

    /// True when recorded income is positive but allocated outflows exceed it (bar denominator > income).
    var incomeSplitShowsOverflowHint: Bool {
        let eps = Self.incomeSplitEpsilon
        guard monthlyIncome > eps else { return false }
        return incomeSplitSegmentDenominator > monthlyIncome + eps
    }
}
