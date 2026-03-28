//
//  AppAnimation.swift
//  Friscora
//
//  Centralized animation constants. Use these everywhere for consistent,
//  cohesive motion (tabs, cards, charts, sheets, list updates).
//

import SwiftUI

/// App-wide animation constants. Prefer these over ad-hoc spring/easeOut values.
enum AppAnimation {

    // MARK: - Tab & segment

    /// Tab bar and segment changes (MainTabView, AddExpenseView, GoalsView, WorkScheduleView).
    static let tabSwitch = Animation.spring(response: 0.35, dampingFraction: 0.78)

    /// Toggle chips, filter segments (e.g. Analytics chart type).
    static let segmentToggle = Animation.spring(response: 0.3, dampingFraction: 0.75)

    // MARK: - Cards & sections

    /// Expand/collapse sections (e.g. Dashboard category block).
    static let cardExpand = Animation.spring(response: 0.38, dampingFraction: 0.82)

    /// Button press feedback, small state changes.
    static let buttonPress = Animation.spring(response: 0.2, dampingFraction: 0.7)

    /// Primary content transition (e.g. navigate to Add tab from dashboard).
    static let primaryTransition = Animation.spring(response: 0.5, dampingFraction: 0.8)

    /// Standard interaction: toggles, row selection, form fields.
    static let standard = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Snappy selection (e.g. color picker, small chips).
    static let snappy = Animation.spring(response: 0.2, dampingFraction: 0.8)

    // MARK: - Forms & sheets

    /// Form content changes (tab index, focus, canSave) in Add flow.
    static let formField = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Sheet / fullScreenCover present and dismiss.
    static let sheetPresent = Animation.spring(response: 0.42, dampingFraction: 0.88)

    /// Feedback submit, success state.
    static let feedbackSubmit = Animation.spring(response: 0.5, dampingFraction: 0.75)

    // MARK: - Charts

    /// Chart appear and type switch (pie/bar/line).
    static let chartReveal = Animation.easeOut(duration: 0.48)

    /// Pie chart segment fill (legacy single progress; prefer Analytics staggered slices).
    static let chartPieReveal = Animation.easeOut(duration: 1.25)

    /// Analytics spending hero: opacity/scale entrance (longer than chartReveal so pie stagger reads clearly).
    static let analyticsHeroReveal = Animation.easeOut(duration: 1.45)

    /// Analytics pie: delay before first wedge begins (after hero starts).
    static let analyticsPieLeadDelay: TimeInterval = 0.22

    /// Analytics pie: start offset between wedges (largest-first order).
    static let analyticsPieStagger: TimeInterval = 0.11

    /// Analytics pie: each wedge’s sweep duration (easeOut applied in `withAnimation`).
    static let analyticsPieSliceSweepDuration: TimeInterval = 0.52

    /// Bar chart fill progress (slightly longer for bar growth).
    static let chartBarReveal = Animation.easeOut(duration: 0.55)

    /// Line chart: tap/drag indicator and overlay (short).
    static let lineChartInteraction = Animation.easeInOut(duration: 0.15)

    /// Line chart: indicator appear (easeInOut 0.25s).
    static let lineChartIndicator = Animation.easeInOut(duration: 0.25)

    /// Line chart: line draw-in (0.7s).
    static let lineChartDraw = Animation.easeOut(duration: 0.7)

    // MARK: - Lists & items

    /// List item add/remove (goals, history rows).
    static let listItem = Animation.easeOut(duration: 0.4)

    /// Goal completion sequence (steps with delay at call site).
    static let goalCelebration = Animation.easeOut(duration: 0.7)

    /// Goal completion final step (longer).
    static let goalCelebrationFinal = Animation.easeOut(duration: 0.8)

    // MARK: - Quick UI

    /// Short feedback (opacity, scale), ~0.25s.
    static let quickUI = Animation.easeOut(duration: 0.25)

    /// Work day form expand/collapse.
    static let workDayExpand = Animation.easeInOut(duration: 0.35)

    // MARK: - Special

    /// Passcode shake (stiff spring).
    static let passcodeShake = Animation.spring(response: 0.3, dampingFraction: 0.5)

    /// Confetti / decorative (use with .linear and custom duration at call site).
    static func confetti(duration: Double) -> Animation {
        .linear(duration: duration)
    }
}
