//
//  WorkDayInputView.swift
//  Friscora
//
//  Bottom sheet view for inputting worked hours with job selection
//

import SwiftUI

/// Earnings preview payload for the schedule composer (hourly estimate, missing rate, or fixed-monthly note).
enum ScheduleWorkEarningsPreviewState: Equatable {
    case none
    case hourlyEstimate(jobId: UUID, hours: Double, amount: Double, shiftLabel: String, timeRange: String)
    case missingHourlyRate(hours: Double, shiftLabel: String, timeRange: String)
    case fixedMonthlyHours(jobId: UUID, hours: Double, shiftLabel: String, timeRange: String)
}

/// Form for adding or editing a work shift on a given day. Embedded in the schedule composer or presented standalone via `WorkDayInputView`.
struct WorkShiftDayForm: View {
    private enum FormAlert: Identifiable {
        case overlap
        case duplicateShift

        var id: Int {
            switch self {
            case .overlap: return 1
            case .duplicateShift: return 2
            }
        }
    }

    let date: Date
    @Binding var selectedDate: IdentifiableDate?
    /// When `true`, omits `NavigationStack`, title, toolbar, and sheet detents (parent provides navigation).
    var embeddedInParentNavigation: Bool = false
    /// When `false`, action buttons scroll with content (for use inside a parent `ScrollView`).
    var stickyBottomActions: Bool = true
    var dismissAfterSave: Bool = true
    var onAfterSave: (() -> Void)? = nil
    /// Select this job when it appears or when the value changes (e.g. user tapped a row in the day list).
    var focusedJobId: UUID? = nil
    /// When `false`, omits the full-screen background so a parent card provides chrome.
    var fillsParentChrome: Bool = true
    /// Called when job/shift selection changes so the parent can show an earnings preview.
    var onEarningsPreviewChange: ((ScheduleWorkEarningsPreviewState) -> Void)? = nil
    /// Opens multi-day bulk apply when job + shift are selected (not custom hours).
    var onApplyToMoreDays: ((UUID, UUID) -> Void)? = nil
    
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @State private var selectedJobId: UUID? = nil
    @State private var selectedShiftId: UUID? = nil
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var showingEditTimeSheet = false
    @State private var editStartMinutes: Int = 9 * 60
    @State private var editEndMinutes: Int = 17 * 60
    /// Per-day time overrides for the selected shift before the main Save (does not change the job’s shift template).
    @State private var pendingCustomStartMinutes: Int? = nil
    @State private var pendingCustomEndMinutes: Int? = nil
    /// After "Edit time" saves times equal to the shift template, we must clear stored per-day overrides on main Save (pending is nil, so this disambiguates from “inherit existing WorkDay”).
    @State private var sessionClearedShiftTimeToTemplate = false
    @State private var isCustomHoursSelected = false
    @State private var activeAlert: FormAlert?
    @State private var forceSaveDespiteOverlap = false
    /// When `false`, the job grid is replaced by a compact row so shift + save stay on screen (composer).
    @State private var showFullJobPicker: Bool = true
    /// When `false`, shift/custom rows collapse to a summary so Save stays visible in the composer.
    @State private var showFullShiftPicker: Bool = true
    
    private var existingWorkDays: [WorkDay] {
        workScheduleService.workDays(for: date)
    }
    
