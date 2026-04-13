//
//  BulkShiftApplySheet.swift
//  Friscora
//
//  Smart multi-day shift apply: pick days, weekday pattern, or custom range — one confirm pipeline.
//

import SwiftUI

enum BulkShiftApplyMode: Int, CaseIterable {
    case pickDays
    case weekdayPattern
    case customRange
}

struct BulkShiftApplySheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let initialJobId: UUID?
    let initialShiftId: UUID?
    let lockHeaderSelections: Bool
    var onFinished: ((BulkOperation) -> Void)?
    var onRequestJobEditor: ((UUID) -> Void)?
    
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    
    @State private var mode: BulkShiftApplyMode = .pickDays
    @State private var selectedJobId: UUID?
    @State private var selectedShiftId: UUID?
    
    @State private var pickedDays: Set<Date> = []
    @State private var selectedMonthIndex: Int = 24
    
    @State private var patternSelectedWeekdays: Set<Int> = []
    @State private var rangePreset: PatternRangePreset = .thisMonth
    @State private var customRangeStart: Date = Date()
    @State private var customRangeEnd: Date = Date()
    
    @State private var replaceExistingForJob = true
    @State private var skipAnyPersonalEventDay = false
    @State private var settingsExpanded = false
    
    private var gridCal: Calendar { ScheduleSharingScheduleExporter.gridCalendar }
    
    private var currencyCode: String { userProfileService.profile.currency }
    
    private var calendarMonths: [Date] {
        let cal = gridCal
        guard let startOfCurrent = cal.date(from: cal.dateComponents([.year, .month], from: Date())) else { return [] }
        return (-24..<25).compactMap { cal.date(byAdding: .month, value: $0, to: startOfCurrent) }
    }
    
    private var selectedJob: Job? {
        guard let id = selectedJobId else { return nil }
        return workScheduleService.job(withId: id)
    }
    
    private var selectedShift: Shift? {
        guard let job = selectedJob, let sid = selectedShiftId else { return nil }
        return job.shift(withId: sid)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        headerSection
                        Picker("", selection: $mode) {
                            Text(L10n("bulk_apply.mode.pick_days")).tag(BulkShiftApplyMode.pickDays)
                            Text(L10n("bulk_apply.mode.pattern")).tag(BulkShiftApplyMode.weekdayPattern)
                            Text(L10n("bulk_apply.mode.custom_range")).tag(BulkShiftApplyMode.customRange)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, AppSpacing.m)
                        
                        Group {
                            switch mode {
                            case .pickDays:
                                pickDaysSection
                            case .weekdayPattern, .customRange:
                                patternRangeSection
                            }
                        }
                        
                        conflictSettings
                        previewEarnings
                        confirmButton
                    }
                    .padding(.vertical, AppSpacing.m)
                }
            }
            .navigationTitle(L10n("bulk_apply.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) { dismiss() }
                        .foregroundColor(AppColorTheme.textSecondary)
                }
            }
        }
        .onAppear {
            if let jid = initialJobId {
                selectedJobId = jid
            } else if let first = workScheduleService.jobs.first {
                selectedJobId = first.id
            }
            if let sid = initialShiftId {
                selectedShiftId = sid
            }
            if let idx = ScheduleMonthNavigator.todayIndex(in: calendarMonths, calendar: gridCal) {
                selectedMonthIndex = idx
            }
            let cal = gridCal
            customRangeStart = cal.startOfDay(for: Date())
            customRangeEnd = cal.startOfDay(for: Date())
            if patternSelectedWeekdays.isEmpty {
                patternSelectedWeekdays = [1, 2, 3, 4, 5]
            }
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .customRange {
                rangePreset = .custom
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if lockHeaderSelections, let job = selectedJob, let shift = selectedShift {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(AppTypography.cardTitle)
                        .foregroundColor(AppColorTheme.textPrimary)
                    Text(shift.name)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                .padding(AppSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColorTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardMedium, style: .continuous))
                .padding(.horizontal, AppSpacing.m)
            } else {
                jobShiftPickers
            }
        }
    }
    
    private var jobShiftPickers: some View {
        VStack(spacing: AppSpacing.s) {
            if workScheduleService.jobs.isEmpty {
                Text(L10n("bulk_apply.no_jobs"))
                    .font(AppTypography.bodySecondary)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .padding(.horizontal, AppSpacing.m)
            } else {
                Menu {
                    ForEach(workScheduleService.jobs) { job in
                        Button(job.name) { selectedJobId = job.id; selectedShiftId = job.shifts.first?.id }
                    }
                } label: {
                    HStack {
                        Text(selectedJob?.name ?? L10n("bulk_apply.choose_job"))
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .padding(AppSpacing.m)
                    .background(AppColorTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                }
                .padding(.horizontal, AppSpacing.m)
                
                if let job = selectedJob {
                    if job.shifts.isEmpty {
                        Button {
                            dismiss()
                            if let id = selectedJobId { onRequestJobEditor?(id) }
                        } label: {
                            Text(L10n("bulk_apply.add_shifts_in_job"))
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColorTheme.accent)
                        }
                        .padding(.horizontal, AppSpacing.m)
                    } else {
                        Menu {
                            ForEach(job.shifts) { sh in
                                Button(sh.name) { selectedShiftId = sh.id }
                            }
                        } label: {
                            HStack {
                                Text(selectedShift?.name ?? L10n("bulk_apply.choose_shift"))
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .font(AppTypography.body)
                            .foregroundColor(AppColorTheme.textPrimary)
                            .padding(AppSpacing.m)
                            .background(AppColorTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                        }
                        .padding(.horizontal, AppSpacing.m)
                    }
                }
            }
        }
    }
    
    private var pickDaysSection: some View {
        VStack(spacing: 10) {
            bulkWeekdayHeaderRow
                .padding(.horizontal, AppSpacing.m)
            GeometryReader { geo in
                TabView(selection: $selectedMonthIndex) {
                    ForEach(Array(calendarMonths.indices), id: \.self) { index in
                        bulkMonthDayGrid(month: calendarMonths[index])
                            .frame(width: geo.size.width, height: 360)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .frame(height: 360)
            .padding(.horizontal, AppSpacing.m)
        }
    }
    
    private var bulkWeekdayHeaderRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
    
    private func bulkMonthDayGrid(month: Date) -> some View {
        let days = generateCalendarDays(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { date in
                bulkPickDayCell(date: date, month: month)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }
    
    private func bulkPickDayCell(date: Date, month: Date) -> some View {
        let inMonth = gridCal.isDate(date, equalTo: month, toGranularity: .month)
        let dayStart = gridCal.startOfDay(for: date)
        let isPicked = pickedDays.contains(dayStart)
        let jobId = selectedJobId
        let hasJobDay = jobId.map { workScheduleService.workDay(for: date, jobId: $0) != nil } ?? false
        let hasPersonal = !workScheduleService.personalEvents(onSameDayAs: date).isEmpty
        let dayNum = gridCal.component(.day, from: date)
        
        return Button {
            guard inMonth, selectedJobId != nil, selectedShiftId != nil else { return }
            HapticHelper.selection()
            if isPicked {
                pickedDays.remove(dayStart)
            } else {
                pickedDays.insert(dayStart)
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(dayNum)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(inMonth ? AppColorTheme.textPrimary : AppColorTheme.textTertiary)
                HStack(spacing: 3) {
                    if hasJobDay {
                        Circle()
                            .fill(AppColorTheme.scheduleBulkReplaceHint)
                            .frame(width: 5, height: 5)
                    }
                    if hasPersonal {
                        Circle()
                            .fill(AppColorTheme.grayMedium)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 8)
            }
            .frame(width: 44, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isPicked ? AppColorTheme.accent.opacity(0.35) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isPicked && hasJobDay ? AppColorTheme.scheduleBulkReplaceHint.opacity(0.9) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .disabled(!inMonth)
        .buttonStyle(.plain)
    }
    
    private var patternRangeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            weekdayChips
            rangeChips
            if rangePreset == .custom {
                HStack {
                    DatePicker(L10n("bulk_apply.range_start"), selection: $customRangeStart, displayedComponents: .date)
                    DatePicker(L10n("bulk_apply.range_end"), selection: $customRangeEnd, displayedComponents: .date)
                }
                .labelsHidden()
                .padding(.horizontal, AppSpacing.m)
            }
            Text(L10n("bulk_apply.computed_preview_hint"))
                .font(AppTypography.caption)
                .foregroundColor(AppColorTheme.textTertiary)
                .padding(.horizontal, AppSpacing.m)
            computedPreviewGrid
        }
    }
    
    private var weekdayChips: some View {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { w in
                let on = patternSelectedWeekdays.contains(w)
                Button {
                    HapticHelper.selection()
                    if on { patternSelectedWeekdays.remove(w) } else { patternSelectedWeekdays.insert(w) }
                } label: {
                    Text(labels[w - 1])
                        .font(.caption.weight(.semibold))
                        .foregroundColor(on ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(on ? AppColorTheme.accent.opacity(0.28) : AppColorTheme.layer3Elevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppColorTheme.cardBorder, lineWidth: on ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.m)
    }
    
    private var rangeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PatternRangePreset.allCases, id: \.self) { p in
                    Button {
                        rangePreset = p
                        applyRangePreset(p)
                    } label: {
                        Text(p.title)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(rangePreset == p ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(rangePreset == p ? AppColorTheme.accent.opacity(0.22) : AppColorTheme.layer3Elevated)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.m)
        }
    }
    
    private var computedPreviewGrid: some View {
        let days = computedPatternDates.prefix(42)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days), id: \.self) { d in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(AppColorTheme.accent.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppColorTheme.accent.opacity(0.12))
                    )
                    .frame(height: 28)
                    .overlay(
                        Text("\(gridCal.component(.day, from: d))")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(AppColorTheme.textSecondary)
                    )
            }
        }
        .padding(AppSpacing.m)
    }
    
    private var computedPatternDates: [Date] {
        let start: Date
        let end: Date
        let cal = gridCal
        switch rangePreset {
        case .thisMonth:
            let m = calendarMonths[safe: selectedMonthIndex] ?? Date()
            guard let interval = cal.dateInterval(of: .month, for: m) else { return [] }
            start = interval.start
            end = cal.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        case .nextMonth:
            let m = calendarMonths[safe: selectedMonthIndex] ?? Date()
            guard let curInterval = cal.dateInterval(of: .month, for: m) else { return [] }
            let nextStart = curInterval.end
            guard let nextInterval = cal.dateInterval(of: .month, for: nextStart) else { return [] }
            start = nextInterval.start
            end = cal.date(byAdding: .day, value: -1, to: nextInterval.end) ?? start
        case .next4Weeks:
            start = cal.startOfDay(for: Date())
            end = cal.date(byAdding: .day, value: 27, to: start) ?? start
        case .next8Weeks:
            start = cal.startOfDay(for: Date())
            end = cal.date(byAdding: .day, value: 55, to: start) ?? start
        case .custom:
            let a = cal.startOfDay(for: customRangeStart)
            let b = cal.startOfDay(for: customRangeEnd)
            start = min(a, b)
            end = max(a, b)
        }
        return ScheduleWeekday.allDays(from: start, to: end, weekdays: patternSelectedWeekdays, calendar: cal)
    }
    
    private var conflictSettings: some View {
        DisclosureGroup(isExpanded: $settingsExpanded) {
            Toggle(L10n("bulk_apply.replace_existing"), isOn: $replaceExistingForJob)
                .tint(AppColorTheme.accent)
            Toggle(L10n("bulk_apply.skip_personal_days"), isOn: $skipAnyPersonalEventDay)
                .tint(AppColorTheme.accent)
        } label: {
            Text(L10n("bulk_apply.conflict_settings"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
        }
        .padding(.horizontal, AppSpacing.m)
    }
    
    private var previewEarnings: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let job = selectedJob, job.paymentType == .fixedMonthly {
                Text(L10n("bulk_apply.fixed_monthly_projection_note"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            } else if let est = hourlyEstimateTotal, est > 0 {
                Text(String(format: L10n("bulk_apply.estimated_batch"), CurrencyFormatter.formatWithSymbol(est, currencyCode: currencyCode)))
                    .font(AppTypography.bodySemibold)
                    .foregroundColor(AppColorTheme.positive)
            } else if selectedJob?.paymentType == .hourly {
                Text(L10n(selectedShift == nil ? "bulk_apply.select_shift_hint" : "bulk_apply.no_rate_hint"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.m)
        .background(AppColorTheme.layer3Elevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardMedium, style: .continuous))
        .padding(.horizontal, AppSpacing.m)
    }
    
    private var hourlyEstimateTotal: Double? {
        guard let job = selectedJob, job.paymentType == .hourly,
              let rate = job.hourlyRate, rate > 0,
              let shift = selectedShift else { return nil }
        let n = effectiveSelectedDayCount
        guard n > 0 else { return nil }
        return Double(n) * shift.durationHours * rate
    }
    
    private var effectiveSelectedDayCount: Int {
        switch mode {
        case .pickDays: return pickedDays.count
        case .weekdayPattern, .customRange: return computedPatternDates.count
        }
    }
    
    private var confirmButton: some View {
        let n = effectiveSelectedDayCount
        let title: String = {
            if let job = selectedJob, job.paymentType == .hourly, let est = hourlyEstimateTotal, est > 0 {
                return String(format: L10n("bulk_apply.confirm_hourly"), n, CurrencyFormatter.formatWithSymbol(est, currencyCode: currencyCode))
            }
            return String(format: L10n("bulk_apply.confirm_plain"), n)
        }()
        return Button {
            applyBatch()
        } label: {
            Text(title)
                .font(AppTypography.bodySemibold)
                .foregroundColor(AppColorTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Group {
                        if n > 0 && selectedShiftId != nil {
                            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                                .fill(AppColorTheme.accentGradient)
                        } else {
                            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                                .fill(AppColorTheme.grayDark)
                        }
                    }
                )
        }
        .disabled(n == 0 || selectedJobId == nil || selectedShiftId == nil)
        .padding(.horizontal, AppSpacing.m)
        .padding(.bottom, AppSpacing.l)
    }
    
    private func applyBatch() {
        guard let jobId = selectedJobId, let shiftId = selectedShiftId,
              let job = workScheduleService.job(withId: jobId),
              let shift = job.shift(withId: shiftId) else { return }
        
        let days: [Date] = {
            switch mode {
            case .pickDays:
                return pickedDays.sorted()
            case .weekdayPattern, .customRange:
                return computedPatternDates.sorted()
            }
        }()
        
        let bulkId = UUID()
        var toAdd: [WorkDay] = []
        var toRemove: [UUID] = []
        var replaced = 0
        var skipped = 0
        let cal = gridCal
        
        for day in days {
            let dayStart = cal.startOfDay(for: day)
            
            if skipAnyPersonalEventDay, !workScheduleService.personalEvents(onSameDayAs: dayStart).isEmpty {
                skipped += 1
                continue
            }
            
            let existing = workScheduleService.workDay(for: dayStart, jobId: jobId)
            let interval = absoluteInterval(job: job, shift: shift, day: dayStart, calendar: cal)
            
            if let ex = existing {
                if !replaceExistingForJob {
                    skipped += 1
                    continue
                }
                if workScheduleService.hasScheduleOverlap(
                    on: dayStart,
                    proposedStart: interval.start,
                    proposedEnd: interval.end,
                    ignoringWorkDayId: ex.id,
                    calendar: cal
                ) {
                    skipped += 1
                    continue
                }
                toRemove.append(ex.id)
                replaced += 1
            } else {
                if workScheduleService.hasScheduleOverlap(
                    on: dayStart,
                    proposedStart: interval.start,
                    proposedEnd: interval.end,
                    ignoringWorkDayId: nil,
                    calendar: cal
                ) {
                    skipped += 1
                    continue
                }
            }
            
            let hours = shift.durationHours
            let wd = WorkDay(
                date: dayStart,
                hoursWorked: hours,
                jobId: jobId,
                shiftId: shiftId,
                bulkOperationId: bulkId,
                patternId: nil
            )
            toAdd.append(wd)
        }
        
        let label = String(format: L10n("bulk_apply.operation_label"), job.name, shift.name)
        let op = BulkOperation(
            id: bulkId,
            jobId: jobId,
            shiftId: shiftId,
            patternId: nil,
            appliedAt: Date(),
            dayCount: toAdd.count,
            replacedCount: replaced,
            skippedCount: skipped,
            label: label
        )
        
        workScheduleService.performWorkDayBatch(toAdd: toAdd, toRemove: toRemove, operationRecord: op)
        HapticHelper.mediumImpact()
        onFinished?(op)
        dismiss()
    }
    
    private func absoluteInterval(job: Job, shift: Shift, day: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let dayStart = calendar.startOfDay(for: day)
        guard let s = calendar.date(byAdding: .minute, value: shift.startMinutesFromMidnight, to: dayStart),
              var e = calendar.date(byAdding: .minute, value: shift.endMinutesFromMidnight, to: dayStart) else {
            return (dayStart, dayStart)
        }
        if e <= s { e = calendar.date(byAdding: .day, value: 1, to: e) ?? e }
        return (s, e)
    }
    
    private func generateCalendarDays(for month: Date) -> [Date] {
        let calendar = gridCal
        guard let firstDayOfMonth = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysToSubtract = (firstWeekday + 5) % 7
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfMonth) else { return [] }
        var days: [Date] = []
        for i in 0..<42 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(date)
            }
        }
        return days
    }
    
    private func applyRangePreset(_ p: PatternRangePreset) {
        let cal = gridCal
        let today = cal.startOfDay(for: Date())
        switch p {
        case .thisMonth:
            break
        case .nextMonth:
            break
        case .next4Weeks, .next8Weeks, .custom:
            customRangeStart = today
            customRangeEnd = cal.date(byAdding: .day, value: p == .next4Weeks ? 27 : 55, to: today) ?? today
        }
    }
    
}

private enum PatternRangePreset: CaseIterable {
    case thisMonth
    case nextMonth
    case next4Weeks
    case next8Weeks
    case custom
    
    var title: String {
        switch self {
        case .thisMonth: return L10n("bulk_apply.range.this_month")
        case .nextMonth: return L10n("bulk_apply.range.next_month")
        case .next4Weeks: return L10n("bulk_apply.range.4_weeks")
        case .next8Weeks: return L10n("bulk_apply.range.8_weeks")
        case .custom: return L10n("bulk_apply.range.custom")
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
