//
//  WorkSettingsView.swift
//  Friscora
//
//  Settings view for managing jobs
//

import SwiftUI

struct WorkSettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @State private var showingJobDetail: Job? = nil
    @State private var isAddingNewJob = false
    @State private var jobToDelete: Job? = nil
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                if workScheduleService.jobs.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
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
                // Color indicator
                Circle()
                    .fill(job.color)
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.headline)
                        .foregroundColor(AppColorTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(job.paymentType == .hourly ? "Hourly" : "Fixed")
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
