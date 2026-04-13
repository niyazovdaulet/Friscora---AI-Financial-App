//
//  WorkSettingsView.swift
//
//  Settings view for managing jobs, work patterns, and bulk apply history.
//

import SwiftUI

struct WorkSettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @State private var showingJobDetail: Job? = nil
    @State private var isAddingNewJob = false
    @State private var jobToDelete: Job? = nil
    @State private var showingDeleteConfirmation = false
    
    @State private var selectedBulkOperation: BulkOperation?
    @State private var patternEditor: WorkPattern?
    @State private var patternToApply: WorkPattern?
    @State private var patternDelete: WorkPattern?
    @State private var patternDeleteRemoveDays = false
    @State private var newPatternContext: WorkPatternCreationContext?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                if workScheduleService.jobs.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            jobsBlock
                            patternsBlock
                            bulkHistoryBlock
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(L10n("jobs.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n("common.done")) {
                        isPresented = false
                    }
                    .foregroundColor(AppColorTheme.accent)
                    .fontWeight(.semibold)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingNewJob = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColorTheme.accent)
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $showingJobDetail) { job in
                JobDetailView(job: job)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(isPresented: $isAddingNewJob) {
                NewJobView()
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(item: $selectedBulkOperation) { op in
                BulkOperationDetailView(operation: op)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(item: $patternEditor) { p in
                WorkPatternEditorSheet(pattern: p)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .sheet(item: $newPatternContext) { ctx in
                WorkPatternCreationSheet(context: ctx)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .confirmationDialog(
                L10n("pattern.apply_confirm_title"),
                isPresented: Binding(
                    get: { patternToApply != nil },
                    set: { if !$0 { patternToApply = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n("pattern.apply_confirm_run")) {
                    if let p = patternToApply {
                        _ = workScheduleService.applyWorkPatternNow(p)
                        patternToApply = nil
                        HapticHelper.mediumImpact()
                    }
                }
                Button(L10n("common.cancel"), role: .cancel) {
                    patternToApply = nil
                }
            } message: {
                Text(L10n("pattern.apply_confirm_message"))
            }
            .confirmationDialog(
                L10n("pattern.delete_title"),
                isPresented: Binding(
                    get: { patternDelete != nil },
                    set: { if !$0 { patternDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(L10n("pattern.delete_pattern_only"), role: .destructive) {
                    if let p = patternDelete {
                        workScheduleService.deleteWorkPattern(id: p.id, removeGeneratedWorkDays: false)
                        patternDelete = nil
                    }
                }
                Button(L10n("pattern.delete_pattern_and_days"), role: .destructive) {
                    if let p = patternDelete {
                        workScheduleService.deleteWorkPattern(id: p.id, removeGeneratedWorkDays: true)
                        patternDelete = nil
                    }
                }
                Button(L10n("common.cancel"), role: .cancel) {
                    patternDelete = nil
                }
            } message: {
                Text(L10n("pattern.delete_message"))
            }
            .alert(L10n("job_detail.delete_job"), isPresented: $showingDeleteConfirmation) {
                Button(L10n("common.cancel"), role: .cancel) {
                    jobToDelete = nil
                }
                Button(L10n("common.delete"), role: .destructive) {
                    if let job = jobToDelete {
                        withAnimation(AppAnimation.standard) {
                            workScheduleService.deleteJob(job)
                        }
                        jobToDelete = nil
                        impactFeedback(style: .medium)
                    }
                }
            } message: {
                if let job = jobToDelete {
                    Text(String(format: L10n("job.delete_confirm"), job.name))
                }
            }
        }
    }
    
    private var jobsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("work_settings.jobs_header"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            ForEach(workScheduleService.jobs) { job in
                jobRow(job: job)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            jobToDelete = job
                            showingDeleteConfirmation = true
                        } label: {
                            Label(L10n("jobs.delete"), systemImage: "trash.fill")
                        }
                    }
            }
        }
    }
    
    private var patternsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n("work_settings.patterns_header"))
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
                Button {
                    newPatternContext = .manual
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColorTheme.accent)
                }
                .accessibilityLabel(L10n("pattern.add_a11y"))
            }
            if workScheduleService.workPatterns.isEmpty {
                Text(L10n("work_settings.patterns_empty"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            } else {
                ForEach(workScheduleService.workPatterns) { p in
                    patternRow(p)
                }
            }
        }
    }
    
    private func patternRow(_ p: WorkPattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.name)
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
                if !p.isActive {
                    Text(L10n("pattern.paused_badge"))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(AppColorTheme.textTertiary)
                }
            }
            HStack(spacing: 10) {
                Button(L10n("pattern.apply_now")) {
                    patternToApply = p
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.accent)
                Button(L10n("common.edit")) {
                    patternEditor = p
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.textSecondary)
                Spacer()
                Button(L10n("common.delete")) {
                    patternDelete = p
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColorTheme.negative)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColorTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardMedium, style: .continuous))
    }
    
    private var bulkHistoryBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("work_settings.bulk_history_header"))
                .font(AppTypography.cardTitle)
                .foregroundColor(AppColorTheme.textPrimary)
            if workScheduleService.bulkOperations.isEmpty {
                Text(L10n("work_settings.bulk_history_empty"))
                    .font(AppTypography.caption)
                    .foregroundColor(AppColorTheme.textSecondary)
            } else {
                ForEach(workScheduleService.bulkOperations) { op in
                    Button {
                        selectedBulkOperation = op
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(op.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(AppColorTheme.textPrimary)
                                Text(op.appliedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColorTheme.textSecondary)
                            }
                            Spacer()
                            Text(String(format: L10n("bulk_history.day_count"), op.dayCount))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                        .padding()
                        .background(AppColorTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.cardMedium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "briefcase.fill",
            message: L10n("work.no_jobs_added"),
            detail: L10n("jobs.add_first_message"),
            actionTitle: L10n("work.add_job"),
            action: { isAddingNewJob = true },
            iconColor: AppColorTheme.textTertiary
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func jobRow(job: Job) -> some View {
        Button {
            showingJobDetail = job
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(job.color)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(L10n(job.paymentType.localizationKey))
                            .font(.caption)
                            .foregroundColor(AppColorTheme.textSecondary)
                        
                        Text("•")
                            .foregroundColor(AppColorTheme.textTertiary)
                        
                        Text(CurrencyFormatter.formatWithSymbol(
                            job.getPaymentAmount(),
                            currencyCode: UserProfileService.shared.profile.currency
                        ))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColorTheme.textTertiary)
            }
            .padding()
            .background(AppColorTheme.cardBackground)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                jobToDelete = job
                showingDeleteConfirmation = true
            } label: {
                Label(L10n("jobs.delete"), systemImage: "trash")
            }
        }
    }
}
