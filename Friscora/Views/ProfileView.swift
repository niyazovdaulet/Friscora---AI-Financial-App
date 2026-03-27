//
//  ProfileView.swift
//  Friscora
//
//  User profile and settings view
//

import SwiftUI
import StoreKit
import UIKit

struct ProfileView: View {
    @StateObject private var userProfileService = UserProfileService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingCurrencySettings = false
    @State private var showingNotificationsSettings = false
    @State private var showingICloudSync = false
    @State private var showingExportData = false
    @State private var showingEraseData = false
    @State private var showingRateApp = false
    @State private var showingFeedback = false
    @State private var showingAuthSetup = false
    @State private var showingAuthDisable = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
            Form {
                    // Section 1: General
                    Section(L10n("settings.general")) {
                    // Language
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(AppColorTheme.sapphire)
                                .frame(width: 24)
                            Text(L10n("settings.language"))
                        }
                    }
                    
                    // Notifications
                    NavigationLink {
                        NotificationsSettingsView()
                    } label: {
                    HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(L10n("settings.notifications"))
                        }
                    }
                    
                    // Currency
                    NavigationLink {
                        CurrencySettingsView()
                    } label: {
                    HStack {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                        Text(L10n("settings.currency"))
                        Spacer()
                        Text(userProfileService.profile.currency)
                            .foregroundColor(.secondary)
                    }
                }
                
                    // Authentication
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text(L10n("settings.authentication"))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { userProfileService.profile.isAuthenticationEnabled },
                            set: { newValue in
                                if newValue {
                                    // Enable authentication - show setup
                                    showingAuthSetup = true
                                } else {
                                    // Disable authentication - require verification
                                    showingAuthDisable = true
                                }
                            }
                        ))
                    }
                    .sheet(isPresented: $showingAuthSetup) {
                        AuthenticationSetupView(isPresented: $showingAuthSetup)
                            .presentationCornerRadius(24)
                            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    }
                    .sheet(isPresented: $showingAuthDisable) {
                        AuthenticationDisableView(isPresented: $showingAuthDisable)
                            .presentationCornerRadius(24)
                            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    }
                }
                
                // Section 2: Data
                Section(L10n("settings.data")) {
                    // iCloud Sync
                    NavigationLink {
                        ICloudSyncView()
                    } label: {
                        HStack {
                            Image(systemName: "icloud.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(L10n("settings.icloud_sync"))
                        }
                    }
                    
                    // Export Data
                    NavigationLink {
                        ExportDataView()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text(L10n("settings.export_data"))
                        }
                    }
                    
                    // Erase Data
                    NavigationLink {
                        EraseDataView()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                                .frame(width: 24)
                            Text(L10n("settings.erase_data"))
                        }
                    }
                }
                
                // Section 3: Others
                Section(L10n("settings.others")) {
                    // About - App Version
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text(L10n("settings.about"))
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    // Feedback
                    Button {
                        HapticHelper.lightImpact()
                        showingFeedback = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(L10n("settings.feedback"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(AppColorTheme.textTertiary)
                        }
                    }
                    .foregroundColor(AppColorTheme.textPrimary)
                    .sheet(isPresented: $showingFeedback) {
                        FeedbackView(isPresented: $showingFeedback)
                            .presentationCornerRadius(24)
                            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    }
                }
                
                // Rate App Button Section
                Section {
                    Button {
                        HapticHelper.lightImpact()
                        requestAppReview()
                    } label: {
                        HStack(spacing: 16) {
                            // Icon in circle with gradient
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.yellow.opacity(0.3),
                                                Color.yellow.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)
                                
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 20))
                            }
                            
                            // Text content
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n("settings.tap_to_rate"))
                                    .font(.headline)
                                    .foregroundColor(AppColorTheme.textPrimary)
                                
                                Text(L10n("settings.help_improve"))
                                    .font(.caption)
                                    .foregroundColor(AppColorTheme.textSecondary)
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
                    .buttonStyle(.plain)
                }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(L10n("settings.title"))
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func requestAppReview() {
        // Request in-app review using StoreKit
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

// MARK: - Currency Settings View
struct CurrencySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var userProfileService = UserProfileService.shared
    
    @State private var selectedCurrency: String = "PLN"
    
    // All major currencies
    let currencies = [
        "USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "HKD", "NZD",
        "SEK", "KRW", "SGD", "NOK", "MXN", "INR", "RUB", "BYN", "ZAR", "TRY", "BRL",
        "TWD", "DKK", "PLN", "THB", "IDR", "HUF", "CZK", "ILS", "CLP", "PHP",
        "AED", "COP", "SAR", "MYR", "RON", "BGN", "PKR", "NGN", "EGP", "VND",
        "BDT", "ARS", "UAH", "IQD", "MAD", "KZT", "QAR", "OMR", "KWD", "BHD"
    ]
    
    var body: some View {
            Form {
            Section {
                Picker(L10n("settings.currency"), selection: $selectedCurrency) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency).tag(currency)
                    }
                }
            } footer: {
                Text(L10n("settings.currency_convert_message"))
            }
        }
        .navigationTitle(L10n("settings.currency"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedCurrency = userProfileService.profile.currency
        }
        .onChange(of: selectedCurrency) { newCurrency in
            saveCurrency(newCurrency)
        }
    }
    
    private func saveCurrency(_ newCurrency: String) {
        let oldCurrency = userProfileService.profile.currency
        
        var profile = userProfileService.profile
        profile.currency = newCurrency
        userProfileService.saveProfile(profile)
        
        // Convert all expenses, incomes, and goals if currency changed
        if oldCurrency != newCurrency {
            Task {
                await convertAllTransactions(from: oldCurrency, to: newCurrency)
                await GoalService.shared.convertGoals(from: oldCurrency, to: newCurrency)
                
                // Notify that conversion is complete
                await MainActor.run {
                    ExpenseService.shared.loadExpenses()
                    IncomeService.shared.loadIncomes()
                }
            }
        }
    }
    
    private func convertAllTransactions(from oldCurrency: String, to newCurrency: String) async {
        let currencyService = CurrencyService.shared
        let expenseService = ExpenseService.shared
        let incomeService = IncomeService.shared
        
        // Convert expenses
        for expense in expenseService.expenses {
            if expense.currency != newCurrency {
                do {
                    let convertedAmount = try await currencyService.convert(
                        amount: expense.amount,
                        from: expense.currency,
                        to: newCurrency
                    )
                    var updatedExpense = expense
                    updatedExpense.amount = convertedAmount
                    updatedExpense.currency = newCurrency
                    expenseService.updateExpense(updatedExpense)
                } catch {
                    print("Failed to convert expense: \(error)")
                }
            }
        }
        
        // Convert incomes
        for income in incomeService.incomes {
            if income.currency != newCurrency {
                do {
                    let convertedAmount = try await currencyService.convert(
                        amount: income.amount,
                        from: income.currency,
                        to: newCurrency
                    )
                    var updatedIncome = income
                    updatedIncome.amount = convertedAmount
                    updatedIncome.currency = newCurrency
                    incomeService.updateIncome(updatedIncome)
                } catch {
                    print("Failed to convert income: \(error)")
                }
            }
        }
    }
}

