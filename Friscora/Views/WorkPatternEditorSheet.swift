//
//  WorkPatternEditorSheet.swift
//  Friscora
//
//  Edit an existing saved work pattern (name, weekdays, range, active).
//

import SwiftUI

struct WorkPatternEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workScheduleService = WorkScheduleService.shared
    
    @State private var pattern: WorkPattern
    
    private var gridCal: Calendar { ScheduleSharingScheduleExporter.gridCalendar }
    
    init(pattern: WorkPattern) {
        _pattern = State(initialValue: pattern)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background.ignoresSafeArea()
                Form {
                    Section {
                        TextField(L10n("pattern.name_placeholder"), text: $pattern.name)
                            .foregroundColor(AppColorTheme.textPrimary)
                        Toggle(L10n("pattern.active"), isOn: $pattern.isActive)
                            .tint(AppColorTheme.accent)
                    }
                    Section {
                        weekdayToggles
                    }
                    Section {
                        DatePicker(L10n("pattern.start_date"), selection: $pattern.startDate, displayedComponents: .date)
                        DatePicker(L10n("pattern.end_date"), selection: $pattern.endDate, displayedComponents: .date)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("pattern.edit_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n("common.save")) {
                        workScheduleService.addOrUpdateWorkPattern(pattern)
                        HapticHelper.mediumImpact()
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.accent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var weekdayToggles: some View {
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        return ForEach(1...7, id: \.self) { w in
            Toggle(isOn: Binding(
                get: { pattern.weekdays.contains(w) },
                set: { on in
                    var s = Set(pattern.weekdays)
                    if on { s.insert(w) } else { s.remove(w) }
                    pattern.weekdays = s.sorted()
                }
            )) {
                Text(labels[w - 1])
            }
            .tint(AppColorTheme.accent)
        }
    }
}
