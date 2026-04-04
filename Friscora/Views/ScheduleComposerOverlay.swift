//
//  ScheduleComposerOverlay.swift
//  Friscora
//
//  “Shift Composer” — bottom overlay for day actions (collapsed quick picks → expanded work/event editors).
//

import SwiftUI

enum ScheduleComposerStage: Equatable {
    case collapsed
    case work(focusedJobId: UUID?)
    case event(editingEventId: UUID?)
}

struct ScheduleComposerOverlay: View {
    let date: Date
    @Binding var stage: ScheduleComposerStage
    /// Closes the composer entirely (clears selected day in parent).
    var onDismissComposer: () -> Void
    var accessibilityComposerFocused: AccessibilityFocusState<Bool>.Binding
    
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    
    @State private var sheetBindingHolder: IdentifiableDate? = nil
    @State private var listRefresh = UUID()
    
    @State private var personalTitle: String = ""
    @State private var personalStart: Date = Date()
    @State private var personalEnd: Date = Date()
    @State private var personalOverlapBanner: Bool = false
    @State private var forceSavePersonalDespiteOverlap: Bool = false
    @FocusState private var eventTitleFieldFocused: Bool
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }
    
    private var sheetBinding: Binding<IdentifiableDate?> {
        Binding(get: { sheetBindingHolder }, set: { sheetBindingHolder = $0 })
    }
    
    /// e.g. "April 23" (localized month + day, no weekday).
    private var composerMonthDayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMMd")
        return formatter.string(from: date)
    }
    
    private var weekdaySubtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter.string(from: date)
    }
    
    private var workRows: [WorkDay] {
        workScheduleService.workDays(for: date).sorted { lhs, rhs in
            let n1 = workScheduleService.job(withId: lhs.jobId)?.name ?? ""
            let n2 = workScheduleService.job(withId: rhs.jobId)?.name ?? ""
            return n1.localizedCaseInsensitiveCompare(n2) == .orderedAscending
        }
    }
    
    private var personalRows: [PersonalScheduleEvent] {
        workScheduleService.personalEvents(onSameDayAs: date)
    }
    
    private var dayItemCount: Int {
        workRows.count + personalRows.count
    }
    
    private var collapsedStatsLine: String? {
        dayQuickStatsLine(for: date)
    }
    
    private var isExpanded: Bool {
        switch stage {
        case .collapsed: return false
        case .work, .event: return true
        }
    }
    
    private var workFormFocusId: UUID? {
        if case .work(let id) = stage { return id }
        return nil
    }
    
    private var workFormStageKey: String {
        if case .work(let id) = stage {
            return id?.uuidString ?? "new"
        }
        return "na"
    }
    
    /// Trimmed title: ≥3 characters and not digits-only.
    private var isPersonalTitleValid: Bool {
        let t = personalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count >= 3 else { return false }
        if t.range(of: "^[0-9]+$", options: .regularExpression) != nil { return false }
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            composerTopBar
            
            Group {
                switch stage {
                case .collapsed:
                    collapsedContent
                case .work:
                    expandedWorkContent
                case .event:
                    expandedEventContent
                }
            }
            .animation(AppAnimation.composerStage, value: stage)
        }
        .padding(.bottom, AppSpacing.s)
        .safeAreaPadding(.bottom, AppSpacing.xs)
        .background(composerCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(AppColorTheme.textTertiary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.28), radius: 20, x: 0, y: 10)
        .padding(.horizontal, AppSpacing.m)
        .onAppear {
            seedPersonalTimesIfNeeded()
            syncPersonalFormWithStage()
        }
        .onChange(of: date) { _, _ in
            personalOverlapBanner = false
            forceSavePersonalDespiteOverlap = false
            seedPersonalTimesIfNeeded()
            syncPersonalFormWithStage()
            listRefresh = UUID()
        }
        .onChange(of: stage) { _, newStage in
            if case .event = newStage {
                syncPersonalFormWithStage()
            }
            if case .work = newStage {
                personalOverlapBanner = false
                eventTitleFieldFocused = false
            }
            if case .collapsed = newStage {
                eventTitleFieldFocused = false
            }
        }
        .toolbar {
            if case .event = stage {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n("common.done")) {
                        eventTitleFieldFocused = false
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColorTheme.accent)
                }
            }
        }
    }
    
    private var composerTopBar: some View {
        HStack(alignment: .top, spacing: 12) {
            if isExpanded {
                Button {
                    HapticHelper.lightImpact()
                    withAnimation(AppAnimation.composerStage) {
                        stage = .collapsed
                    }
                } label: {
                    Image(systemName: "chevron.down.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title2)
                        .foregroundColor(AppColorTheme.textTertiary)
                }
                .accessibilityLabel(L10n("schedule.composer.back_collapsed_a11y"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(composerMonthDayTitle)
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                if stage == .collapsed {
                    Text(L10n("schedule.composer.add_to_day_subtitle"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                } else {
                    Text(weekdaySubtitle)
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if case .event = stage {
                    eventTitleFieldFocused = false
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused(accessibilityComposerFocused)
            
            Spacer(minLength: 8)
            
            Button {
                HapticHelper.lightImpact()
                onDismissComposer()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.title2)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            .accessibilityLabel(L10n("schedule.inspector.close_a11y"))
            .accessibilityHint(L10n("schedule.inspector.close_hint_a11y"))
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.m)
        .padding(.bottom, AppSpacing.s)
    }
    
    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            if let line = collapsedStatsLine {
                Text(line)
                    .font(.subheadline)
                    .foregroundColor(AppColorTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            if dayItemCount > 0 {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(workRows) { wd in
                            compactWorkRow(wd)
                            Divider().background(AppColorTheme.grayDark.opacity(0.2))
                        }
                        ForEach(personalRows) { ev in
                            compactPersonalRow(ev)
                            Divider().background(AppColorTheme.grayDark.opacity(0.2))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 132)
                .background(AppColorTheme.cardBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .id(listRefresh)
            }
            
            HStack(spacing: 10) {
                composerPill(
                    title: L10n("schedule.composer.action_work"),
                    systemImage: "briefcase.fill",
                    tint: AppColorTheme.accent
                ) {
                    HapticHelper.selection()
                    withAnimation(AppAnimation.composerStage) {
                        stage = .work(focusedJobId: nil)
                    }
                }
                .disabled(!workScheduleService.hasJobs)
                .opacity(workScheduleService.hasJobs ? 1 : 0.45)
                
                composerPill(
                    title: L10n("schedule.composer.action_event"),
                    systemImage: "calendar",
                    tint: AppColorTheme.sapphire
                ) {
                    HapticHelper.selection()
                    resetPersonalFormForNew()
                    withAnimation(AppAnimation.composerStage) {
                        stage = .event(editingEventId: nil)
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.bottom, AppSpacing.m)
    }
    
    private func composerPill(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.35), tint.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func compactWorkRow(_ wd: WorkDay) -> some View {
        let job = workScheduleService.job(withId: wd.jobId)
        let title = job?.name ?? L10n("schedule.item.work_fallback")
        let subtitle: String = {
            if let shiftId = wd.shiftId, let j = job, let sh = j.shift(withId: shiftId) {
                return "\(sh.name) · \(wd.customTimeRangeString(locale: LocalizationManager.shared.currentLocale) ?? sh.timeRangeString(locale: LocalizationManager.shared.currentLocale))"
            }
            if let custom = wd.customTimeRangeString(locale: LocalizationManager.shared.currentLocale) {
                return custom
            }
            return String(format: "%.1f %@", wd.hoursWorked, L10n("work.hours_short"))
        }()
        return Button {
            HapticHelper.selection()
            withAnimation(AppAnimation.composerStage) {
                stage = .work(focusedJobId: wd.jobId)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "briefcase.fill")
                    .foregroundColor(job?.color ?? AppColorTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColorTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func compactPersonalRow(_ ev: PersonalScheduleEvent) -> some View {
        let busyLabel = L10n("schedule.busy_placeholder")
        let titleText = ev.showAsBusy && ev.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? busyLabel
            : (ev.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n("schedule.event.untitled") : ev.title)
        let timeText = ev.timeRangeString(locale: LocalizationManager.shared.currentLocale)
        return Button {
            HapticHelper.selection()
            loadPersonalForm(from: ev)
            withAnimation(AppAnimation.composerStage) {
                stage = .event(editingEventId: ev.id)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundColor(AppColorTheme.sapphire)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColorTheme.textPrimary)
                    Text(timeText)
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var expandedWorkContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                if workScheduleService.hasJobs {
                    WorkShiftDayForm(
                        date: date,
                        selectedDate: sheetBinding,
                        embeddedInParentNavigation: true,
                        stickyBottomActions: false,
                        dismissAfterSave: false,
                        onAfterSave: {
                            listRefresh = UUID()
                            HapticHelper.mediumImpact()
                            withAnimation(AppAnimation.composerStage) {
                                stage = .collapsed
                            }
                        },
                        focusedJobId: workFormFocusId,
                        fillsParentChrome: false
                    )
                    .id("\(calendar.startOfDay(for: date).timeIntervalSince1970)-\(workFormStageKey)")
                    .padding(.horizontal, AppSpacing.m)
                } else {
                    Text(L10n("schedule.work_form_no_jobs"))
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.m)
                }
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .frame(maxHeight: 420)
    }
    
    private var expandedEventContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text(L10n("schedule.event.section_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { eventTitleFieldFocused = false }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n("schedule.event.title_label"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { eventTitleFieldFocused = false }
                    TextField(L10n("schedule.event.title_placeholder"), text: $personalTitle)
                        .focused($eventTitleFieldFocused)
                        .textInputAutocapitalization(.sentences)
                        .foregroundColor(AppColorTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColorTheme.elevatedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppColorTheme.textTertiary.opacity(0.22), lineWidth: 1)
                        )
                    Text(L10n("schedule.event.title_rules_hint"))
                        .font(.caption2)
                        .foregroundColor(AppColorTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { eventTitleFieldFocused = false }
                }
                
                HStack(alignment: .top, spacing: AppSpacing.m) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n("schedule.event.start_label"))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { eventTitleFieldFocused = false }
                        DatePicker("", selection: $personalStart, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(AppColorTheme.sapphire)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n("schedule.event.end_label"))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { eventTitleFieldFocused = false }
                        DatePicker("", selection: $personalEnd, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(AppColorTheme.sapphire)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Text(L10n("schedule.event.forecast_footer"))
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { eventTitleFieldFocused = false }
                
                if personalOverlapBanner {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n("schedule.overlap.message"))
                            .font(.subheadline)
                            .foregroundColor(AppColorTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentShape(Rectangle())
                            .onTapGesture { eventTitleFieldFocused = false }
                        HStack(spacing: 12) {
                            Button {
                                eventTitleFieldFocused = false
                                personalOverlapBanner = false
                                forceSavePersonalDespiteOverlap = false
                            } label: {
                                Text(L10n("schedule.composer.adjust_times"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColorTheme.accent)
                            }
                            Button {
                                eventTitleFieldFocused = false
                                forceSavePersonalDespiteOverlap = true
                                savePersonalEvent()
                            } label: {
                                Text(L10n("schedule.overlap.save_anyway"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColorTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppColorTheme.sapphire.opacity(0.35))
                                    .clipShape(Capsule())
                            }
                            .disabled(!isPersonalTitleValid)
                        }
                    }
                    .padding(AppSpacing.m)
                    .background(AppColorTheme.warning.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                
                Button {
                    eventTitleFieldFocused = false
                    savePersonalEvent()
                } label: {
                    Text(editingEventId != nil ? L10n("common.save") : L10n("schedule.composer.event_add"))
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColorTheme.sapphire.opacity(isPersonalTitleValid ? 0.85 : 0.32))
                        .cornerRadius(14)
                }
                .disabled(!isPersonalTitleValid)
                
                if editingEventId != nil {
                    Button(role: .destructive) {
                        eventTitleFieldFocused = false
                        deleteEditingPersonalEvent()
                    } label: {
                        Text(L10n("common.delete"))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColorTheme.negative.opacity(0.12))
                            .cornerRadius(14)
                    }
                }
                
                Color.clear
                    .frame(minHeight: 160)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { eventTitleFieldFocused = false }
            }
            .padding(.horizontal, AppSpacing.m)
            .padding(.bottom, AppSpacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .frame(maxHeight: 420)
    }
    
    private var editingEventId: UUID? {
        if case .event(let id) = stage { return id }
        return nil
    }
    
    private var composerCardBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AppColorTheme.elevatedBackground.opacity(0.97),
                        AppColorTheme.cardBackground.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private func dayQuickStatsLine(for day: Date) -> String? {
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
            parts.append(formatHoursShort(hours))
        }
        if hasHourlyEstimate {
            let money = CurrencyFormatter.formatWithSymbol(hourlyTotal, currencyCode: currency)
            parts.append(String(format: L10n("schedule.composer.approx_earnings_fragment"), money))
        }
        return parts.joined(separator: L10n("schedule.composer.stats_sep"))
    }
    
    private func formatHoursShort(_ hours: Double) -> String {
        if hours == floor(hours) {
            return String(format: "%.0f %@", hours, L10n("work.hours_short"))
        }
        return String(format: "%.1f %@", hours, L10n("work.hours_short"))
    }
    
    private func syncPersonalFormWithStage() {
        guard case .event(let eid) = stage else { return }
        if let eid {
            if let ev = workScheduleService.personalEvents(onSameDayAs: date).first(where: { $0.id == eid }) {
                loadPersonalForm(from: ev)
            } else {
                resetPersonalFormForNew()
            }
        } else {
            resetPersonalFormForNew()
        }
    }
    
    private func seedPersonalTimesIfNeeded() {
        let day = calendar.startOfDay(for: date)
        if let nine = calendar.date(byAdding: .hour, value: 9, to: day),
           let ten = calendar.date(byAdding: .hour, value: 10, to: day) {
            personalStart = nine
            personalEnd = ten
        }
    }
    
    private func resetPersonalFormForNew() {
        personalTitle = ""
        seedPersonalTimesIfNeeded()
        personalOverlapBanner = false
        forceSavePersonalDespiteOverlap = false
    }
    
    private func loadPersonalForm(from ev: PersonalScheduleEvent) {
        personalTitle = ev.title
        let day = calendar.startOfDay(for: date)
        if let s = calendar.date(byAdding: .minute, value: ev.startMinutesFromMidnight, to: day),
           let e = calendar.date(byAdding: .minute, value: ev.endMinutesFromMidnight, to: day) {
            personalStart = s
            personalEnd = e
        } else {
            seedPersonalTimesIfNeeded()
        }
        personalOverlapBanner = false
        forceSavePersonalDespiteOverlap = false
    }
    
    private func savePersonalEvent() {
        guard isPersonalTitleValid else { return }
        let trimmedTitle = personalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let startM = minutesFromDateOnDay(personalStart, day: date)
        let endM = minutesFromDateOnDay(personalEnd, day: date)
        let dayStart = calendar.startOfDay(for: date)
        guard let absStart = calendar.date(byAdding: .minute, value: startM, to: dayStart),
              var absEnd = calendar.date(byAdding: .minute, value: endM, to: dayStart) else { return }
        if absEnd <= absStart {
            absEnd = calendar.date(byAdding: .day, value: 1, to: absEnd) ?? absEnd
        }
        
        let id = editingEventId ?? UUID()
        let ignorePersonal = editingEventId
        
        if !forceSavePersonalDespiteOverlap,
           workScheduleService.hasScheduleOverlap(
            on: date,
            proposedStart: absStart,
            proposedEnd: absEnd,
            ignoringPersonalEventId: ignorePersonal
           ) {
            personalOverlapBanner = true
            return
        }
        forceSavePersonalDespiteOverlap = false
        personalOverlapBanner = false
        
        let event = PersonalScheduleEvent(
            id: id,
            date: dayStart,
            title: trimmedTitle,
            startMinutesFromMidnight: startM,
            endMinutesFromMidnight: endM,
            showAsBusy: false
        )
        workScheduleService.addOrUpdatePersonalEvent(event)
        HapticHelper.mediumImpact()
        listRefresh = UUID()
        resetPersonalFormForNew()
        withAnimation(AppAnimation.composerStage) {
            stage = .collapsed
        }
    }
    
    private func deleteEditingPersonalEvent() {
        guard let eid = editingEventId,
              let ev = personalRows.first(where: { $0.id == eid }) else { return }
        workScheduleService.deletePersonalEvent(ev)
        listRefresh = UUID()
        HapticHelper.mediumImpact()
        resetPersonalFormForNew()
        withAnimation(AppAnimation.composerStage) {
            stage = .collapsed
        }
    }
    
    private func minutesFromDateOnDay(_ timeDate: Date, day: Date) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: timeDate)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return h * 60 + m
    }
}
