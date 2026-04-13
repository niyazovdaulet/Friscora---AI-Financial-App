//
//  WorkPatternCreationSheet.swift
//  Friscora
//
//  Create a named `WorkPattern` from a bulk operation or an earning-aware suggestion.
//

import SwiftUI

struct WorkPatternCreationSheet: View {
    let context: WorkPatternCreationContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var workScheduleService = WorkScheduleService.shared
    
    @State private var name: String = ""
    @State private var endDate: Date = Date()
    
    private var gridCal: Calendar { ScheduleSharingScheduleExporter.gridCalendar }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background.ignoresSafeArea()
                Form {
                    Section {
                        TextField(L10n("pattern.name_placeholder"), text: $name)
                            .foregroundColor(AppColorTheme.textPrimary)
                    }
                    Section {
                        DatePicker(L10n("pattern.end_date"), selection: $endDate, displayedComponents: .date)
                            .tint(AppColorTheme.accent)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("pattern.create_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) { dismiss() }
                        .foregroundColor(AppColorTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) { save() }
                        .foregroundColor(AppColorTheme.accent)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            switch context {
            case .fromUndoBulk(let op):
                if let job = workScheduleService.job(withId: op.jobId) {
                    name = defaultPatternName(jobName: job.name)
                }
                let days = workScheduleService.workDays(withBulkOperationId: op.id).map(\.date)
                if let maxD = days.max() {
                    endDate = gridCal.date(byAdding: .month, value: 6, to: maxD) ?? maxD
                }
            case .fromSuggestion(let s):
                if let job = workScheduleService.job(withId: s.jobId) {
                    name = defaultPatternName(jobName: job.name)
                }
                endDate = gridCal.date(byAdding: .month, value: 6, to: Date()) ?? Date()
            case .manual:
                if let job = workScheduleService.jobs.first {
                    name = defaultPatternName(jobName: job.name)
                }
                endDate = gridCal.date(byAdding: .month, value: 6, to: Date()) ?? Date()
            }
        }
    }
    
    private func defaultPatternName(jobName: String) -> String {
        let df = DateFormatter()
        df.locale = LocalizationManager.shared.currentLocale
        df.dateFormat = "MMM yyyy"
        return "\(jobName) · \(df.string(from: Date()))"
    }
    
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cal = gridCal
        let start = cal.startOfDay(for: Date())
        let end = cal.startOfDay(for: endDate)
        
        switch context {
        case .manual:
            guard let job = workScheduleService.jobs.first(where: { !$0.shifts.isEmpty }),
                  let shift = job.shifts.first else { return }
            let pattern = WorkPattern(
                id: UUID(),
                name: trimmed,
                jobId: job.id,
                shiftId: shift.id,
                weekdays: [1, 2, 3, 4, 5],
                startDate: start,
                endDate: max(end, start),
                isActive: true,
                createdAt: Date(),
                lastAppliedAt: nil,
                totalDaysGenerated: 0
            )
            workScheduleService.addOrUpdateWorkPattern(pattern)
        case .fromUndoBulk(let op):
            let related = workScheduleService.workDays(withBulkOperationId: op.id)
            let weekdays = Set(related.map { ScheduleWeekday.appWeekday(mondayFirst1To7: $0.date, calendar: cal) }).sorted()
            let patternId = UUID()
            let pattern = WorkPattern(
                id: patternId,
                name: trimmed,
                jobId: op.jobId,
                shiftId: op.shiftId,
                weekdays: weekdays,
                startDate: start,
                endDate: max(end, start),
                isActive: true,
                createdAt: Date(),
                lastAppliedAt: Date(),
                totalDaysGenerated: related.count
            )
            workScheduleService.addOrUpdateWorkPattern(pattern)
            workScheduleService.assignPatternIdToWorkDays(bulkOperationId: op.id, patternId: patternId)
        case .fromSuggestion(let s):
            let pattern = WorkPattern(
                id: UUID(),
                name: trimmed,
                jobId: s.jobId,
                shiftId: s.shiftId,
                weekdays: s.weekdays.sorted(),
                startDate: start,
                endDate: max(end, start),
                isActive: true,
                createdAt: Date(),
                lastAppliedAt: nil,
                totalDaysGenerated: 0
            )
            workScheduleService.addOrUpdateWorkPattern(pattern)
            workScheduleService.dismissPatternSuggestion(fingerprint: SchedulePatternDetector.fingerprint(jobId: s.jobId, shiftId: s.shiftId, weekdays: s.weekdays))
        }
        HapticHelper.mediumImpact()
        dismiss()
    }
}
