//
//  WorkScheduleView.swift
//  Friscora
//
//  Schedule tab: work shifts and personal events on one calendar; pay tools stay work-only.
//

import SwiftUI
import UIKit

private struct PartnerDayDetailSelection: Identifiable, Equatable {
    let date: Date
    var id: String { ScheduleSharingScheduleExporter.dayKey(for: date) }
}

struct ScheduleView: View {
    @StateObject private var viewModel = WorkScheduleViewModel()
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    @StateObject private var shareViewModel = ScheduleSharingViewModel()
    @EnvironmentObject private var shareCoordinator: ScheduleShareCoordinator
    @Environment(\.colorScheme) private var colorScheme
    /// Start-of-day when the Shift Composer is open; `nil` when closed. Same-day tap toggles close.
    @State private var composerDay: Date? = nil
    @State private var composerStage: ScheduleComposerStage = .collapsed
    @AccessibilityFocusState private var composerAccessibilityFocused: Bool
    @State private var showingSettings = false
    @State private var showingNewJob = false
    @State private var showingClearConfirmation = false
    /// Collapsed by default so the calendar stays the visual focus; projection stays one tap away.
    @State private var salaryProjectionExpanded = false
    /// Wrap/unwrap summary card content with a chevron, like salary projection.
    @State private var summaryExpanded = true
    @FocusState private var shareNameFieldFocused: Bool
    @State private var showingShareInviteComposer = false
    @State private var partnerDayDetailSelection: PartnerDayDetailSelection?
    @State private var showingBulkApplySheet = false
    @State private var bulkApplyPresetJobId: UUID?
    @State private var bulkApplyPresetShiftId: UUID?
    @State private var recentBulkOperation: BulkOperation?
    @State private var undoBannerStartDate: Date?
    @State private var jobDetailForShifts: Job?
    @State private var activePatternSheet: WorkPatternCreationContext?
    /// Debounces month-side effects while the user is swiping pages.
    @State private var visibleMonthSyncTask: Task<Void, Never>?
    /// Drives staged visual transitions for button-triggered month jumps.
    @State private var monthNavigationTask: Task<Void, Never>?

