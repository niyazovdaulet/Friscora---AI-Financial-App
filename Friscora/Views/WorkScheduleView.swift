//
//  WorkScheduleView.swift
//  Friscora
//
//  Schedule tab: work shifts and personal events on one calendar; pay tools stay work-only.
//

import SwiftUI

struct ScheduleView: View {
    @StateObject private var viewModel = WorkScheduleViewModel()
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    /// Start-of-day when the Shift Composer is open; `nil` when closed. Same-day tap toggles close.
    @State private var composerDay: Date? = nil
    @State private var composerStage: ScheduleComposerStage = .collapsed
    @AccessibilityFocusState private var composerAccessibilityFocused: Bool
    @State private var showingSettings = false
    @State private var showingNewJob = false
    @State private var showingClearConfirmation = false
    /// Collapsed by default so the calendar stays the visual focus; projection stays one tap away.
    @State private var salaryProjectionExpanded = false
    
    /// Months to show in horizontal calendar (24 back, current, 24 forward)
    private var calendarMonths: [Date] {
        let cal = viewModel.calendar
        guard let startOfCurrent = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return [] }
        return (-24..<25).compactMap { cal.date(byAdding: .month, value: $0, to: startOfCurrent) }
    }
    
    /// Index of the currently selected month in calendarMonths
    @State private var selectedMonthIndex: Int = 24
    
    /// Check if current month has any work days
    private var hasWorkDaysInMonth: Bool {
        let workDays = workScheduleService.workDays.filter { workDay in
            viewModel.calendar.isDate(workDay.date, equalTo: viewModel.selectedMonth, toGranularity: .month)
        }
        return !workDays.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
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

                        if workScheduleService.hasJobs {
                            summarySection
                                .padding(.horizontal, AppSpacing.l)

                            salaryProjectionDisclosure
                                .padding(.horizontal, AppSpacing.l)
                        } else {
                            scheduleNoJobsForecastNote
                                .padding(.horizontal, AppSpacing.l)
                        }
                    }
                    .padding(.vertical, AppSpacing.m)
                }
                .scrollIndicators(.hidden, axes: .vertical)
                .allowsHitTesting(composerDay == nil)
                
                if let day = composerDay,
                   viewModel.calendar.isDate(day, equalTo: viewModel.selectedMonth, toGranularity: .month) {
                    scheduleComposerDimmerAndCard(for: day)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(AppAnimation.inspectorReveal, value: composerDay)
            .navigationTitle(L10n("tab.schedule"))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasWorkDaysInMonth {
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
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(AppColorTheme.accent)
                            .accessibilityLabel(L10n("schedule.toolbar.jobs_a11y"))
                    }
                }
            }
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
            .onAppear {
                SalarySyncService.shared.syncSalaryToIncome()
                // Sync month index with viewModel in case we need to show a specific month
                if selectedMonthIndex >= calendarMonths.count {
                    selectedMonthIndex = max(0, calendarMonths.count - 1)
                }
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
    }
    
    /// Full-screen dimmer + bottom composer. Dimmer sits above the scroll view (month arrows are inactive until the composer is dismissed).
    @ViewBuilder
    private func scheduleComposerDimmerAndCard(for day: Date) -> some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    Rectangle()
                        .fill(AppColorTheme.scheduleComposerBackdropDim)
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
                accessibilityComposerFocused: $composerAccessibilityFocused
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    
    private var horizontalCalendarSection: some View {
        VStack(spacing: 20) {
            // Month name and navigation buttons at the top
            HStack {
                Button {
                    if selectedMonthIndex > 0 {
                        withAnimation(AppAnimation.tabSwitch) {
                            selectedMonthIndex -= 1
                        }
                        impactFeedback(style: .light)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppColorTheme.accent)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                }
                .disabled(selectedMonthIndex <= 0)
                .opacity(selectedMonthIndex <= 0 ? 0.5 : 1)
                
                Spacer()
                
                Text(viewModel.monthString(for: viewModel.selectedMonth))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Spacer()
                
                Button {
                    if selectedMonthIndex < calendarMonths.count - 1 {
                        withAnimation(AppAnimation.tabSwitch) {
                            selectedMonthIndex += 1
                        }
                        impactFeedback(style: .light)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColorTheme.accent)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                }
                .disabled(selectedMonthIndex >= calendarMonths.count - 1)
                .opacity(selectedMonthIndex >= calendarMonths.count - 1 ? 0.5 : 1)
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
            
            TabView(selection: $selectedMonthIndex) {
                ForEach(Array(calendarMonths.enumerated()), id: \.offset) { index, month in
                    calendarSectionForMonth(month)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selectedMonthIndex)
            .frame(height: 400)
            .onChange(of: selectedMonthIndex) { _, newIndex in
                guard newIndex >= 0, newIndex < calendarMonths.count else { return }
                let newMonth = calendarMonths[newIndex]
                if let d = composerDay, !viewModel.calendar.isDate(d, equalTo: newMonth, toGranularity: .month) {
                    withAnimation(AppAnimation.inspectorReveal) {
                        composerDay = nil
                        composerStage = .collapsed
                    }
                }
                viewModel.selectedMonth = newMonth
            }
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
    
    /// Compact context under the month header when a day is selected (mirrors composer stats; uses profile currency).
    private func selectedDayContextSummaryLine(for day: Date) -> String? {
        let work = workScheduleService.workDays(for: day)
        let events = workScheduleService.personalEvents(onSameDayAs: day)
        let count = work.count + events.count
        guard count > 0 else { return nil }
        let hours = work.reduce(0) { $0 + $1.hoursWorked }
        let currency = userProfileService.profile.currency
        var hourlyTotal: Double = 0
        var hasHourlyEstimate = false
        for wd in work {
            guard let job = workScheduleService.job(withId: wd.jobId) else { continue }
            if job.paymentType == .hourly, let r = job.hourlyRate, r > 0 {
                hourlyTotal += wd.hoursWorked * r
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
    
    private func calendarSectionForMonth(_ month: Date) -> some View {
        calendarGrid(for: month)
    }
    
    private func calendarGrid(for month: Date) -> some View {
        VStack(spacing: 12) {
            // Weekday headers (Monday first)
            HStack(spacing: 0) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            let days = generateCalendarDays(for: month)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days, id: \.self) { date in
                    calendarDayView(for: date, inMonth: month)
                }
            }
        }
    }
    
    private func calendarDayView(for date: Date, inMonth month: Date) -> some View {
        let isCurrentMonth = viewModel.calendar.isDate(date, equalTo: month, toGranularity: .month)
        let isToday = viewModel.calendar.isDateInToday(date)
        let workDays = workScheduleService.workDays(for: date)
        let personal = workScheduleService.personalEvents(onSameDayAs: date)
        let hasItems = !workDays.isEmpty || !personal.isEmpty
        let dayNum = viewModel.calendar.component(.day, from: date)
        let isComposerFocusedDay = isCurrentMonth
            && (composerDay.map { viewModel.calendar.isDate($0, inSameDayAs: date) } ?? false)
        let a11y = scheduleDayAccessibility(
            date: date,
            isCurrentMonth: isCurrentMonth,
            workDays: workDays,
            personal: personal,
            composerOpenForThisDay: isComposerFocusedDay
        )
        
        return Button {
            guard isCurrentMonth else { return }
            HapticHelper.selection()
            withAnimation(AppAnimation.inspectorReveal) {
                if let ins = composerDay, viewModel.calendar.isDate(ins, inSameDayAs: date) {
                    composerDay = nil
                    composerStage = .collapsed
                } else {
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
                
                if isCurrentMonth && hasItems {
                    scheduleDayMicroIndicatorRow(workDays: workDays, personal: personal)
                } else {
                    Color.clear.frame(height: 12)
                }
            }
            .frame(width: 44, height: 56)
            .scaleEffect(isComposerFocusedDay ? 1.04 : 1.0)
            .animation(AppAnimation.snappy, value: isComposerFocusedDay)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isComposerFocusedDay ? AppColorTheme.accent.opacity(0.18) : Color.clear)
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
        }
        .disabled(!isCurrentMonth)
        .accessibilityLabel(a11y.label)
        .accessibilityHint(a11y.hint)
    }
    
    /// Work: thin multi-segment bar (stroke + translucent fill). Events: sapphire glyph on elevated pill (distinct from job colors).
    private func scheduleDayMicroIndicatorRow(workDays: [WorkDay], personal: [PersonalScheduleEvent]) -> some View {
        let hasWork = !workDays.isEmpty
        let hasPersonal = !personal.isEmpty
        return HStack(alignment: .center, spacing: 4) {
            if hasWork {
                workSegmentMicroBar(for: workDays)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if hasPersonal {
                Spacer(minLength: 0)
            }
            if hasPersonal {
                personalEventMicroGlyph
            }
        }
        .frame(height: 12)
        .accessibilityElement(children: .ignore)
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
    
    private var personalEventMicroGlyph: some View {
        ZStack {
            Circle()
                .fill(AppColorTheme.elevatedBackground)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .strokeBorder(AppColorTheme.textTertiary.opacity(0.45), lineWidth: 0.5)
                )
            Image(systemName: "calendar")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(AppColorTheme.sapphire)
        }
        .accessibilityHidden(true)
    }
    
    private func scheduleDayAccessibility(
        date: Date,
        isCurrentMonth: Bool,
        workDays: [WorkDay],
        personal: [PersonalScheduleEvent],
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
        let hint = L10n("schedule.a11y.day_cell_hint")
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
        VStack(spacing: AppSpacing.m) {
            HStack {
                Text(L10n("work.summary"))
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
            }
            
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
                
                Text(L10n("schedule.summary_forecast_footer"))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                
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
        .padding()
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
}

// MARK: - Identifiable Date Wrapper

/// Wrapper to make Date identifiable for sheet presentation
struct IdentifiableDate: Identifiable {
    let id = UUID()
    let date: Date
}

