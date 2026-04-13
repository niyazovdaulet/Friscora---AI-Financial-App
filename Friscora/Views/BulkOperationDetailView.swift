//
//  BulkOperationDetailView.swift
//  Friscora
//
//  Inspect and remove work days tied to a bulk apply (settings history).
//

import SwiftUI

struct BulkOperationDetailView: View {
    let operation: BulkOperation
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @State private var selectedIds: Set<UUID> = []
    @State private var confirmDeleteAll = false
    
    private var relatedDays: [WorkDay] {
        workScheduleService.workDays(withBulkOperationId: operation.id).sorted {
            $0.date < $1.date
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background.ignoresSafeArea()
                List {
                    Section {
                        LabeledContent(L10n("bulk_history.detail.applied"), value: operation.appliedAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent(L10n("bulk_history.detail.added"), value: "\(operation.dayCount)")
                        LabeledContent(L10n("bulk_history.detail.replaced"), value: "\(operation.replacedCount)")
                        LabeledContent(L10n("bulk_history.detail.skipped"), value: "\(operation.skippedCount)")
                        LabeledContent(L10n("bulk_history.detail.label"), value: operation.label)
                    }
                    .listRowBackground(AppColorTheme.cardBackground)
                    
                    Section {
                        if relatedDays.isEmpty {
                            Text(L10n("bulk_history.detail.empty"))
                                .foregroundColor(AppColorTheme.textSecondary)
                        } else {
                            ForEach(relatedDays) { wd in
                                let checked = selectedIds.contains(wd.id)
                                Button {
                                    if checked {
                                        selectedIds.remove(wd.id)
                                    } else {
                                        selectedIds.insert(wd.id)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(checked ? AppColorTheme.accent : AppColorTheme.textTertiary)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(wd.date.formatted(date: .abbreviated, time: .omitted))
                                                .foregroundColor(AppColorTheme.textPrimary)
                                            if let job = workScheduleService.job(withId: wd.jobId) {
                                                Text(job.name)
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColorTheme.textSecondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text(L10n("bulk_history.detail.shifts_header"))
                    }
                    .listRowBackground(AppColorTheme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("bulk_history.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.done")) { dismiss() }
                        .foregroundColor(AppColorTheme.accent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: AppSpacing.s) {
                    Button(role: .destructive) {
                        removeSelected()
                    } label: {
                        Text(L10n("bulk_history.remove_selected"))
                            .font(AppTypography.bodySemibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedIds.isEmpty ? AppColorTheme.grayDark : AppColorTheme.negative.opacity(0.2))
                            .foregroundColor(selectedIds.isEmpty ? AppColorTheme.textTertiary : AppColorTheme.negative)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                    }
                    .disabled(selectedIds.isEmpty)
                    Button(role: .destructive) {
                        confirmDeleteAll = true
                    } label: {
                        Text(L10n("bulk_history.remove_all"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColorTheme.negative)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(AppSpacing.m)
                .background(AppColorTheme.background.opacity(0.98))
            }
            .alert(L10n("bulk_history.remove_all_confirm_title"), isPresented: $confirmDeleteAll) {
                Button(L10n("common.cancel"), role: .cancel) {}
                Button(L10n("common.delete"), role: .destructive) {
                    removeAll()
                }
            } message: {
                Text(L10n("bulk_history.remove_all_confirm_message"))
            }
        }
    }
    
    private func removeSelected() {
        guard !selectedIds.isEmpty else { return }
        workScheduleService.performWorkDayBatch(toAdd: [], toRemove: Array(selectedIds), operationRecord: nil)
        if workScheduleService.workDays(withBulkOperationId: operation.id).isEmpty {
            workScheduleService.removeBulkOperationRecord(id: operation.id)
            dismiss()
        } else {
            selectedIds = []
        }
        HapticHelper.mediumImpact()
    }
    
    private func removeAll() {
        let ids = relatedDays.map(\.id)
        workScheduleService.performWorkDayBatch(toAdd: [], toRemove: ids, operationRecord: nil)
        workScheduleService.removeBulkOperationRecord(id: operation.id)
        HapticHelper.mediumImpact()
        dismiss()
    }
}