// MARK: - Notifications Settings View
struct NotificationsSettingsView: View {
    @StateObject private var notificationService = NotificationService.shared
    @State private var schedule: NotificationSchedule
    
    init() {
        _schedule = State(initialValue: NotificationService.shared.getSchedule())
    }
    
    var body: some View {
        Form {
            Section(L10n("settings.morning_reminder")) {
                Toggle(L10n("settings.enable"), isOn: $schedule.morningEnabled)
                
                if schedule.morningEnabled {
                    DatePicker(L10n("settings.time"), selection: $schedule.morningTime, displayedComponents: .hourAndMinute)
                }
            }
            
            Section(L10n("settings.evening_reminder")) {
                Toggle(L10n("settings.enable"), isOn: $schedule.eveningEnabled)
                
                if schedule.eveningEnabled {
                    DatePicker(L10n("settings.time"), selection: $schedule.eveningTime, displayedComponents: .hourAndMinute)
                }
            }
            
            Section(L10n("settings.custom_reminder")) {
                Toggle(L10n("settings.enable"), isOn: $schedule.customEnabled)
                
                if schedule.customEnabled {
                    if let customTime = schedule.customTime {
                        DatePicker(L10n("settings.time"), selection: Binding(
                            get: { customTime },
                            set: { schedule.customTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                    } else {
                        DatePicker(L10n("settings.time"), selection: Binding(
                            get: { Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date() },
                            set: { schedule.customTime = $0 }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            }
        }
        .navigationTitle(L10n("notifications.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: schedule.morningEnabled) { _ in
            notificationService.saveSchedule(schedule)
        }
        .onChange(of: schedule.morningTime) { _ in
            notificationService.saveSchedule(schedule)
        }
        .onChange(of: schedule.eveningEnabled) { _ in
            notificationService.saveSchedule(schedule)
        }
        .onChange(of: schedule.eveningTime) { _ in
            notificationService.saveSchedule(schedule)
        }
        .onChange(of: schedule.customEnabled) { _ in
            notificationService.saveSchedule(schedule)
        }
        .onChange(of: schedule.customTime) { _ in
            notificationService.saveSchedule(schedule)
        }
    }
}

// MARK: - iCloud Sync View
struct ICloudSyncView: View {
    @StateObject private var syncService = ICloudSyncService.shared
    
    private static var relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Text(L10n("settings.icloud_sync_status"))
                        .foregroundColor(AppColorTheme.textPrimary)
                    Spacer()
                    if syncService.isSyncing {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else if let last = syncService.lastSyncedAt {
                        Text(Self.relativeDateFormatter.localizedString(for: last, relativeTo: Date()))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                Button {
                    HapticHelper.lightImpact()
                    DispatchQueue.global(qos: .userInitiated).async {
                        syncService.syncFromCloud()
                    }
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.5) {
                        syncService.syncToCloud()
                    }
                } label: {
                    Label(L10n("settings.icloud_sync_now"), systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(syncService.isSyncing)
            } footer: {
                Text(L10n("settings.icloud_sync_footer"))
            }
        }
        .navigationTitle(L10n("settings.icloud_sync"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Export Data View
struct ExportDataView: View {
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    var body: some View {
        Form {
            Section {
                Button {
                    HapticHelper.lightImpact()
                    if let url = buildCSVExport() {
                        presentShareSheet(activityItems: [url])
                    }
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text(L10n("settings.export_as_csv"))
                    }
                }
                .disabled(hasNoData)
            } footer: {
                Text(L10n("settings.export_footer"))
            }
        }
        .navigationTitle(L10n("settings.export_data"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    /// Presents UIActivityViewController from the key window so the share sheet displays correctly (not blank).
    private func presentShareSheet(activityItems: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }
        let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        top.present(activityVC, animated: true)
    }
    
    private var hasNoData: Bool {
        ExpenseService.shared.expenses.isEmpty &&
        IncomeService.shared.incomes.isEmpty &&
        GoalService.shared.goals.isEmpty &&
        WorkScheduleService.shared.workDays.isEmpty &&
        WorkScheduleService.shared.jobs.isEmpty
    }
    
    /// Rounds to 2 decimal places to avoid floating-point display (e.g. 99.9359999 → 99.94).
    private func roundAmount(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return String(format: "%.2f", rounded)
    }
    
    private func roundHours(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return String(format: "%.2f", rounded)
    }
    
    private func buildCSVExport() -> URL? {
        let calendar = Calendar.current
        let expenseService = ExpenseService.shared
        let incomeService = IncomeService.shared
        let goalService = GoalService.shared
        let categoryService = CustomCategoryService.shared
        let workService = WorkScheduleService.shared
        let profile = UserProfileService.shared.profile
        let languageCode = LocalizationManager.shared.currentLanguageCode
        
        var csv = ""
        
        // ----- App & Language -----
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        csv += "App_Info\n"
        csv += "ExportDate,AppVersion,Build,AppLanguage,Currency\n"
        csv += "\(dateFormatter.string(from: Date())),\(version),\(build),\(languageCode),\(profile.currency)\n\n"
        
        // ----- Expenses by month (separate table per month) -----
        let expenseMonths = Set(expenseService.expenses.map { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date })
        let sortedExpenseMonths = expenseMonths.sorted(by: >)
        for monthStart in sortedExpenseMonths {
            let monthKey = dateFormatter.string(from: monthStart).prefix(7)
            let monthExpenses = expenseService.expensesForMonth(monthStart).sorted { $0.date > $1.date }
            csv += "Expenses_\(monthKey)\n"
            csv += "Date,Amount,Category,Note,Currency\n"
            for e in monthExpenses {
                let cat = e.customCategoryId.flatMap { id in categoryService.customCategories.first(where: { $0.id == id })?.name } ?? e.category.rawValue
                csv += "\(dateFormatter.string(from: e.date)),\(roundAmount(e.amount)),\(csvEscape(cat)),\(csvEscape(e.note ?? "")),\(e.currency)\n"
            }
            csv += "\n"
        }
        
        // ----- Incomes by month (separate table per month) -----
        let incomeMonths = Set(incomeService.incomes.map { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date })
        let sortedIncomeMonths = incomeMonths.sorted(by: >)
        for monthStart in sortedIncomeMonths {
            let monthKey = dateFormatter.string(from: monthStart).prefix(7)
            let monthIncomes = incomeService.incomesForMonth(monthStart).sorted { $0.date > $1.date }
            csv += "Incomes_\(monthKey)\n"
            csv += "Date,Amount,Note,Currency\n"
            for i in monthIncomes {
                csv += "\(dateFormatter.string(from: i.date)),\(roundAmount(i.amount)),\(csvEscape(i.note ?? "")),\(i.currency)\n"
            }
            csv += "\n"
        }
        
        // ----- Goals (with progress percent) -----
        let goals = goalService.goals
        csv += "Goals\n"
        csv += "Title,TargetAmount,CurrentAmount,ProgressPercent,CreatedDate,Deadline,Currency,IsCompleted\n"
        for g in goals {
            let deadline = g.deadline.map { dateFormatter.string(from: $0) } ?? ""
            let progressPct = g.targetAmount > 0 ? min(100, (g.currentAmount / g.targetAmount) * 100) : 0
            csv += "\(csvEscape(g.title)),\(roundAmount(g.targetAmount)),\(roundAmount(g.currentAmount)),\(roundAmount(progressPct)),\(dateFormatter.string(from: g.createdDate)),\(deadline),\(g.effectiveCurrency),\(g.isCompleted)\n"
        }
        csv += "\n"
        
        // ----- Goal Activities -----
        let activities = goalService.activities.sorted { $0.date > $1.date }
        if !activities.isEmpty {
            csv += "Goal_Activities\n"
            csv += "GoalTitle,Date,Amount,Note\n"
            for a in activities {
                let title = goalService.goals.first(where: { $0.id == a.goalId })?.title ?? ""
                csv += "\(csvEscape(title)),\(dateFormatter.string(from: a.date)),\(roundAmount(a.amount)),\(csvEscape(a.note ?? ""))\n"
            }
            csv += "\n"
        }
        
        // ----- Work: Jobs -----
        let jobs = workService.jobs
        if !jobs.isEmpty {
            csv += "Work_Jobs\n"
            csv += "JobName,PaymentType,HourlyRate,FixedMonthlyAmount,SalaryType,PaymentDays,SalaryPaidNextMonth,ShiftsCount\n"
            for j in jobs {
                let rate = j.hourlyRate.map { roundAmount($0) } ?? ""
                let fixed = j.fixedMonthlyAmount.map { roundAmount($0) } ?? ""
                let days = j.paymentDays.map { String($0) }.joined(separator: ";")
                csv += "\(csvEscape(j.name)),\(j.paymentType.rawValue),\(rate),\(fixed),\(j.salaryType.rawValue),\(csvEscape(days)),\(j.salaryPaidNextMonth),\(j.shifts.count)\n"
            }
            csv += "\n"
            
            // Work: Shifts (per job)
            csv += "Work_Shifts\n"
            csv += "JobName,ShiftName,StartMinutes,EndMinutes,DurationHours\n"
            for j in jobs {
                for s in j.shifts {
                    csv += "\(csvEscape(j.name)),\(csvEscape(s.name)),\(s.startMinutesFromMidnight),\(s.endMinutesFromMidnight),\(roundHours(s.durationHours))\n"
                }
            }
            csv += "\n"
            
            // Work: Work Days
            let workDays = workService.workDays.sorted { $0.date > $1.date }
            csv += "Work_Days\n"
            csv += "Date,JobName,HoursWorked,ShiftName\n"
            for w in workDays {
                let jobName = workService.job(withId: w.jobId)?.name ?? ""
                let shiftName = w.shiftId.flatMap { workService.job(withId: w.jobId)?.shift(withId: $0)?.name } ?? ""
                csv += "\(dateFormatter.string(from: w.date)),\(csvEscape(jobName)),\(roundHours(w.hoursWorked)),\(csvEscape(shiftName))\n"
            }
            csv += "\n"
            
            // Work: Monthly summary (total hours per job per month)
            let workDayMonths = Set(workDays.map { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date })
            let sortedWorkMonths = workDayMonths.sorted(by: >)
            csv += "Work_Summary_ByMonth\n"
            csv += "Month,JobName,TotalHours\n"
            for monthStart in sortedWorkMonths {
                let monthKey = dateFormatter.string(from: monthStart).prefix(7)
                for j in jobs {
                    let hours = workService.totalHoursForMonth(monthStart, jobId: j.id)
                    if hours > 0 {
                        csv += "\(monthKey),\(csvEscape(j.name)),\(roundHours(hours))\n"
                    }
                }
            }
            csv += "\n"
        }
        
        // ----- Analytics: Per-month summary -----
        let allMonths = (Set(expenseService.expenses.map { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date })
            .union(Set(incomeService.incomes.map { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date })))
        let sortedAllMonths = allMonths.sorted(by: >)
        if !sortedAllMonths.isEmpty {
            csv += "Analytics_MonthlySummary\n"
            csv += "Month,Income,Expenses,GoalAllocations,RemainingBalance\n"
            for monthStart in sortedAllMonths {
                let monthKey = dateFormatter.string(from: monthStart).prefix(7)
                let income = incomeService.totalIncomeForMonth(monthStart)
                let expenses = expenseService.totalExpensesForMonth(monthStart)
                let goalAlloc = goalService.totalGoalAllocationsForMonth(monthStart)
                let remaining = income - expenses - goalAlloc
                csv += "\(monthKey),\(roundAmount(income)),\(roundAmount(expenses)),\(roundAmount(goalAlloc)),\(roundAmount(remaining))\n"
            }
            csv += "\n"
            
            // Analytics: Category breakdown per month
            csv += "Analytics_CategoryBreakdown\n"
            csv += "Month,Category,Amount\n"
            for monthStart in sortedAllMonths {
                let monthKey = dateFormatter.string(from: monthStart).prefix(7)
                let breakdown = expenseService.expensesByCategoryDisplayForMonth(monthStart)
                for (categoryInfo, amount) in breakdown.sorted(by: { $0.key.name < $1.key.name }) {
                    csv += "\(monthKey),\(csvEscape(categoryInfo.name)),\(roundAmount(amount))\n"
                }
            }
        }
        
        let fileName = "Friscora_Export_\(dateFormatter.string(from: Date())).csv"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
    
    private func csvEscape(_ s: String) -> String {
        let needsQuotes = s.contains(",") || s.contains("\n") || s.contains("\"")
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}

// MARK: - Erase Data View
struct EraseDataView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false
    
    var body: some View {
        Form {
            Section {
                Text(L10n("settings.erase_warning"))
                    .foregroundColor(.red)
            }
            
            Section {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n("settings.erase_all_data"))
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle(L10n("settings.erase_data"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n("settings.erase_confirm_title"), isPresented: $showConfirmation) {
            Button(L10n("common.cancel"), role: .cancel) { }
            Button(L10n("common.delete"), role: .destructive) {
                eraseAllData()
            }
        } message: {
            Text(L10n("settings.erase_confirm_message"))
        }
    }
    
    private func eraseAllData() {
        // Clear all data
        ExpenseService.shared.expenses.removeAll()
        IncomeService.shared.incomes.removeAll()
        GoalService.shared.goals.removeAll()
        GoalService.shared.activities.removeAll()
        CustomCategoryService.shared.customCategories.removeAll()
        
        // Save empty arrays
        if let encoded = try? JSONEncoder().encode([Expense]()) {
            UserDefaults.standard.set(encoded, forKey: "saved_expenses")
        }
        if let encoded = try? JSONEncoder().encode([Income]()) {
            UserDefaults.standard.set(encoded, forKey: "saved_incomes")
        }
        if let encoded = try? JSONEncoder().encode([Goal]()) {
            UserDefaults.standard.set(encoded, forKey: "saved_goals")
        }
        if let encoded = try? JSONEncoder().encode([GoalActivity]()) {
            UserDefaults.standard.set(encoded, forKey: "saved_goal_activities")
        }
        if let encoded = try? JSONEncoder().encode([CustomCategory]()) {
            UserDefaults.standard.set(encoded, forKey: "saved_custom_categories")
        }
        
        // Reload services
        ExpenseService.shared.loadExpenses()
        IncomeService.shared.loadIncomes()
        GoalService.shared.loadGoals()
        GoalService.shared.loadActivities()
        CustomCategoryService.shared.customCategories.removeAll()
        if let encoded = try? JSONEncoder().encode([CustomCategory]()) {
            UserDefaults.standard.set(encoded, forKey: "saved_custom_categories")
        }
        CustomCategoryService.shared.loadCategories()
        
        dismiss()
    }
}

// MARK: - Rate App View
struct RateAppView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingAppStore = false
    
    var body: some View {
        Form {
            Section {
                Button {
                    requestAppReview()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(L10n("settings.rate_in_app"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
                
                Button {
                    openAppStore()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right.square.fill")
                            .foregroundColor(.blue)
                        Text(L10n("settings.open_app_store"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            } footer: {
                Text(L10n("settings.rate_footer"))
            }
        }
        .navigationTitle(L10n("rate_app.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func requestAppReview() {
        // Request in-app review using StoreKit
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    
    private func openAppStore() {
        // Open App Store page directly
        // Replace "YOUR_APP_STORE_ID" with your actual App Store ID
        // You can find it in App Store Connect or by searching for your app
        let appStoreID = "YOUR_APP_STORE_ID" // TODO: Replace with actual App Store ID
        let appStoreURL = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        
        if let url = URL(string: appStoreURL) {
            UIApplication.shared.open(url)
        } else {
            // Fallback: try to open using bundle identifier
            let bundleID = Bundle.main.bundleIdentifier ?? ""
            let fallbackURL = "https://apps.apple.com/app/\(bundleID)"
            if let url = URL(string: fallbackURL) {
                UIApplication.shared.open(url)
            }
        }
    }
}