    /// Months to show in horizontal calendar (24 back, current, 24 forward)
    private var calendarMonths: [Date] {
        let cal = viewModel.calendar
        guard let startOfCurrent = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return [] }
        return (-24..<25).compactMap { cal.date(byAdding: .month, value: $0, to: startOfCurrent) }
    }
    
    /// Index of the currently selected month in calendarMonths
    @State private var selectedMonthIndex: Int = 24
    /// Swipe/tap direction for smooth month-title transition (-1 prev, +1 next).
    @State private var monthTransitionDirection: Int = 0
    /// Slight delayed title animation for calmer month transitions.
    private let monthTitleTransitionAnimation = AppAnimation.tabSwitch.delay(0.12)

    /// Month for the visible pager page — use for partner snapshot loading so it stays aligned with the grid (not a stale `selectedMonth`).
    private var visibleCalendarMonth: Date {
        guard selectedMonthIndex >= 0, selectedMonthIndex < calendarMonths.count else {
            return viewModel.selectedMonth
        }
        return calendarMonths[selectedMonthIndex]
    }

    /// Layout identity for calendar views only — **must not** include partner snapshot day keys. Embedding changing
    /// Firestore keys in `.id()` remounts `LazyHStack` / `LazyVGrid` on every sync and can corrupt paging + grids on newer OS versions.
    private var calendarLayoutIdentity: String {
        let pair = shareViewModel.partnership.map { $0.pairingId.uuidString } ?? "none"
        return "\(shareViewModel.activeSource)-\(pair)"
    }

    /// Stable per month + sharing mode; partner **data** still flows via `@Published partnerMonthSnapshot` without remounting the grid.
    private func calendarPageIdentity(for month: Date) -> String {
        let cal = viewModel.calendar
        let y = cal.component(.year, from: month)
        let m = cal.component(.month, from: month)
        return "schedule-\(y)-\(m)-\(calendarLayoutIdentity)"
    }
    
    /// Uses `selectedMonthIndex` so it stays in sync with the pager (not one frame behind `viewModel.selectedMonth`).
    private var isViewingMonthContainingToday: Bool {
        guard let todayIdx = ScheduleMonthNavigator.todayIndex(in: calendarMonths, calendar: viewModel.calendar) else {
            return true
        }
        return selectedMonthIndex == todayIdx
    }
    
    /// Check if current month has any work days (local schedule only; partner view never clears local data).
    private var hasWorkDaysInMonth: Bool {
        guard shareViewModel.activeSource == .mySchedule else { return false }
        let workDays = workScheduleService.workDays.filter { workDay in
            viewModel.calendar.isDate(workDay.date, equalTo: viewModel.selectedMonth, toGranularity: .month)
        }
        return !workDays.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            scheduleContent
                .navigationTitle(L10n("tab.schedule"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { scheduleToolbar }
        }
        .animation(AppAnimation.inspectorReveal, value: composerDay)
        .alert(L10n("work.clear_all"), isPresented: $showingClearConfirmation) {
            Button(L10n("common.cancel"), role: .cancel) { }
            Button(L10n("work.clear_all_button"), role: .destructive) {
                clearMonthWorkDays()
            }
        } message: {
            Text(String(format: L10n("work.delete_month_confirm"), viewModel.monthString(for: viewModel.selectedMonth)))
        }
        .sheet(isPresented: $showingSettings) {
            WorkSettingsView(isPresented: $showingSettings)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showingNewJob) {
            NewJobView()
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showingShareInviteComposer) {
            shareCalendarSheet
        }
        .onAppear {
            SalarySyncService.shared.syncSalaryToIncome()
            shareViewModel.purgeExpiredInvites()
            if selectedMonthIndex >= calendarMonths.count {
                selectedMonthIndex = max(0, calendarMonths.count - 1)
            }
            shareViewModel.syncSchedulePagerVisibleMonth(visibleCalendarMonth)
            Task {
                await shareViewModel.onScheduleTabAppear()
                await shareViewModel.ensurePartnerSnapshot(for: visibleCalendarMonth)
            }
        }
        .task(id: recentBulkOperation?.id) {
            guard let opId = recentBulkOperation?.id else { return }
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            await MainActor.run {
                guard recentBulkOperation?.id == opId else { return }
                recentBulkOperation = nil
                undoBannerStartDate = nil
            }
        }
        .onChange(of: shareCoordinator.pendingInvite) { _, incoming in
            guard let incoming else { return }
            ScheduleShareLogging.trace("ScheduleView: received coordinator.pendingInvite → ViewModel")
            Task { @MainActor in
                if shareViewModel.validateIncomingInvite(incoming) {
                    shareViewModel.consumeIncomingInvite(incoming)
                }
                shareCoordinator.consumePendingInvite()
            }
        }
        .alert(L10n("schedule.share.error.alert_title"), isPresented: shareErrorPresentedBinding) {
            Button(L10n("common.ok")) { }
        } message: {
            Text(shareErrorMessage(shareViewModel.linkErrorState))
        }
        .sheet(
            isPresented: Binding(
                get: { shareViewModel.pendingInvite != nil },
                set: { if !$0 { shareViewModel.pendingInvite = nil } }
            )
        ) {
            if let invite = shareViewModel.pendingInvite {
                InviteAcceptanceSheet(
                    invite: invite,
                    recipientName: $shareViewModel.recipientNameInput,
                    isLoading: shareViewModel.isPerformingNetworkAction,
                    errorText: shareViewModel.consentErrorMessage,
                    onAccept: { Task { await shareViewModel.approveInvite() } },
                    onDecline: { Task { await shareViewModel.declineInvite() } }
                )
                .task {
                    await shareViewModel.resolvePendingInviteIfNeeded()
                }
            }
        }
        .sheet(item: $partnerDayDetailSelection) { selection in
            NavigationStack {
                PartnerScheduleDayDetailView(
                    date: selection.date,
                    bucket: shareViewModel.partnerDayBucket(for: selection.date)
                        ?? PartnerScheduleSnapshot.DayBucket(work: [], personalEventCount: 0),
                    shareItems: shareViewModel.partnerMonthSnapshot?.shareItems ?? []
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n("common.done")) { partnerDayDetailSelection = nil }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingBulkApplySheet) {
            BulkShiftApplySheet(
                initialJobId: bulkApplyPresetJobId,
                initialShiftId: bulkApplyPresetShiftId,
                lockHeaderSelections: bulkApplyPresetJobId != nil && bulkApplyPresetShiftId != nil,
                onFinished: { op in
                    recentBulkOperation = op
                    undoBannerStartDate = Date()
                },
                onRequestJobEditor: { jid in
                    showingBulkApplySheet = false
                    jobDetailForShifts = workScheduleService.job(withId: jid)
                }
            )
            .presentationCornerRadius(24)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $jobDetailForShifts) { job in
            JobDetailView(job: job)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $activePatternSheet) { ctx in
            WorkPatternCreationSheet(context: ctx)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onChange(of: shareViewModel.activeSource) { _, _ in
            withAnimation(AppAnimation.inspectorReveal) {
                composerDay = nil
                composerStage = .collapsed
            }
            shareViewModel.syncSchedulePagerVisibleMonth(visibleCalendarMonth)
            Task {
                await shareViewModel.ensurePartnerSnapshot(for: visibleCalendarMonth)
                jumpToPartnerSnapshotMonthIfNeeded()
            }
        }
        .onChange(of: shareViewModel.partnerMonthSnapshot) { _, _ in
            guard shareViewModel.activeSource == .partner else { return }
            jumpToPartnerSnapshotMonthIfNeeded()
        }
        .onChange(of: viewModel.selectedMonth) { _, _ in
            scheduleVisibleMonthSync()
        }
        .onChange(of: shareViewModel.partnership) { _, newValue in
            if newValue != nil {
                SchedulePairingFirestoreSync.stopListeningForRecipientAcceptance()
            }
            shareViewModel.syncSchedulePagerVisibleMonth(visibleCalendarMonth)
            shareViewModel.reconcileLiveFirestoreSyncObservers()
            if newValue != nil {
                Task {
                    await shareViewModel.ensurePartnerSnapshot(for: visibleCalendarMonth)
                }
            }
        }
        .onChange(of: shareViewModel.outgoingInvite?.token) { _, _ in
            shareViewModel.startOutgoingInvitePairingObserverIfNeeded()
        }
        .onChange(of: composerDay) { _, newValue in
            if newValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                    composerAccessibilityFocused = true
                }
            } else {
                composerAccessibilityFocused = false
            }
        }
    }

    private var scheduleContent: some View {
        ZStack {
            AppColorTheme.background
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        if !workScheduleService.hasJobs {
                            scheduleOnboardingHint
                                .padding(.horizontal, AppSpacing.l)
                                .padding(.top, AppSpacing.s)
                        }

                        horizontalCalendarSection
                            .padding(.horizontal, AppSpacing.l)
                            .padding(.top, AppSpacing.l)

                        if shareViewModel.activeSource == .mySchedule {
                            if recentBulkOperation != nil {
                                undoBulkOperationBanner
                                    .padding(.horizontal, AppSpacing.l)
                            } else if let suggestion = workScheduleService.patternSuggestion {
                                patternSuggestionCard(suggestion)
                                    .padding(.horizontal, AppSpacing.l)
                            }
                        }

                        if shareViewModel.isReadOnlySharedContext {
                            sharedReadOnlyInfoSection
                                .padding(.horizontal, AppSpacing.l)
                        } else if workScheduleService.hasJobs {
                            summarySection
                                .padding(.horizontal, AppSpacing.l)
                                .id("summarySection")

                            salaryProjectionDisclosure
                                .padding(.horizontal, AppSpacing.l)
                                .id("salaryProjectionSection")
                        } else {
                            scheduleNoJobsForecastNote
                                .padding(.horizontal, AppSpacing.l)
                        }
                    }
                    .padding(.vertical, AppSpacing.m)
                }
                .scrollIndicators(.hidden, axes: .vertical)
                .allowsHitTesting(composerDay == nil)
                .onChange(of: summaryExpanded) { _, isExpanded in
                    guard isExpanded else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(AppAnimation.tabSwitch) {
                            proxy.scrollTo("salaryProjectionSection", anchor: .top)
                        }
                    }
                }
                .onChange(of: salaryProjectionExpanded) { _, isExpanded in
                    guard isExpanded else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        withAnimation(AppAnimation.tabSwitch) {
                            proxy.scrollTo("salaryProjectionSection", anchor: .top)
                        }
                    }
                }
            }

            // Always show the composer when `composerDay` is set. Do not gate on `viewModel.selectedMonth`:
            // the month pager index and `viewModel.selectedMonth` can briefly disagree during transitions;
            // gating on `selectedMonth` alone would hide the overlay while `allowsHitTesting` is still false.
            if let day = composerDay {
                scheduleComposerDimmerAndCard(for: day)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    @ToolbarContentBuilder
    private var scheduleToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showingClearConfirmation = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.caption)
                    Text(L10n("common.clear"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColorTheme.negative)
            }
            .disabled(!hasWorkDaysInMonth)
            .opacity(hasWorkDaysInMonth ? 1 : 0.45)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(.white)
                    .accessibilityLabel(L10n("schedule.toolbar.jobs_a11y"))
            }
        }
        if shareViewModel.activeSource == .mySchedule && hasAnyJobWithShift {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    bulkApplyPresetJobId = nil
                    bulkApplyPresetShiftId = nil
                    showingBulkApplySheet = true
                } label: {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .foregroundColor(.gray)
                        .accessibilityLabel(L10n("bulk_apply.toolbar.a11y"))
                }
            }
        }
    }
    
    private var hasAnyJobWithShift: Bool {
        workScheduleService.jobs.contains { !$0.shifts.isEmpty }
    }
    
    @ViewBuilder
    private var undoBulkOperationBanner: some View {
        if let op = recentBulkOperation, let start = undoBannerStartDate {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                let elapsed = timeline.date.timeIntervalSince(start)
                let progress = max(0, min(1, 1 - elapsed / 12))
                VStack(alignment: .leading, spacing: AppSpacing.s) {
                    HStack(alignment: .center, spacing: AppSpacing.s) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(undoBannerTitle(for: op))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColorTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Button(L10n("bulk_apply.save_as_pattern")) {
                            activePatternSheet = .fromUndoBulk(op)
                        }
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColorTheme.accent)
                        Button(L10n("common.undo")) {
                            undoRecentBulkOperation(op)
                        }
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColorTheme.textPrimary)
                    }
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColorTheme.textTertiary.opacity(0.2))
                        GeometryReader { geo in
                            Capsule()
                                .fill(AppColorTheme.accent)
                                .frame(width: max(4, geo.size.width * progress))
                        }
                        .frame(height: AppSpacing.hairline)
                    }
                    .frame(height: AppSpacing.hairline)
                    .clipShape(Capsule())
                }
                .padding(AppSpacing.m)
                .background(AppColorTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardMedium, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(AppAnimation.inspectorReveal, value: op.id)
            }
        }
    }
    
    private func undoBannerTitle(for op: BulkOperation) -> String {
        let currency = userProfileService.profile.currency
        if let job = workScheduleService.job(withId: op.jobId), job.paymentType == .hourly,
           let shiftId = op.shiftId, let shift = job.shift(withId: shiftId),
           let rate = job.hourlyRate, rate > 0 {
            let est = Double(op.dayCount) * shift.durationHours * rate
            let money = CurrencyFormatter.formatWithSymbol(est, currencyCode: currency)
            return String(format: L10n("bulk_apply.undo_banner_hourly"), op.dayCount, money)
        }
        return String(format: L10n("bulk_apply.undo_banner_plain"), op.dayCount)
    }
    
    private func undoRecentBulkOperation(_ op: BulkOperation) {
        let ids = workScheduleService.workDays(withBulkOperationId: op.id).map(\.id)
        workScheduleService.performWorkDayBatch(toAdd: [], toRemove: ids, operationRecord: nil)
        workScheduleService.removeBulkOperationRecord(id: op.id)
        recentBulkOperation = nil
        undoBannerStartDate = nil
        HapticHelper.lightImpact()
    }
    
    private func patternSuggestionCard(_ suggestion: SchedulePatternSuggestion) -> some View {
        let currency = userProfileService.profile.currency
        let fp = SchedulePatternDetector.fingerprint(jobId: suggestion.jobId, shiftId: suggestion.shiftId, weekdays: suggestion.weekdays)
        return VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(L10n("pattern.suggestion.title"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            if suggestion.isFixedMonthlyJob {
                Text(L10n("pattern.suggestion.fixed_monthly_body"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            } else if let est = suggestion.estimatedMonthlyEarnings, est > 0 {
                Text(String(format: L10n("pattern.suggestion.earnings"), CurrencyFormatter.formatWithSymbol(est, currencyCode: currency)))
                    .font(AppTypography.bodySecondary)
                    .foregroundColor(AppColorTheme.positive)
            } else {
                Text(L10n("pattern.suggestion.body_generic"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            HStack(spacing: AppSpacing.m) {
                Button(L10n("pattern.suggestion.not_now")) {
                    workScheduleService.dismissPatternSuggestion(fingerprint: fp)
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
                Spacer()
                Button(L10n("pattern.suggestion.save")) {
                    activePatternSheet = .fromSuggestion(suggestion)
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.accent)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardMedium, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var shareErrorPresentedBinding: Binding<Bool> {
        Binding(
            get: { shareViewModel.linkErrorState != nil },
            set: { if !$0 { shareViewModel.linkErrorState = nil } }
        )
    }
    
    /// Full-screen dimmer + bottom composer. Dimmer sits above the scroll view (month arrows are inactive until the composer is dismissed).
    @ViewBuilder
    private func scheduleComposerDimmerAndCard(for day: Date) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    // Balance: full `ultraThinMaterial` hides the grid in dark mode; very low opacity removes
                    // the blur. These opacities keep the calendar readable while the frosted effect still reads.
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(colorScheme == .dark ? 0.36 : 0.30)
                        .ignoresSafeArea()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    HapticHelper.lightImpact()
                    withAnimation(AppAnimation.inspectorReveal) {
                        composerDay = nil
                        composerStage = .collapsed
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n("schedule.composer.dismiss_a11y"))
                .accessibilityHint(L10n("schedule.composer.dismiss_hint_a11y"))
                .accessibilityAddTraits(.isButton)
            
            ScheduleComposerOverlay(
                date: day,
                stage: $composerStage,
                onDismissComposer: {
                    withAnimation(AppAnimation.inspectorReveal) {
                        composerDay = nil
                        composerStage = .collapsed
                    }
                },
                accessibilityComposerFocused: $composerAccessibilityFocused,
                onRequestBulkApply: shareViewModel.activeSource == .mySchedule
                    ? { jobId, shiftId in
                        bulkApplyPresetJobId = jobId
                        bulkApplyPresetShiftId = shiftId
                        showingBulkApplySheet = true
                    }
                    : nil
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func jumpToTodayMonth() {
        guard let idx = ScheduleMonthNavigator.todayIndex(in: calendarMonths, calendar: viewModel.calendar) else { return }
        guard idx != selectedMonthIndex else { return }
        navigateToMonthIndex(idx)
        impactFeedback(style: .light)
    }

    private func setSelectedMonthIndexAnimated(_ newIndex: Int, direction: Int) {
        guard newIndex >= 0, newIndex < calendarMonths.count else { return }
        monthTransitionDirection = direction
        withAnimation(AppAnimation.tabSwitch) {
            selectedMonthIndex = newIndex
        }
    }

    /// Ensures button-triggered month changes always show a visible page transition.
    /// For long jumps (e.g. "This month"), animate a few intermediate pages first.
    private func navigateToMonthIndex(_ targetIndex: Int) {
        guard targetIndex >= 0, targetIndex < calendarMonths.count else { return }
        let startIndex = selectedMonthIndex
        guard targetIndex != startIndex else { return }
        monthNavigationTask?.cancel()

        let direction = targetIndex > startIndex ? 1 : -1
        let distance = abs(targetIndex - startIndex)
        let stagedSteps = min(distance, 6)

        monthNavigationTask = Task {
            var current = startIndex
            if stagedSteps > 1 {
                for _ in 0..<stagedSteps {
                    if Task.isCancelled { return }
                    current += direction
                    await MainActor.run {
                        setSelectedMonthIndexAnimated(current, direction: direction)
                    }
                    try? await Task.sleep(nanoseconds: 55_000_000)
                }
            }
            if Task.isCancelled { return }
            await MainActor.run {
                setSelectedMonthIndexAnimated(targetIndex, direction: direction)
            }
        }
    }

    /// Partner snapshots use absolute `yyyy-MM-dd` keys. If the pager is on a month/year with no overlapping keys (e.g. April 2028 while data is April 2026), the grid looks empty — align the pager to the first month that contains partner days.
    private func jumpToPartnerSnapshotMonthIfNeeded() {
        guard shareViewModel.activeSource == .partner,
              let snap = shareViewModel.partnerMonthSnapshot,
              !snap.days.isEmpty else { return }
        let cal = viewModel.calendar
        let visible = visibleCalendarMonth
        if ScheduleMonthNavigator.visibleMonthContainsAnyPartnerDay(snap: snap, visibleMonthStart: visible, calendar: cal) {
            return
        }
        guard let targetMonth = ScheduleMonthNavigator.startOfMonthContainingEarliestPartnerDay(in: snap, calendar: cal) else { return }
        if let idx = calendarMonths.firstIndex(where: { cal.isDate($0, equalTo: targetMonth, toGranularity: .month) }) {
            guard idx != selectedMonthIndex else { return }
            withAnimation(AppAnimation.tabSwitch) {
                selectedMonthIndex = idx
                viewModel.selectedMonth = calendarMonths[idx]
            }
            ScheduleShareLogging.trace(
                "ScheduleView: jumped pager to month with partner data target=\(ScheduleSharingScheduleExporter.dayKey(for: targetMonth)) (was viewing year \(cal.component(.year, from: visible)))"
            )
            impactFeedback(style: .light)
        } else {
            ScheduleShareLogging.trace(
                "ScheduleView: partner data outside horizontal month window (earliest partner day) — user may need to scroll"
            )
        }
    }

    /// Clears all work days for the currently selected month
    private func clearMonthWorkDays() {
        let workDaysToDelete = workScheduleService.workDays.filter { workDay in
            viewModel.calendar.isDate(workDay.date, equalTo: viewModel.selectedMonth, toGranularity: .month)
        }
        
        for workDay in workDaysToDelete {
            workScheduleService.deleteWorkDay(workDay)
        }
        
        impactFeedback(style: .medium)
    }

    /// Debounces expensive snapshot/sync work so swipe paging remains calm.
    private func scheduleVisibleMonthSync() {
        visibleMonthSyncTask?.cancel()
        visibleMonthSyncTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            let month = visibleCalendarMonth
            await MainActor.run {
                shareViewModel.syncSchedulePagerVisibleMonth(month)
            }
            await shareViewModel.ensurePartnerSnapshot(for: month)
        }
    }
    
    private var scheduleOnboardingHint: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(L10n("schedule.onboarding.title"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            Text(L10n("schedule.onboarding.detail"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                showingNewJob = true
            } label: {
                Text(L10n("work.add_job"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColorTheme.accent.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColorTheme.cardBackground, AppColorTheme.cardBackground.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    }
    
    private var scheduleNoJobsForecastNote: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(L10n("schedule.forecast_scope_title"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            Text(L10n("settings.schedule_forecast_footer"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColorTheme.cardBackground, AppColorTheme.cardBackground.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    }

    private var sharedReadOnlyInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(L10n("schedule.share.readonly.title"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            Text(L10n("schedule.share.readonly.body"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppColorTheme.cardBackground, AppColorTheme.cardBackground.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    }
    
    private var horizontalCalendarSection: some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Text(viewModel.monthString(for: viewModel.selectedMonth))
                    .id(selectedMonthIndex)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .transition(monthTitleTransition)
                    .animation(monthTitleTransitionAnimation, value: selectedMonthIndex)
                Spacer()
            }

            HStack(spacing: 8) {
                if let contextSubtitle = shareViewModel.scheduleCalendarContextSubtitle {
                    Text(contextSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(shareViewModel.isReadOnlySharedContext ? AppColorTheme.sapphire : AppColorTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((shareViewModel.isReadOnlySharedContext ? AppColorTheme.sapphire : AppColorTheme.elevatedBackground).opacity(0.2))
                        .clipShape(Capsule())
                        .accessibilityIdentifier("schedule.activeContextPill")
                }

                Spacer()

                if shareViewModel.partnership != nil {
                    Button {
                        shareViewModel.togglePartnerScheduleView()
                    } label: {
                        Image(systemName: shareViewModel.activeSource == .partner ? "person.fill" : "person")
                            .foregroundColor(AppColorTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(AppColorTheme.elevatedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .accessibilityIdentifier("schedule.contextSwitcher")
                    .accessibilityLabel(
                        shareViewModel.activeSource == .partner
                            ? L10n("schedule.share.a11y.switch_to_mine")
                            : L10n("schedule.share.a11y.switch_to_partner")
                    )
                }

                Button {
                    showingShareInviteComposer = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(AppColorTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColorTheme.elevatedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel(L10n("schedule.share.management.a11y.open"))
            }
            .padding(.horizontal, 8)
            
            if let ctxDay = composerDay,
               viewModel.calendar.isDate(ctxDay, equalTo: viewModel.selectedMonth, toGranularity: .month),
               let line = selectedDayContextSummaryLine(for: ctxDay) {
                Text(line)
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(line)
            }
            
            /// Weekday labels live **outside** the paged `TabView`. The month pages use a fixed height; including
            /// this row inside each page clipped the headers off the top.
            calendarWeekdayHeaderRow
                .padding(.horizontal, 4)
            
            // `ScrollView` + `.scrollPosition` has been observed to desync `selectedMonthIndex` from the visible page
            // on iOS 26 when the composer opens (jumping e.g. to April 2028). `TabView` + page style keeps selection stable.
            GeometryReader { geo in
                TabView(selection: $selectedMonthIndex.animation(AppAnimation.tabSwitch)) {
                    ForEach(Array(calendarMonths.indices), id: \.self) { index in
                        calendarSectionForMonth(calendarMonths[index])
                            .frame(width: geo.size.width, height: 400)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(AppAnimation.tabSwitch, value: selectedMonthIndex)
            }
            .frame(height: 400)
            .onChange(of: selectedMonthIndex) { oldIndex, newIndex in
                guard newIndex >= 0, newIndex < calendarMonths.count else { return }
                monthTransitionDirection = (newIndex > oldIndex) ? 1 : (newIndex < oldIndex ? -1 : 0)
                let newMonth = calendarMonths[newIndex]
                if let d = composerDay, !viewModel.calendar.isDate(d, equalTo: newMonth, toGranularity: .month) {
                    withAnimation(AppAnimation.inspectorReveal) {
                        composerDay = nil
                        composerStage = .collapsed
                    }
                }
                viewModel.selectedMonth = newMonth
            }

            HStack(spacing: 12) {
                Button {
                    let newIndex = ScheduleMonthNavigator.previousIndex(from: selectedMonthIndex, lowerBound: 0)
                    guard newIndex != selectedMonthIndex else { return }
                    navigateToMonthIndex(newIndex)
                    impactFeedback(style: .light)
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColorTheme.ctaPrimary)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                }
                .disabled(selectedMonthIndex <= 0)
                .opacity(selectedMonthIndex <= 0 ? 0.5 : 1)
                .accessibilityIdentifier("schedule.monthPrevious")

                Spacer(minLength: 8)

                if !isViewingMonthContainingToday {
                    Button {
                        jumpToTodayMonth()
                    } label: {
                        Text(L10n("schedule.month.jump_this_month"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColorTheme.ctaPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppColorTheme.elevatedBackground)
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("schedule.monthJumpThisMonth")
                    .accessibilityHint(L10n("schedule.month.jump_this_month_a11y"))
                }

                Spacer(minLength: 8)

                Button {
                    let newIndex = ScheduleMonthNavigator.nextIndex(from: selectedMonthIndex, upperBound: calendarMonths.count - 1)
                    guard newIndex != selectedMonthIndex else { return }
                    navigateToMonthIndex(newIndex)
                    impactFeedback(style: .light)
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColorTheme.ctaPrimary)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                }
                .disabled(selectedMonthIndex >= calendarMonths.count - 1)
                .opacity(selectedMonthIndex >= calendarMonths.count - 1 ? 0.5 : 1)
                .accessibilityIdentifier("schedule.monthNext")
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [AppColorTheme.cardBackground, AppColorTheme.cardBackground.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
    }

    private var monthTitleTransition: AnyTransition {
        if monthTransitionDirection >= 0 {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    /// Compact context under the month header when a day is selected (mirrors composer stats; uses profile currency).
    private func selectedDayContextSummaryLine(for day: Date) -> String? {
        guard !shareViewModel.isReadOnlySharedContext else { return nil }
        let work = workScheduleService.workDays(for: day)
        let events = workScheduleService.personalEvents(onSameDayAs: day)
        let count = work.count + events.count
        guard count > 0 else { return nil }
        let hours = work.reduce(0) { $0 + effectiveHoursForSelectedDayContext($1) }
        let currency = userProfileService.profile.currency
        var hourlyTotal: Double = 0
        var hasHourlyEstimate = false
        for wd in work {
            guard let job = workScheduleService.job(withId: wd.jobId) else { continue }
            if job.paymentType == .hourly, let r = job.hourlyRate, r > 0 {
                hourlyTotal += effectiveHoursForSelectedDayContext(wd) * r
                hasHourlyEstimate = true
            }
        }
        let entriesPart = String(format: L10n("schedule.composer.entry_count"), count)
        var parts: [String] = [entriesPart]
        if hours > 0 {
            parts.append(formatHours(hours))
        }
        if hasHourlyEstimate {
            let money = CurrencyFormatter.formatWithSymbol(hourlyTotal, currencyCode: currency)
            parts.append(String(format: L10n("schedule.composer.approx_earnings_fragment"), money))
        }
        return parts.joined(separator: L10n("schedule.composer.stats_sep"))
    }

    private func effectiveHoursForSelectedDayContext(_ workDay: WorkDay) -> Double {
        guard let range = workScheduleService.resolvedDisplayTimeRangeMinutes(for: workDay, calendar: viewModel.calendar) else {
            return workDay.hoursWorked
        }
        return Shift.durationHours(startMinutesFromMidnight: range.start, endMinutesFromMidnight: range.end)
    }
    
    private func calendarSectionForMonth(_ month: Date) -> some View {
        calendarDayGrid(for: month)
    }
    
    /// Monday-first weekday labels — shared across months, aligned with the grid columns.
    private var calendarWeekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
    
    private func calendarDayGrid(for month: Date) -> some View {
        let days = generateCalendarDays(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { date in
                calendarDayView(for: date, inMonth: month)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .id(calendarPageIdentity(for: month))
    }
    
    private func calendarDayView(for date: Date, inMonth month: Date) -> some View {
        let isCurrentMonth = viewModel.calendar.isDate(date, equalTo: month, toGranularity: .month)
        let isToday = viewModel.calendar.isDateInToday(date)
        let partnerBucket = shareViewModel.isReadOnlySharedContext ? shareViewModel.partnerDayBucket(for: date) : nil
        let workDays = shareViewModel.isReadOnlySharedContext ? [] : workScheduleService.workDays(for: date)
        let personal = shareViewModel.isReadOnlySharedContext ? [] : workScheduleService.personalEvents(onSameDayAs: date)
        let partnerHasEntries = shareViewModel.isReadOnlySharedContext && partnerDayHasVisibleItems(bucket: partnerBucket)
        let dayNum = viewModel.calendar.component(.day, from: date)
        let isComposerFocusedDay = isCurrentMonth
            && (composerDay.map { viewModel.calendar.isDate($0, inSameDayAs: date) } ?? false)
        let showsEventIndicator = isCurrentMonth
            && !shareViewModel.isReadOnlySharedContext
            && !personal.isEmpty
        let a11y = scheduleDayAccessibility(
            date: date,
            isCurrentMonth: isCurrentMonth,
            workDays: workDays,
            personal: personal,
            partnerBucket: partnerBucket,
            composerOpenForThisDay: isComposerFocusedDay
        )

        let partnerSoftFill = shareViewModel.isReadOnlySharedContext
            && partnerHasEntries
            && isCurrentMonth
            && !isToday
            && !isComposerFocusedDay

        let partnerShiftTimeCaption = shareViewModel.isReadOnlySharedContext
            ? partnerCompactShiftTimeCaption(work: partnerBucket?.work ?? [], day: date)
            : nil

        return Button {
            guard isCurrentMonth else { return }
            if shareViewModel.isReadOnlySharedContext {
                partnerDayDetailSelection = PartnerDayDetailSelection(date: viewModel.calendar.startOfDay(for: date))
                HapticHelper.selection()
                return
            }
            HapticHelper.selection()
            withAnimation(AppAnimation.inspectorReveal) {
                if let ins = composerDay, viewModel.calendar.isDate(ins, inSameDayAs: date) {
                    composerDay = nil
                    composerStage = .collapsed
                } else {
                    // Keep pager + view model month aligned with the grid page being tapped (avoids drift
                    // between scroll-driven index and `selectedMonth` on newer OS runtimes).
                    if let idx = calendarMonths.firstIndex(where: { viewModel.calendar.isDate($0, equalTo: month, toGranularity: .month) }),
                       idx != selectedMonthIndex {
                        selectedMonthIndex = idx
                        viewModel.selectedMonth = calendarMonths[idx]
                    }
                    composerDay = viewModel.calendar.startOfDay(for: date)
                    composerStage = .collapsed
                }
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNum)")
                    .font(.system(size: 15, weight: isToday ? .bold : .semibold))
                    .foregroundColor(
                        isCurrentMonth
                            ? (isToday ? AppColorTheme.accent : AppColorTheme.textPrimary)
                            : AppColorTheme.textTertiary
                    )

                if isCurrentMonth && (!workDays.isEmpty || partnerHasEntries) {
                    scheduleDayMicroIndicatorRow(
                        workDays: workDays,
                        partnerBucket: partnerBucket,
                        day: date,
                        partnerShiftTimeCaption: partnerShiftTimeCaption
                    )
                } else {
                    Color.clear.frame(height: shareViewModel.isReadOnlySharedContext ? 16 : 12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: (partnerShiftTimeCaption != nil) ? 68 : 60, maxHeight: (partnerShiftTimeCaption != nil) ? 68 : 60)
            .scaleEffect(isComposerFocusedDay ? 1.04 : 1.0)
            .animation(AppAnimation.snappy, value: isComposerFocusedDay)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(partnerSoftFill ? AppColorTheme.sapphire.opacity(0.14) : (isComposerFocusedDay ? AppColorTheme.accent.opacity(0.18) : Color.clear))
            )
            .overlay {
                if isToday && isCurrentMonth {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppColorTheme.accent, lineWidth: 2)
                } else if isComposerFocusedDay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppColorTheme.accent.opacity(0.55), lineWidth: 1.5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showsEventIndicator {
                    Image(systemName: "calendar")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))
                }
            }
            .animation(AppAnimation.snappy, value: showsEventIndicator)
        }
        .disabled(!isCurrentMonth)
        .accessibilityLabel(a11y.label)
        .accessibilityHint(a11y.hint)
    }
    
    /// Work: thin multi-segment bar (stroke + translucent fill). Partner view uses API snapshot segments.
    @ViewBuilder
    private func scheduleDayMicroIndicatorRow(
        workDays: [WorkDay],
        partnerBucket: PartnerScheduleSnapshot.DayBucket?,
        day: Date,
        partnerShiftTimeCaption: String?
    ) -> some View {
        if shareViewModel.isReadOnlySharedContext {
            partnerCalendarMicroStack(bucket: partnerBucket, day: day, shiftTimeCaption: partnerShiftTimeCaption)
                .accessibilityElement(children: .ignore)
        } else {
            HStack(alignment: .center, spacing: 4) {
                workSegmentMicroBar(for: workDays)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 12)
            .accessibilityElement(children: .ignore)
        }
    }

    private func partnerDayHasVisibleItems(bucket: PartnerScheduleSnapshot.DayBucket?) -> Bool {
        guard let bucket else { return false }
        return !bucket.work.isEmpty || bucket.displayablePersonalEventCount > 0
    }

    private func partnerScheduleSegmentColor(hex: String) -> Color {
        let t = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 6 else { return AppColorTheme.accent }
        return Color(hex: t)
    }

    private func partnerCalendarMicroStack(
        bucket: PartnerScheduleSnapshot.DayBucket?,
        day: Date,
        shiftTimeCaption: String?
    ) -> some View {
        let work = bucket?.work ?? []
        let eventTotal = bucket?.displayablePersonalEventCount ?? 0
        return VStack(spacing: 2) {
            partnerShiftMicroRow(work: work)
                .frame(height: 5)
            if let shiftTimeCaption {
                Text(shiftTimeCaption)
                    .font(.system(size: 5.5, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColorTheme.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: 44)
            }
            partnerEventsMicroRow(totalEvents: eventTotal)
                .frame(height: 5)
        }
        .frame(minHeight: shiftTimeCaption == nil ? 14 : 21)
    }

    /// First shift with resolved times, compact short-time range; `·+n` when more than one shift that day.
    private func partnerCompactShiftTimeCaption(work: [PartnerScheduleSnapshot.WorkSegment], day: Date) -> String? {
        guard let head = work.first(where: { $0.startMinutesFromMidnight != nil && $0.endMinutesFromMidnight != nil }) else {
            return nil
        }
        let cal = ScheduleSharingScheduleExporter.gridCalendar
        let dayStart = cal.startOfDay(for: day)
        guard var line = head.compactShiftTimeRangeLine(
            dayStart: dayStart,
            calendar: cal,
            locale: LocalizationManager.shared.currentLocale
        ) else { return nil }
        if work.count > 1 {
            line += "·+\(work.count - 1)"
        }
        return line
    }

    private func partnerShiftMicroRow(work: [PartnerScheduleSnapshot.WorkSegment]) -> some View {
        let maxSeg = 3
        let segCount = min(maxSeg, max(work.count, 0))
        let overflow = max(0, work.count - maxSeg)
        return HStack(spacing: 3) {
            if work.isEmpty {
                Color.clear.frame(height: 4)
            } else {
                HStack(spacing: 1) {
                    ForEach(Array(work.prefix(segCount).enumerated()), id: \.offset) { _, seg in
                        let color = partnerScheduleSegmentColor(hex: seg.colorHex)
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(color.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                    .strokeBorder(color.opacity(0.92), lineWidth: 0.75)
                            )
                    }
                }
                .frame(height: 4)
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.system(size: 6, weight: .bold, design: .rounded))
                        .foregroundColor(AppColorTheme.textSecondary)
                        .fixedSize()
                }
            }
        }
    }

    private func partnerEventsMicroRow(totalEvents: Int) -> some View {
        HStack(spacing: 3) {
            if totalEvents == 0 {
                Color.clear.frame(height: 4)
            } else {
                let dotCount = min(3, totalEvents)
                HStack(spacing: 2) {
                    ForEach(0..<dotCount, id: \.self) { _ in
                        Circle()
                            .fill(AppColorTheme.sapphire.opacity(0.88))
                            .frame(width: 4, height: 4)
                    }
                }
                if totalEvents > 3 {
                    Text("+\(totalEvents - 3)")
                        .font(.system(size: 6, weight: .bold, design: .rounded))
                        .foregroundColor(AppColorTheme.textSecondary)
                        .fixedSize()
                }
            }
        }
    }
    
    private func workSegmentMicroBar(for workDays: [WorkDay]) -> some View {
        let maxSeg = 3
        let count = workDays.count
        let segCount = min(maxSeg, max(count, 0))
        let overflow = max(0, count - maxSeg)
        return HStack(spacing: 3) {
            HStack(spacing: 1) {
                ForEach(0..<segCount, id: \.self) { i in
                    let wd = workDays[i]
                    let color = workScheduleService.job(withId: wd.jobId)?.color ?? AppColorTheme.accent
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(color.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                .strokeBorder(color.opacity(0.92), lineWidth: 0.75)
                        )
                }
            }
            .frame(height: 4)
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 6, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .fixedSize()
            }
        }
    }
    
    private func scheduleDayAccessibility(
        date: Date,
        isCurrentMonth: Bool,
        workDays: [WorkDay],
        personal: [PersonalScheduleEvent],
        partnerBucket: PartnerScheduleSnapshot.DayBucket?,
        composerOpenForThisDay: Bool
    ) -> (label: String, hint: String) {
        guard isCurrentMonth else {
            return ("", "")
        }
        let dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .full
        dayFormatter.locale = LocalizationManager.shared.currentLocale
        let dayStr = dayFormatter.string(from: date)
        var parts: [String] = [dayStr]
        if shareViewModel.isReadOnlySharedContext, let b = partnerBucket, partnerDayHasVisibleItems(bucket: b) {
            let n = b.work.count + b.displayablePersonalEventCount
            parts.append(String(format: L10n("schedule.share.a11y.partner_entry_count"), n))
            if let seg = b.work.first(where: { $0.startMinutesFromMidnight != nil && $0.endMinutesFromMidnight != nil }),
               let range = seg.shiftTimeRangeLine(
                dayStart: viewModel.calendar.startOfDay(for: date),
                calendar: ScheduleSharingScheduleExporter.gridCalendar,
                locale: LocalizationManager.shared.currentLocale
               ) {
                parts.append(range)
            }
        }
        if !workDays.isEmpty {
            parts.append(String(format: L10n("schedule.a11y.work_count"), workDays.count))
        }
        if !personal.isEmpty {
            parts.append(String(format: L10n("schedule.a11y.event_count"), personal.count))
        }
        if composerOpenForThisDay {
            parts.append(L10n("schedule.a11y.composer_open"))
        }
        let label = parts.joined(separator: ", ")
        let hint = shareViewModel.isReadOnlySharedContext
            ? L10n("schedule.share.a11y.partner_day_hint")
            : L10n("schedule.a11y.day_cell_hint")
        return (label, hint)
    }
    
    private func generateCalendarDays(for month: Date) -> [Date] {
        let calendar = viewModel.calendar
        guard let firstDayOfMonth = calendar.dateInterval(of: .month, for: month)?.start else {
            return []
        }
        // Week starts on Monday: weekday 1=Sun..7=Sat → Monday before or on 1st
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysToSubtract = (firstWeekday + 5) % 7
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfMonth) else {
            return []
        }
        
        var days: [Date] = []
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private var summarySection: some View {
        DisclosureGroup(isExpanded: $summaryExpanded) {
            VStack(spacing: 16) {
                summaryRow(
                    title: L10n("work.total_hours"),
                    value: formatHours(viewModel.totalHours),
                    icon: "clock.fill",
                    color: AppColorTheme.accent
                )
                
                Divider()
                    .background(AppColorTheme.grayDark.opacity(0.3))
                
                summaryRow(
                    title: L10n("work.estimated_salary"),
                    value: formatSummarySalary(viewModel.estimatedSalary),
                    icon: "dollarsign.circle.fill",
                    color: AppColorTheme.accent
                )
                
                // Hours per job (when multiple jobs)
                if workScheduleService.jobs.count >= 2 {
                    ForEach(workScheduleService.jobs) { job in
                        Divider()
                            .background(AppColorTheme.grayDark.opacity(0.3))
                        
                        summaryRow(
                            title: job.name,
                            value: formatHours(workScheduleService.totalHoursForMonth(viewModel.selectedMonth, jobId: job.id)),
                            icon: "briefcase.fill",
                            color: job.color
                        )
                    }
                }
            }
            .padding(.top, AppSpacing.m)
            .padding()
            .background(
                LinearGradient(
                    colors: [AppColorTheme.elevatedBackground, AppColorTheme.elevatedBackground.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        } label: {
            Text(L10n("work.summary"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
        }
        .tint(AppColorTheme.accent)
        .padding(AppSpacing.m)
        .background(
            LinearGradient(
                colors: [AppColorTheme.cardBackground, AppColorTheme.cardBackground.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    /// Formats hours: whole numbers without ".0" (e.g. "102 h"), decimals with one place (e.g. "8.5 h")
    private func formatHours(_ hours: Double) -> String {
        if hours == floor(hours) {
            return String(format: "%.0f", hours) + " " + L10n("work.hours_short")
        } else {
            return String(format: "%.1f", hours) + " " + L10n("work.hours_short")
        }
    }
    
    /// Estimated salary: full format for smaller amounts, compact (e.g. 23.6k PLN) when large so the summary layout doesn’t break.
    private func formatSummarySalary(_ amount: Double) -> String {
        let currency = userProfileService.profile.currency
        if abs(amount) >= 10_000 {
            return CurrencyFormatter.formatCompact(amount, currencyCode: currency)
        }
        return CurrencyFormatter.formatWithSymbol(amount, currencyCode: currency)
    }
    
    private func summaryRow(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 32)
            
            Text(title)
                .foregroundColor(AppColorTheme.textSecondary)
                .font(.subheadline)
            
            Spacer(minLength: 8)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppColorTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    /// Salary projection folded by default (Option A: collapsible) to avoid three large blocks above the fold.
    private var salaryProjectionDisclosure: some View {
        DisclosureGroup(isExpanded: $salaryProjectionExpanded) {
            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text(String(format: L10n("schedule.projection_based_on_shifts"), viewModel.scheduledShiftCountForSelectedMonth))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                salaryProjectionCardBody
            }
        } label: {
            Text(L10n("work.salary_projection"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
        }
        .tint(AppColorTheme.accent)
        .padding(AppSpacing.m)
        .background(
            LinearGradient(
                colors: [AppColorTheme.cardBackground, AppColorTheme.cardBackground.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    private var salaryProjectionCardBody: some View {
        VStack(spacing: AppSpacing.m) {
            if viewModel.projectedPayments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                        .foregroundColor(AppColorTheme.textTertiary)
                    
                    Text(L10n("work.no_payments_scheduled"))
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    LinearGradient(
                        colors: [AppColorTheme.elevatedBackground, AppColorTheme.elevatedBackground.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.projectedPayments) { payment in
                        paymentRow(payment: payment)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [AppColorTheme.elevatedBackground, AppColorTheme.elevatedBackground.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
            }
        }
        .padding(.top, AppSpacing.s)
    }
    
    private func paymentRow(payment: WorkScheduleViewModel.ProjectedPayment) -> some View {
        HStack(spacing: 16) {
            // Color indicator
            Circle()
                .fill(payment.jobColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(payment.jobName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Text(paymentDateDescription(payment.date))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            
            Spacer()
            
            Text(CurrencyFormatter.formatWithSymbol(
                payment.amount,
                currencyCode: userProfileService.profile.currency
            ))
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(payment.jobColor)
        }
        .padding(.vertical, 8)
    }
    
    private func paymentDateDescription(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            formatter.dateFormat = "MMM d"
            formatter.locale = LocalizationManager.shared.currentLocale
            return formatter.string(from: date)
        }
    }
    
    private func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private var shareCalendarSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        showingShareInviteComposer = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColorTheme.textPrimary)
                            .padding(10)
                            .background(AppColorTheme.elevatedBackground)
                            .clipShape(Circle())
                    }
                    Spacer()
                    if shareViewModel.partnership == nil,
                       shareViewModel.outgoingInvite == nil {
                        Button(L10n("schedule.share.management.create")) {
                            shareViewModel.isShowingShareOptionsSheet = true
                        }
                        .disabled(!shareViewModel.validateRecipientName(shareViewModel.nameInput))
                        .opacity(shareViewModel.validateRecipientName(shareViewModel.nameInput) ? 1 : 0.45)
                        .foregroundColor(AppColorTheme.accent)
                        .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n("schedule.share.management.title"))
                            .font(.title2.weight(.bold))
                            .foregroundColor(AppColorTheme.textPrimary)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n("schedule.share.management.your_name_label"))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppColorTheme.textSecondary)
                            TextField(L10n("schedule.share.management.your_name_placeholder"), text: $shareViewModel.nameInput)
                                .focused($shareNameFieldFocused)
                                .disabled(shareViewModel.partnership != nil || shareViewModel.outgoingInvite != nil)
                                .padding(12)
                                .background(AppColorTheme.elevatedBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            if shareViewModel.partnership != nil || shareViewModel.outgoingInvite != nil {
                                Text(L10n("schedule.share.management.name_locked_hint"))
                                    .font(.caption2)
                                    .foregroundColor(AppColorTheme.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let p = shareViewModel.partnership {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(String(format: L10n("schedule.share.management.paired_with"), p.partnerDisplayName))
                                    .font(.headline)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                Text(L10n("schedule.share.management.paired_detail"))
                                    .font(.subheadline)
                                    .foregroundColor(AppColorTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button {
                                    Task { await shareViewModel.stopSharing() }
                                } label: {
                                    Text(L10n("schedule.share.stop_sharing"))
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(AppColorTheme.negative.opacity(0.18))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .padding(AppSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColorTheme.cardBackground.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else if let invite = shareViewModel.outgoingInvite {
                            Text(L10n("schedule.share.management.link_active_title"))
                                .font(.headline)
                                .foregroundColor(AppColorTheme.textPrimary)
                            ActiveInviteCard(
                                invite: invite,
                                copied: shareViewModel.copyFeedbackToken == invite.token,
                                onCopy: {
                                    UIPasteboard.general.string = invite.inviteURL.absoluteString
                                    shareViewModel.markCopied(token: invite.token)
                                },
                                onStop: {
                                    Task { await shareViewModel.revokeOutgoingInvite() }
                                }
                            )
                            Text(L10n("schedule.share.management.link_active_footer"))
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ShareIntroView(
                                isCreateEnabled: shareViewModel.validateRecipientName(shareViewModel.nameInput)
                            ) {
                                shareViewModel.isShowingShareOptionsSheet = true
                            }
                        }

                        if let creationError = shareViewModel.inviteCreationErrorMessage {
                            Text(creationError)
                                .font(.caption)
                                .foregroundColor(AppColorTheme.negative)
                        }
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.bottom, AppSpacing.xl)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    shareNameFieldFocused = false
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
            .background(AppColorTheme.background.ignoresSafeArea())
            .sheet(isPresented: $shareViewModel.isShowingShareOptionsSheet) {
                ShareOptionsSheet(
                    selectedItems: Binding(
                        get: { shareViewModel.selectedShareItems },
                        set: { shareViewModel.selectedShareItems = $0 }
                    ),
                    isContinueEnabled: shareViewModel.canContinueShareOptions && shareViewModel.validateRecipientName(shareViewModel.nameInput),
                    isLoading: shareViewModel.isPerformingNetworkAction,
                    duplicateSelectionWarning: shareViewModel.hasDuplicateActiveInviteForSelection
                        ? L10n("schedule.share.error.duplicate_selection")
                        : nil
                ) {
                    Task {
                        let fixedExpiry = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                        await shareViewModel.createInviteFromDraft(expiresAt: fixedExpiry)
                    }
                }
            }
        }
    }

    private func shareErrorMessage(_ state: ShareLinkErrorState?) -> String {
        guard let state else { return L10n("schedule.share.error.unknown") }
        switch state {
        case .invalidLink:
            return L10n("schedule.share.error.invalid")
        case .expired:
            return L10n("schedule.share.error.expired")
        case .revoked:
            return L10n("schedule.share.error.revoked")
        case .declined:
            return L10n("schedule.share.error.declined")
        case .networkFailure:
            return L10n("schedule.share.error.network")
        case .alreadyPaired:
            return L10n("schedule.share.error.already_paired")
        case .inviteDisabledWhilePaired:
            return L10n("schedule.share.error.paired_cannot_create")
        case .activeOutgoingInviteExists:
            return L10n("schedule.share.error.active_link_exists")
        case .peerEndedSharing(let name):
            return String(format: L10n("schedule.share.error.peer_ended"), name)
        case .cannotAcceptOwnInvite:
            return L10n("schedule.share.error.cannot_accept_own")
        case .inviteAlreadyAccepted:
            return L10n("schedule.share.error.invite_already_accepted")
        case .mustStopToSwitchPartner(let partnerName):
            return String(format: L10n("schedule.share.error.switch_partner_first"), partnerName)
        }
    }

}

// MARK: - Identifiable Date Wrapper

/// Wrapper to make Date identifiable for sheet presentation
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

