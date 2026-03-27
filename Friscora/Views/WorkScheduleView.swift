//
//  WorkScheduleView.swift
//  Friscora
//
//  Main view for work schedule tracking with multiple jobs
//

import SwiftUI

struct WorkScheduleView: View {
    @StateObject private var viewModel = WorkScheduleViewModel()
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    @State private var selectedDate: IdentifiableDate? = nil
    @State private var showingSettings = false
    @State private var showingNewJob = false
    @State private var showingClearConfirmation = false
    
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
                
                if !workScheduleService.hasJobs {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Horizontally scrollable calendar (task 8)
                            horizontalCalendarSection
                                .padding(.horizontal)
                            
                            // Summary section
                            summarySection
                                .padding(.horizontal)
                            
                            // Salary projection section
                            salaryProjectionSection
                                .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
            }
//            .navigationTitle(L10n("work.title"))
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
            .sheet(item: $selectedDate) { identifiableDate in
                WorkDayInputView(date: identifiableDate.date, selectedDate: $selectedDate)
                    .presentationCornerRadius(24)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
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
        }
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
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "briefcase.fill",
            message: L10n("work.no_jobs_added"),
            detail: L10n("work.add_first_job"),
            actionTitle: L10n("work.add_job"),
            action: { showingNewJob = true },
            iconColor: AppColorTheme.textTertiary
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            TabView(selection: $selectedMonthIndex) {
                ForEach(Array(calendarMonths.enumerated()), id: \.offset) { index, month in
                    calendarSectionForMonth(month)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: selectedMonthIndex)
            .frame(height: 372)
            .onChange(of: selectedMonthIndex) { _, newIndex in
                if newIndex >= 0, newIndex < calendarMonths.count {
                    viewModel.selectedMonth = calendarMonths[newIndex]
                }
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
        let hasHours = !workDays.isEmpty
        
        // Get job colors for this date (unique colors only)
        let jobColors = workDays.compactMap { workDay -> Color? in
            guard let job = workScheduleService.job(withId: workDay.jobId) else { return nil }
            return job.color
        }
        
        return Button {
            if isCurrentMonth {
                if workScheduleService.hasJobs {
                    selectedDate = IdentifiableDate(date: date)
                } else {
                    // First time - open settings
                    showingSettings = true
                }
            }
        } label: {
            ZStack {
                // Work day indicator - filled circle(s)
                if hasHours && isCurrentMonth {
                    if jobColors.count == 1 {
                        // Single job - full filled circle
                        Circle()
                            .fill(jobColors[0].opacity(0.85))
                            .frame(width: 36, height: 36)
                    } else {
                        // Multiple jobs - segmented circle
                        MultiColorCircle(colors: jobColors)
                            .frame(width: 36, height: 36)
                    }
                }
                
                // Today highlight ring (on top of work indicator)
                if isToday && isCurrentMonth {
                    Circle()
                        .stroke(AppColorTheme.accent, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
                
                Text("\(viewModel.calendar.component(.day, from: date))")
                    .font(.system(size: 15, weight: isToday || hasHours ? .bold : .semibold))
                    .foregroundColor(
                        isCurrentMonth
                            ? (hasHours ? .white : (isToday ? AppColorTheme.accent : AppColorTheme.textPrimary))
                            : AppColorTheme.textTertiary
                    )
            }
            .frame(width: 44, height: 50)
        }
        .disabled(!isCurrentMonth)
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
        VStack(spacing: 20) {
            HStack {
                Text(L10n("work.summary"))
                    .font(.title3)
                    .fontWeight(.bold)
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
    
    private var salaryProjectionSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text(L10n("work.salary_projection"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
            }
            
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

// MARK: - Multi-Color Circle View

/// A circle divided into segments for multiple job colors
struct MultiColorCircle: View {
    let colors: [Color]
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            let anglePerSegment = 360.0 / Double(colors.count)
            
            ZStack {
                ForEach(0..<colors.count, id: \.self) { index in
                    let startAngle = Angle(degrees: Double(index) * anglePerSegment - 90)
                    let endAngle = Angle(degrees: Double(index + 1) * anglePerSegment - 90)
                    
                    Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: startAngle,
                            endAngle: endAngle,
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(colors[index].opacity(0.85))
                }
            }
        }
        .clipShape(Circle())
    }
}
