//
//  WorkDayInputView.swift
//  Friscora
//
//  Bottom sheet view for inputting worked hours with job selection
//

import SwiftUI

struct WorkDayInputView: View {
    let date: Date
    @Binding var selectedDate: IdentifiableDate?
    
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @State private var selectedJobId: UUID? = nil
    @State private var selectedShiftId: UUID? = nil
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var showingEditTimeSheet = false
    @State private var editStartMinutes: Int = 9 * 60
    @State private var editEndMinutes: Int = 17 * 60
    @State private var isCustomHoursSelected = false
    
    private var existingWorkDays: [WorkDay] {
        workScheduleService.workDays(for: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Date display
                        dateHeader
                        
                        // Job selection
                        if !workScheduleService.jobs.isEmpty {
                            jobSelectionSection
                        }
                        
                        // Select Shift (only if job selected); user can add a shift if job has none
                        if selectedJobId != nil {
                            shiftSelectionSection
                        }
                        
                        // Bottom padding so content isn't hidden behind sticky Save (task 5)
                        if shouldShowActionButtons {
                            Color.clear.frame(height: 100)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                
                // Sticky Save/Delete at bottom so users don't have to scroll (task 5)
                if shouldShowActionButtons {
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
            .onAppear {
                // If there's only one job, auto-select it
                if workScheduleService.jobs.count == 1 {
                    selectedJobId = workScheduleService.jobs.first?.id
                }
                
                // If there's an existing work day for this date, load it
                if let firstWorkDay = existingWorkDays.first {
                    selectedJobId = firstWorkDay.jobId
                    selectedShiftId = firstWorkDay.shiftId
                    isCustomHoursSelected = (firstWorkDay.shiftId == nil)
                } else {
                    selectedShiftId = nil
                    isCustomHoursSelected = false
                }
                if selectedJobId != nil {
                    sheetDetent = .large
                }
            }
            .onChange(of: selectedJobId) { _, newJobId in
                if newJobId != nil {
                    withAnimation(AppAnimation.workDayExpand) {
                        sheetDetent = .large
                    }
                } else {
                    sheetDetent = .medium
                }
                selectedShiftId = nil
                isCustomHoursSelected = false
                if let id = newJobId, let workDay = existingWorkDays.first(where: { $0.jobId == id }) {
                    selectedShiftId = workDay.shiftId
                    if workDay.shiftId == nil {
                        isCustomHoursSelected = true
                    }
                }
            }
            .sheet(isPresented: $showingEditTimeSheet) {
                editTimeSheet
            }
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
            Text(L10n("work_hours.select_job"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(workScheduleService.jobs) { job in
                        jobButton(job: job)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private func jobButton(job: Job) -> some View {
        let isSelected = selectedJobId == job.id
        let existingWorkDay = existingWorkDays.first { $0.jobId == job.id }
        
        return Button {
            withAnimation(AppAnimation.standard) {
                selectedJobId = job.id
                if let workDay = existingWorkDay {
                    selectedShiftId = workDay.shiftId
                    isCustomHoursSelected = (workDay.shiftId == nil)
                } else {
                    selectedShiftId = nil
                    isCustomHoursSelected = false
                }
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
    
    private var hasExistingWorkWithoutShift: Bool {
        guard let jobId = selectedJobId else { return false }
        return existingWorkDays.contains { $0.jobId == jobId && $0.shiftId == nil }
    }
    
    private var shiftSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text(L10n("work_hours.select_shift"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
                // + button to add new shift without going to Jobs (task 7)
                if let job = selectedJob {
                    Button {
                        onAddNewShiftFromWorkHours(job: job)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(selectedJob?.color ?? AppColorTheme.accent)
                    }
                }
            }
            
            VStack(spacing: 10) {
                // Empty state: job has no shifts — prompt to add one
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
                }
                
                // "Custom" row – existing work day without shift (legacy); user can edit time or add a shift
                if hasExistingWorkWithoutShift, let workDay = existingWorkDayForSelectedJob, workDay.shiftId == nil {
                    let showOnlyCustom = isCustomHoursSelected
                    let showCustomRow = showOnlyCustom || (selectedShiftId == nil)
                    if showCustomRow {
                        let isSelected = isCustomHoursSelected
                        Button {
                            withAnimation(AppAnimation.standard) {
                                if isSelected {
                                    isCustomHoursSelected = false
                                } else {
                                    isCustomHoursSelected = true
                                    selectedShiftId = nil
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
                
                // Shifts: when one selected, show only that row; tap again to unselect. Otherwise show all.
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
                        Button {
                            withAnimation(AppAnimation.standard) {
                                if isSelected {
                                    selectedShiftId = nil
                                } else {
                                    selectedShiftId = shift.id
                                    isCustomHoursSelected = false
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
                                    Text(shift.timeRangeString(locale: LocalizationManager.shared.currentLocale))
                                        .font(.caption)
                                        .foregroundColor(AppColorTheme.textSecondary)
                                    Text(String(format: "%.1f %@", shift.durationHours, L10n("work_hours.hours_unit")))
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
            
            // Clickable time range to edit day-only times (shift or custom hours)
            if let shift = selectedShift, !isCustomHoursSelected {
                let workDay = existingWorkDayForSelectedJob
                let timeRangeText: String = {
                    if let wd = workDay, let custom = wd.customTimeRangeString(locale: LocalizationManager.shared.currentLocale) {
                        return custom
                    }
                    return shift.timeRangeString(locale: LocalizationManager.shared.currentLocale)
                }()
                Button {
                    editStartMinutes = workDay?.customStartMinutesFromMidnight ?? shift.startMinutesFromMidnight
                    editEndMinutes = workDay?.customEndMinutesFromMidnight ?? shift.endMinutesFromMidnight
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
            // Edit time for legacy custom hours (no shift)
            if isCustomHoursSelected, let workDay = existingWorkDayForSelectedJob {
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
        .padding()
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
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
        guard let jobId = selectedJobId,
              let shiftId = selectedShiftId,
              var job = workScheduleService.job(withId: jobId),
              let shiftIndex = job.shifts.firstIndex(where: { $0.id == shiftId }) else { return }
        
        // Update the shift template for the whole job (all days using this shift will show the new times)
        var updatedShift = job.shifts[shiftIndex]
        updatedShift.startMinutesFromMidnight = editStartMinutes
        updatedShift.endMinutesFromMidnight = editEndMinutes
        job.shifts[shiftIndex] = updatedShift
        workScheduleService.updateJob(job)
        
        // Save work day for this date using the updated shift (no per-day override)
        var diff = editEndMinutes - editStartMinutes
        if diff <= 0 { diff += 24 * 60 }
        let hours = Double(diff) / 60.0
        let workDay = WorkDay(
            date: date,
            hoursWorked: hours,
            jobId: jobId,
            shiftId: shiftId,
            customStartMinutesFromMidnight: nil,
            customEndMinutesFromMidnight: nil
        )
        workScheduleService.addOrUpdateWorkDay(workDay)
        HapticHelper.mediumImpact()
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Save button
            Button {
                validateAndSaveHours()
            } label: {
                Text(L10n("work_hours.save"))
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
        
        if let shift = selectedShift {
            shiftId = shift.id
            hours = shift.durationHours
            // No per-day override; shift time is the job’s shift template
        } else if isCustomHoursSelected, let workDay = existingWorkDayForSelectedJob {
            hours = workDay.hoursWorked
            shiftId = nil
            customStart = workDay.customStartMinutesFromMidnight
            customEnd = workDay.customEndMinutesFromMidnight
        } else {
            return
        }
        
        let workDay = WorkDay(
            date: date,
            hoursWorked: hours,
            jobId: jobId,
            shiftId: shiftId,
            customStartMinutesFromMidnight: customStart,
            customEndMinutesFromMidnight: customEnd
        )
        workScheduleService.addOrUpdateWorkDay(workDay)
        
        HapticHelper.mediumImpact()
        selectedDate = nil
    }
    
    private func deleteHours() {
        guard let jobId = selectedJobId,
              let workDay = existingWorkDays.first(where: { $0.jobId == jobId }) else { return }
        
        workScheduleService.deleteWorkDay(workDay)
        HapticHelper.mediumImpact()
        selectedDate = nil
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