    var body: some View {
        Group {
            if embeddedInParentNavigation {
                formRoot
            } else {
                NavigationStack {
                    formRoot
                        .navigationTitle(L10n("work_hours.title"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(L10n("common.cancel")) {
                                    selectedDate = nil
                                }
                                .foregroundColor(AppColorTheme.textSecondary)
                            }
                        }
                        .presentationDetents([.medium, .large], selection: $sheetDetent)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
    
    private var formScrollContent: some View {
        VStack(spacing: 24) {
            if !embeddedInParentNavigation {
                dateHeader
            }
            
            if !workScheduleService.jobs.isEmpty {
                jobSelectionSection
            }
            
            if selectedJobId != nil {
                shiftSelectionSection
            }
            
            if let applyMore = onApplyToMoreDays,
               let jid = selectedJobId,
               let sid = selectedShiftId,
               !isCustomHoursSelected {
                Button {
                    HapticHelper.lightImpact()
                    applyMore(jid, sid)
                } label: {
                    Text(L10n("schedule.bulk.apply_more_days"))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            
            if shouldShowActionButtons && !stickyBottomActions {
                actionButtons
            }
            
            if shouldShowActionButtons && stickyBottomActions {
                Color.clear.frame(height: 100)
            }
        }
        .padding(.horizontal, embeddedInParentNavigation ? 0 : 20)
        .padding(.top, embeddedInParentNavigation ? 4 : 12)
        .padding(.bottom, stickyBottomActions ? 32 : 16)
    }
    
    private var formRoot: some View {
        ZStack {
            if fillsParentChrome {
                AppColorTheme.background
                    .ignoresSafeArea()
            }
            
            Group {
                if embeddedInParentNavigation {
                    formScrollContent
                } else {
                    ScrollView {
                        formScrollContent
                    }
                    .scrollIndicators(.hidden)
                }
            }
            
            if shouldShowActionButtons && stickyBottomActions {
                VStack {
                    Spacer()
                    actionButtons
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppColorTheme.background.opacity(0.95),
                                    AppColorTheme.cardBackground.opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingEditTimeSheet) {
            editTimeSheet
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .overlap:
                return Alert(
                    title: Text(L10n("schedule.overlap.title")),
                    message: Text(L10n("schedule.overlap.message")),
                    primaryButton: .cancel(Text(L10n("common.cancel"))),
                    secondaryButton: .default(Text(L10n("schedule.overlap.save_anyway"))) {
                        forceSaveDespiteOverlap = true
                        validateAndSaveHours()
                    }
                )
            case .duplicateShift:
                return Alert(
                    title: Text(L10n("schedule.shift_already_added.title")),
                    message: Text(L10n("schedule.shift_already_added.message")),
                    dismissButton: .default(Text(L10n("common.ok")))
                )
            }
        }
        .onAppear {
            applyInitialJobSelection()
            if selectedJobId != nil {
                sheetDetent = .large
                showFullJobPicker = false
            }
            if selectedShiftId != nil || isCustomHoursSelected {
                showFullShiftPicker = false
            }
            publishEarningsPreview()
        }
        .onDisappear {
            onEarningsPreviewChange?(.none)
        }
        .onChange(of: focusedJobId) { _, newId in
            clearPendingShiftTimeOverrides()
            guard let newId, workScheduleService.job(withId: newId) != nil else { return }
            selectedJobId = newId
            if let workDay = existingWorkDays.first(where: { $0.jobId == newId }) {
                selectedShiftId = workDay.shiftId
                isCustomHoursSelected = (workDay.shiftId == nil)
            } else {
                selectedShiftId = nil
                isCustomHoursSelected = false
            }
            sheetDetent = .large
            showFullJobPicker = false
            if selectedShiftId != nil || isCustomHoursSelected {
                showFullShiftPicker = false
            }
            publishEarningsPreview()
        }
        .onChange(of: selectedJobId) { _, newJobId in
            clearPendingShiftTimeOverrides()
            if !embeddedInParentNavigation {
                if newJobId != nil {
                    withAnimation(AppAnimation.workDayExpand) {
                        sheetDetent = .large
                    }
                } else {
                    sheetDetent = .medium
                }
            }
            if newJobId != nil {
                withAnimation(AppAnimation.standard) {
                    showFullJobPicker = false
                }
            } else {
                showFullJobPicker = true
            }
            selectedShiftId = nil
            isCustomHoursSelected = false
            if let id = newJobId, let workDay = existingWorkDays.first(where: { $0.jobId == id }) {
                selectedShiftId = workDay.shiftId
                if workDay.shiftId == nil {
                    isCustomHoursSelected = true
                }
            }
            if selectedShiftId != nil || isCustomHoursSelected {
                withAnimation(AppAnimation.standard) {
                    showFullShiftPicker = false
                }
            } else {
                showFullShiftPicker = true
            }
            publishEarningsPreview()
        }
        .onChange(of: selectedShiftId) { _, _ in
            clearPendingShiftTimeOverrides()
            if selectedShiftId != nil {
                withAnimation(AppAnimation.standard) {
                    showFullShiftPicker = false
                }
            } else if !isCustomHoursSelected {
                showFullShiftPicker = true
            }
            publishEarningsPreview()
        }
        .onChange(of: isCustomHoursSelected) { _, newValue in
            if newValue {
                withAnimation(AppAnimation.standard) {
                    showFullShiftPicker = false
                }
            } else if selectedShiftId == nil {
                showFullShiftPicker = true
            }
            publishEarningsPreview()
        }
    }
    
    private func applyInitialJobSelection() {
        if let focus = focusedJobId, workScheduleService.job(withId: focus) != nil {
            selectedJobId = focus
            if let workDay = existingWorkDays.first(where: { $0.jobId == focus }) {
                selectedShiftId = workDay.shiftId
                isCustomHoursSelected = (workDay.shiftId == nil)
            } else {
                selectedShiftId = nil
                isCustomHoursSelected = false
            }
            return
        }
        if workScheduleService.jobs.count == 1 {
            selectedJobId = workScheduleService.jobs.first?.id
        }
        if let firstWorkDay = existingWorkDays.first {
            selectedJobId = firstWorkDay.jobId
            selectedShiftId = firstWorkDay.shiftId
            isCustomHoursSelected = (firstWorkDay.shiftId == nil)
        } else {
            selectedShiftId = nil
            isCustomHoursSelected = false
        }
    }
    
    private func publishEarningsPreview() {
        guard let onEarningsPreviewChange else { return }
        guard let jobId = selectedJobId, let job = workScheduleService.job(withId: jobId) else {
            onEarningsPreviewChange(.none)
            return
        }
        let shiftReady = selectedShiftId != nil && !isCustomHoursSelected
        let customReady = isCustomHoursSelected && existingWorkDayForSelectedJob != nil
        guard shiftReady || customReady else {
            onEarningsPreviewChange(.none)
            return
        }
        let locale = LocalizationManager.shared.currentLocale
        let hours: Double
        let shiftLabel: String
        let timeRange: String
        if let shift = selectedShift, !isCustomHoursSelected {
            let w = resolvedShiftWindow(for: shift)
            hours = Shift.durationHours(startMinutesFromMidnight: w.start, endMinutesFromMidnight: w.end)
            shiftLabel = shift.name
            timeRange = Shift.timeRangeString(startMinutesFromMidnight: w.start, endMinutesFromMidnight: w.end, locale: locale)
        } else if isCustomHoursSelected, let wd = existingWorkDayForSelectedJob {
            hours = wd.hoursWorked
            shiftLabel = L10n("work_hours.custom_hours")
            timeRange = wd.customTimeRangeString(locale: locale)
                ?? String(format: "%.1f %@", wd.hoursWorked, L10n("work.hours_short"))
        } else {
            onEarningsPreviewChange(.none)
            return
        }
        switch job.paymentType {
        case .hourly:
            let rate = job.hourlyRate ?? 0
            if rate > 0 {
                onEarningsPreviewChange(.hourlyEstimate(
                    jobId: job.id,
                    hours: hours,
                    amount: hours * rate,
                    shiftLabel: shiftLabel,
                    timeRange: timeRange
                ))
            } else {
                onEarningsPreviewChange(.missingHourlyRate(
                    hours: hours,
                    shiftLabel: shiftLabel,
                    timeRange: timeRange
                ))
            }
        case .fixedMonthly:
            onEarningsPreviewChange(.fixedMonthlyHours(
                jobId: job.id,
                hours: hours,
                shiftLabel: shiftLabel,
                timeRange: timeRange
            ))
        }
    }
    
    private var dateHeader: some View {
        VStack(spacing: 6) {
            Text(formatDate(date))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColorTheme.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(formatDayOfWeek(date))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var jobSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n("work_hours.select_job"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer(minLength: 8)
                if selectedJobId != nil, !showFullJobPicker {
                    Button {
                        withAnimation(AppAnimation.standard) {
                            showFullJobPicker = true
                        }
                        HapticHelper.selection()
                    } label: {
                        Text(L10n("work_hours.change_job"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColorTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n("work_hours.change_job"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if selectedJobId == nil || showFullJobPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(workScheduleService.jobs) { job in
                            jobButton(job: job)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } else if let job = selectedJob {
                compactSelectedJobSummary(job: job)
            }
        }
        .padding()
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private func compactSelectedJobSummary(job: Job) -> some View {
        let existingWorkDay = existingWorkDays.first { $0.jobId == job.id }
        let subtitle: String? = {
            guard let wd = existingWorkDay else { return nil }
            if let shiftId = wd.shiftId, let sh = job.shift(withId: shiftId) {
                return "\(sh.name) · \(String(format: "%.1fh", wd.hoursWorked))"
            }
            return String(format: "%.1fh", wd.hoursWorked)
        }()
        return HStack(spacing: 12) {
            Circle()
                .fill(job.color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(AppColorTheme.textPrimary.opacity(0.35), lineWidth: 2)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorTheme.elevatedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(job.name)\(subtitle.map { ", \($0)" } ?? "")")
    }
    
    private func jobButton(job: Job) -> some View {
        let isSelected = selectedJobId == job.id
        let existingWorkDay = existingWorkDays.first { $0.jobId == job.id }
        
        return Button {
            if isSelected, showFullJobPicker {
                withAnimation(AppAnimation.standard) {
                    showFullJobPicker = false
                }
                HapticHelper.selection()
                return
            }
            withAnimation(AppAnimation.standard) {
                selectedJobId = job.id
                if let workDay = existingWorkDay {
                    selectedShiftId = workDay.shiftId
                    isCustomHoursSelected = (workDay.shiftId == nil)
                } else {
                    selectedShiftId = nil
                    isCustomHoursSelected = false
                }
                showFullJobPicker = false
            }
            HapticHelper.selection()
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(job.color)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? AppColorTheme.textPrimary : Color.clear, lineWidth: 3)
                    )
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                
                Text(job.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 80)
                
                // Reserve fixed height for subtitle so all job cards match
                Group {
                    if let wd = existingWorkDay {
                        if let shiftId = wd.shiftId, let shift = job.shift(withId: shiftId) {
                            Text("\(shift.name) · \(String(format: "%.1fh", wd.hoursWorked))")
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        } else {
                            Text(String(format: "%.1fh", wd.hoursWorked))
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                    } else {
                        Text(" ")
                            .font(.caption)
                            .opacity(0)
                    }
                }
                .frame(height: 14)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .padding(.horizontal, 16)
            .background(
                isSelected
                    ? job.color.opacity(0.2)
                    : AppColorTheme.elevatedBackground
            )
            .cornerRadius(12)
        }
    }
    
    private var selectedJob: Job? {
        guard let jobId = selectedJobId else { return nil }
        return workScheduleService.job(withId: jobId)
    }
    
    private var selectedShift: Shift? {
        guard let job = selectedJob, let shiftId = selectedShiftId else { return nil }
        return job.shift(withId: shiftId)
    }
    
    private var shouldShowActionButtons: Bool {
        guard selectedJobId != nil else { return false }
        return selectedShiftId != nil || isCustomHoursSelected
    }
    
    private var existingWorkDayForSelectedJob: WorkDay? {
        guard let jobId = selectedJobId else { return nil }
        return existingWorkDays.first { $0.jobId == jobId }
    }
    
    /// Effective start/end minutes for a shift row (pending + per-day overrides apply only when this shift is selected).
    private func resolvedShiftWindow(for shift: Shift) -> (start: Int, end: Int) {
        guard shift.id == selectedShiftId else {
            return (shift.startMinutesFromMidnight, shift.endMinutesFromMidnight)
        }
        if sessionClearedShiftTimeToTemplate {
            return (shift.startMinutesFromMidnight, shift.endMinutesFromMidnight)
        }
        if let ps = pendingCustomStartMinutes, let pe = pendingCustomEndMinutes {
            return (ps, pe)
        }
        if let wd = existingWorkDayForSelectedJob, wd.shiftId == shift.id,
           let cs = wd.customStartMinutesFromMidnight, let ce = wd.customEndMinutesFromMidnight {
            return (cs, ce)
        }
        return (shift.startMinutesFromMidnight, shift.endMinutesFromMidnight)
    }
    
    private func resolvedHoursForSelectedShift() -> Double {
        guard let shift = selectedShift else { return 0 }
        let w = resolvedShiftWindow(for: shift)
        return Shift.durationHours(startMinutesFromMidnight: w.start, endMinutesFromMidnight: w.end)
    }
    
    private func clearPendingShiftTimeOverrides() {
        pendingCustomStartMinutes = nil
        pendingCustomEndMinutes = nil
        sessionClearedShiftTimeToTemplate = false
    }
    
    private var hasExistingWorkWithoutShift: Bool {
        guard let jobId = selectedJobId else { return false }
        return existingWorkDays.contains { $0.jobId == jobId && $0.shiftId == nil }
    }
    
    private var hasShiftSelection: Bool {
        selectedShiftId != nil || isCustomHoursSelected
    }
    
    private var shiftSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n("work_hours.select_shift"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer(minLength: 8)
                if hasShiftSelection, !showFullShiftPicker {
                    Button {
                        withAnimation(AppAnimation.standard) {
                            showFullShiftPicker = true
                        }
                        HapticHelper.selection()
                    } label: {
                        Text(L10n("work_hours.change_shift"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColorTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n("work_hours.change_shift"))
                }
                if let job = selectedJob {
                    Button {
                        onAddNewShiftFromWorkHours(job: job)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                    }
                    .accessibilityLabel(L10n("work_hours.add_shift_a11y"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let job = selectedJob, job.shifts.isEmpty {
                Button {
                    onAddNewShiftFromWorkHours(job: job)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                        Text(L10n("work_hours.no_shifts_add"))
                            .font(.subheadline)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(AppColorTheme.elevatedBackground)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            } else if hasShiftSelection, !showFullShiftPicker {
                compactSelectedShiftSummary
            } else {
                shiftPickerExpandedContent
                
                if showFullShiftPicker || !hasShiftSelection {
                    shiftExpandedTimeEditLinks
                }
            }
        }
        .padding()
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    /// Large shift / custom rows (same as before collapse).
    private var shiftPickerExpandedContent: some View {
        VStack(spacing: 10) {
            if hasExistingWorkWithoutShift, let workDay = existingWorkDayForSelectedJob, workDay.shiftId == nil {
                let showOnlyCustom = isCustomHoursSelected
                let showCustomRow = showOnlyCustom || (selectedShiftId == nil)
                if showCustomRow {
                    let isSelected = isCustomHoursSelected
                    Button {
                        if isSelected, showFullShiftPicker {
                            withAnimation(AppAnimation.standard) {
                                showFullShiftPicker = false
                            }
                            HapticHelper.selection()
                            return
                        }
                        withAnimation(AppAnimation.standard) {
                            if isSelected {
                                isCustomHoursSelected = false
                            } else {
                                isCustomHoursSelected = true
                                selectedShiftId = nil
                                showFullShiftPicker = false
                            }
                        }
                        HapticHelper.selection()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n("work_hours.custom_hours"))
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                Text(String(format: "%.1f %@", workDay.hoursWorked, L10n("work_hours.hours_unit")))
                                    .font(.caption)
                                    .foregroundColor(AppColorTheme.textSecondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "chevron.up.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                                    .symbolRenderingMode(.hierarchical)
                            } else {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                                ? (selectedJob?.color ?? AppColorTheme.accent).opacity(0.2)
                                : AppColorTheme.elevatedBackground
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? (selectedJob?.color ?? AppColorTheme.accent) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            let shiftsToShow: [Shift] = {
                guard let job = selectedJob else { return [] }
                if let sid = selectedShiftId, let s = job.shift(withId: sid) {
                    return [s]
                }
                return job.shifts
            }()
            if !isCustomHoursSelected {
                ForEach(shiftsToShow, id: \.id) { shift in
                    let isSelected = selectedShiftId == shift.id
                    let rowWindow = resolvedShiftWindow(for: shift)
                    let rowHours = Shift.durationHours(startMinutesFromMidnight: rowWindow.start, endMinutesFromMidnight: rowWindow.end)
                    Button {
                        if isSelected, showFullShiftPicker {
                            withAnimation(AppAnimation.standard) {
                                showFullShiftPicker = false
                            }
                            HapticHelper.selection()
                            return
                        }
                        withAnimation(AppAnimation.standard) {
                            if isSelected {
                                selectedShiftId = nil
                            } else {
                                selectedShiftId = shift.id
                                isCustomHoursSelected = false
                                showFullShiftPicker = false
                            }
                        }
                        HapticHelper.selection()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(shift.name)
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                Text(Shift.timeRangeString(startMinutesFromMidnight: rowWindow.start, endMinutesFromMidnight: rowWindow.end, locale: LocalizationManager.shared.currentLocale))
                                    .font(.caption)
                                    .foregroundColor(AppColorTheme.textSecondary)
                                Text(String(format: "%.1f %@", rowHours, L10n("work_hours.hours_unit")))
                                    .font(.caption2)
                                    .foregroundColor(AppColorTheme.textTertiary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "chevron.up.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                                    .symbolRenderingMode(.hierarchical)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            isSelected
                                ? (selectedJob?.color ?? AppColorTheme.accent).opacity(0.2)
                                : AppColorTheme.elevatedBackground
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? (selectedJob?.color ?? AppColorTheme.accent) : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    @ViewBuilder
    private var shiftExpandedTimeEditLinks: some View {
        if let shift = selectedShift, !isCustomHoursSelected {
            let locale = LocalizationManager.shared.currentLocale
            let w = resolvedShiftWindow(for: shift)
            let timeRangeText = Shift.timeRangeString(startMinutesFromMidnight: w.start, endMinutesFromMidnight: w.end, locale: locale)
            Button {
                editStartMinutes = pendingCustomStartMinutes ?? existingWorkDayForSelectedJob?.customStartMinutesFromMidnight ?? shift.startMinutesFromMidnight
                editEndMinutes = pendingCustomEndMinutes ?? existingWorkDayForSelectedJob?.customEndMinutesFromMidnight ?? shift.endMinutesFromMidnight
                showingEditTimeSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text(timeRangeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n("work_hours.edit_time"))
        } else if isCustomHoursSelected, let workDay = existingWorkDayForSelectedJob {
            let timeRangeText = workDay.customTimeRangeString(locale: LocalizationManager.shared.currentLocale)
                ?? String(format: "%.1f %@", workDay.hoursWorked, L10n("work_hours.hours_unit"))
            Button {
                let defaultStart = 9 * 60
                let defaultEnd = 17 * 60
                editStartMinutes = workDay.customStartMinutesFromMidnight ?? defaultStart
                editEndMinutes = workDay.customEndMinutesFromMidnight ?? defaultEnd
                showingEditTimeSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text(timeRangeText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                    Image(systemName: "pencil.circle.fill")
                        .font(.caption)
                        .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n("work_hours.edit_time"))
        }
    }
    
    @ViewBuilder
    private var compactSelectedShiftSummary: some View {
        if let job = selectedJob, let shift = selectedShift, !isCustomHoursSelected {
            let locale = LocalizationManager.shared.currentLocale
            let w = resolvedShiftWindow(for: shift)
            let timeRangeText = Shift.timeRangeString(startMinutesFromMidnight: w.start, endMinutesFromMidnight: w.end, locale: locale)
            let hoursLine = String(format: "%.1f %@", resolvedHoursForSelectedShift(), L10n("work_hours.hours_unit"))
            Button {
                editStartMinutes = pendingCustomStartMinutes ?? existingWorkDayForSelectedJob?.customStartMinutesFromMidnight ?? shift.startMinutesFromMidnight
                editEndMinutes = pendingCustomEndMinutes ?? existingWorkDayForSelectedJob?.customEndMinutesFromMidnight ?? shift.endMinutesFromMidnight
                showingEditTimeSheet = true
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(job.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(AppColorTheme.textPrimary.opacity(0.35), lineWidth: 2)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColorTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(timeRangeText) · \(hoursLine)")
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(job.color)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColorTheme.elevatedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(L10n("work_hours.edit_time"))
        } else if isCustomHoursSelected, let workDay = existingWorkDayForSelectedJob, let job = selectedJob {
            let timeRangeText = workDay.customTimeRangeString(locale: LocalizationManager.shared.currentLocale)
                ?? String(format: "%.1f %@", workDay.hoursWorked, L10n("work_hours.hours_unit"))
            Button {
                let defaultStart = 9 * 60
                let defaultEnd = 17 * 60
                editStartMinutes = workDay.customStartMinutesFromMidnight ?? defaultStart
                editEndMinutes = workDay.customEndMinutesFromMidnight ?? defaultEnd
                showingEditTimeSheet = true
            } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(job.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(AppColorTheme.textPrimary.opacity(0.35), lineWidth: 2)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n("work_hours.custom_hours"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColorTheme.textPrimary)
                            .lineLimit(1)
                        Text(timeRangeText)
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(job.color)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColorTheme.elevatedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(L10n("work_hours.edit_time"))
        }
    }
    
    private func onAddNewShiftFromWorkHours(job: Job) {
        // Present a minimal add-shift flow: we need to add a shift to the job and persist.
        // WorkScheduleService has updateJob; we can append a new shift and update.
        let defaultStart = 9 * 60
        let defaultEnd = 17 * 60
        var updatedShifts = job.shifts
        updatedShifts.append(Shift(name: L10n("shift.morning"), startMinutesFromMidnight: defaultStart, endMinutesFromMidnight: defaultEnd))
        var updatedJob = job
        updatedJob.shifts = updatedShifts
        workScheduleService.updateJob(updatedJob)
        selectedShiftId = updatedShifts.last?.id
        isCustomHoursSelected = false
        showFullShiftPicker = false
        HapticHelper.selection()
    }
    
    private var editTimeSheet: some View {
        let startBinding = Binding(
            get: { dateFromMinutes(editStartMinutes) },
            set: { editStartMinutes = minutesFromDate($0) }
        )
        let endBinding = Binding(
            get: { dateFromMinutes(editEndMinutes) },
            set: { editEndMinutes = minutesFromDate($0) }
        )
        let accent = selectedJob?.color ?? AppColorTheme.accent
        return NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    // Compact card: two rows, Start and End with compact time pickers (tap to open system picker)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Text(L10n("shift.start_time"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textSecondary)
                                .frame(width: 56, alignment: .leading)
                            DatePicker("", selection: startBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                        HStack(spacing: 12) {
                            Text(L10n("shift.end_time"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(AppColorTheme.textSecondary)
                                .frame(width: 56, alignment: .leading)
                            DatePicker("", selection: endBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(accent)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(AppColorTheme.elevatedBackground)
                        .cornerRadius(12)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(AppColorTheme.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    Spacer(minLength: 0)
                }
            }
            .navigationTitle(L10n("work_hours.edit_time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        showingEditTimeSheet = false
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        saveCustomTimeRange()
                        showingEditTimeSheet = false
                    }
                    .foregroundColor(accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }
    
    private func saveCustomTimeRange() {
        if isCustomHoursSelected, var wd = existingWorkDayForSelectedJob {
            let h = Shift.durationHours(startMinutesFromMidnight: editStartMinutes, endMinutesFromMidnight: editEndMinutes)
            wd.hoursWorked = h
            wd.customStartMinutesFromMidnight = editStartMinutes
            wd.customEndMinutesFromMidnight = editEndMinutes
            wd.patternId = nil
            workScheduleService.addOrUpdateWorkDay(wd)
            HapticHelper.mediumImpact()
            publishEarningsPreview()
            return
        }
        guard let shift = selectedShift else { return }
        if editStartMinutes == shift.startMinutesFromMidnight && editEndMinutes == shift.endMinutesFromMidnight {
            pendingCustomStartMinutes = nil
            pendingCustomEndMinutes = nil
            sessionClearedShiftTimeToTemplate = true
        } else {
            pendingCustomStartMinutes = editStartMinutes
            pendingCustomEndMinutes = editEndMinutes
            sessionClearedShiftTimeToTemplate = false
        }
        HapticHelper.mediumImpact()
        publishEarningsPreview()
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            let isEditingExisting = existingWorkDays.contains(where: { $0.jobId == selectedJobId })
            // Save button
            Button {
                validateAndSaveHours()
            } label: {
                Text(isEditingExisting ? L10n("common.save") : L10n("schedule.composer.add_shift"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedJob?.color ?? AppColorTheme.accent)
                    .cornerRadius(16)
            }
            
            // Delete button (if existing)
            if existingWorkDays.contains(where: { $0.jobId == selectedJobId }) {
                Button {
                    deleteHours()
                } label: {
                    Text(L10n("common.delete"))
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.negative)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColorTheme.negative.opacity(0.15))
                        .cornerRadius(16)
                }
            }
        }
    }
    
    private func validateAndSaveHours() {
        guard let jobId = selectedJobId else { return }
        
        let hours: Double
        let shiftId: UUID?
        var customStart: Int?
        var customEnd: Int?
        
        if let shift = selectedShift, !isCustomHoursSelected {
            shiftId = shift.id
            if sessionClearedShiftTimeToTemplate {
                customStart = nil
                customEnd = nil
            } else if let ps = pendingCustomStartMinutes, let pe = pendingCustomEndMinutes {
                if ps == shift.startMinutesFromMidnight && pe == shift.endMinutesFromMidnight {
                    customStart = nil
                    customEnd = nil
                } else {
                    customStart = ps
                    customEnd = pe
                }
            } else if let wd = existingWorkDayForSelectedJob, wd.shiftId == shift.id {
                customStart = wd.customStartMinutesFromMidnight
                customEnd = wd.customEndMinutesFromMidnight
            }
            if let cs = customStart, let ce = customEnd,
               cs == shift.startMinutesFromMidnight && ce == shift.endMinutesFromMidnight {
                customStart = nil
                customEnd = nil
            }
            if let cs = customStart, let ce = customEnd {
                hours = Shift.durationHours(startMinutesFromMidnight: cs, endMinutesFromMidnight: ce)
            } else {
                hours = shift.durationHours
            }
        } else if isCustomHoursSelected, let workDay = existingWorkDayForSelectedJob {
            hours = workDay.hoursWorked
            shiftId = nil
            customStart = workDay.customStartMinutesFromMidnight
            customEnd = workDay.customEndMinutesFromMidnight
        } else {
            return
        }
        
        let toSave = WorkDay(
            id: existingWorkDayForSelectedJob?.id ?? UUID(),
            date: date,
            hoursWorked: hours,
            jobId: jobId,
            shiftId: shiftId,
            customStartMinutesFromMidnight: customStart,
            customEndMinutesFromMidnight: customEnd,
            bulkOperationId: existingWorkDayForSelectedJob?.bulkOperationId,
            patternId: nil
        )

        if let existing = existingWorkDayForSelectedJob,
           existing.shiftId == toSave.shiftId,
           existing.customStartMinutesFromMidnight == toSave.customStartMinutesFromMidnight,
           existing.customEndMinutesFromMidnight == toSave.customEndMinutesFromMidnight,
           abs(existing.hoursWorked - toSave.hoursWorked) < 0.0001 {
            activeAlert = .duplicateShift
            return
        }
        
        if !forceSaveDespiteOverlap,
           let interval = absoluteIntervalForSave(jobId: jobId, shiftId: shiftId, customStart: customStart, customEnd: customEnd) {
            let ignoreId = existingWorkDayForSelectedJob?.id
            if workScheduleService.hasScheduleOverlap(
                on: date,
                proposedStart: interval.start,
                proposedEnd: interval.end,
                ignoringWorkDayId: ignoreId
            ) {
                activeAlert = .overlap
                return
            }
        }
        forceSaveDespiteOverlap = false
        
        workScheduleService.addOrUpdateWorkDay(toSave)
        clearPendingShiftTimeOverrides()
        
        HapticHelper.mediumImpact()
        publishEarningsPreview()
        onAfterSave?()
        if dismissAfterSave {
            selectedDate = nil
        }
    }
    
    private func absoluteIntervalForSave(
        jobId: UUID,
        shiftId: UUID?,
        customStart: Int?,
        customEnd: Int?
    ) -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        if let cs = customStart, let ce = customEnd {
            guard let s = cal.date(byAdding: .minute, value: cs, to: day),
                  var e = cal.date(byAdding: .minute, value: ce, to: day) else { return nil }
            if e <= s { e = cal.date(byAdding: .day, value: 1, to: e) ?? e }
            return (s, e)
        }
        if let sid = shiftId, let job = workScheduleService.job(withId: jobId), let shift = job.shift(withId: sid) {
            guard let s = cal.date(byAdding: .minute, value: shift.startMinutesFromMidnight, to: day),
                  var e = cal.date(byAdding: .minute, value: shift.endMinutesFromMidnight, to: day) else { return nil }
            if e <= s { e = cal.date(byAdding: .day, value: 1, to: e) ?? e }
            return (s, e)
        }
        guard let next = cal.date(byAdding: .day, value: 1, to: day) else { return nil }
        return (day, next)
    }
    
    private func deleteHours() {
        guard let jobId = selectedJobId,
              let workDay = existingWorkDays.first(where: { $0.jobId == jobId }) else { return }
        
        workScheduleService.deleteWorkDay(workDay)
        HapticHelper.mediumImpact()
        publishEarningsPreview()
        onAfterSave?()
        if dismissAfterSave {
            selectedDate = nil
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter.string(from: date)
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter.string(from: date)
    }
}

// MARK: - Standalone sheet wrapper

struct WorkDayInputView: View {
    let date: Date
    @Binding var selectedDate: IdentifiableDate?
    
    var body: some View {
        WorkShiftDayForm(date: date, selectedDate: $selectedDate)
    }
}
