//
//  JobDetailView.swift
//  Friscora
//
//  View for adding/editing job details
//

import SwiftUI

struct JobDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workScheduleService = WorkScheduleService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    
    let job: Job?
    @State private var name: String = ""
    @State private var paymentType: PaymentType = .hourly
    @State private var hourlyRateText: String = ""
    @State private var fixedMonthlyText: String = ""
    @State private var rateAmountDisplay: String = ""
    @State private var salaryType: SalaryType = .monthly
    @State private var selectedPaymentDays: Set<Int> = []
    @State private var selectedColor: Color = Color(hex: "2EC4B6")
    @State private var shifts: [Shift] = []
    @State private var showingDeleteConfirmation = false
    @State private var showPaymentDayClarification = false
    @State private var paymentDayClarificationDay: Int = 1
    @State private var salaryPaidNextMonth: Bool = true
    
    // Predefined color options
    private let colorOptions: [Color] = [
        Color(hex: "2EC4B6"), // Teal
        Color(hex: "3B82F6"), // Blue
        Color(hex: "8B5CF6"), // Purple
        Color(hex: "EC4899"), // Pink
        Color(hex: "F59E0B"), // Amber
        Color(hex: "10B981"), // Green
        Color(hex: "EF4444"), // Red
        Color(hex: "06B6D4"), // Cyan
    ]
    
    private var isEditing: Bool {
        job != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColorTheme.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Name section
                        nameSection
                        
                        // Payment type section
                        paymentTypeSection
                        
                        // Rate/Amount section
                        rateAmountSection
                        
                        // Shifts section
                        shiftsSection
                        
                        // Salary type section
                        salaryTypeSection
                        
                        // Payment days section
                        paymentDaysSection
                        
                        // Color selection section
                        colorSection
                        
                        // Delete button (only when editing)
                        if isEditing {
                            deleteSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .dismissKeyboardOnBackgroundTap()
            }
            .navigationTitle(isEditing ? L10n("job_detail.edit_job") : L10n("new_job.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n("common.save")) {
                        saveJob()
                    }
                    .foregroundColor(AppColorTheme.accent)
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
            .onAppear {
                loadJobData()
            }
            .alert(L10n("job_detail.delete_job"), isPresented: $showingDeleteConfirmation) {
                Button(L10n("common.cancel"), role: .cancel) { }
                Button(L10n("common.delete"), role: .destructive) {
                    deleteJob()
                }
            } message: {
                if let job = job {
                    Text(String(format: L10n("job.delete_confirm"), job.name))
                }
            }
            .alert(L10n("job.payment_day_clarification_title"), isPresented: $showPaymentDayClarification) {
                Button(L10n("common.yes")) {
                    salaryPaidNextMonth = true
                }
                Button(L10n("common.no")) {
                    salaryPaidNextMonth = false
                }
            } message: {
                Text(paymentDayClarificationYesNoMessage)
            }
        }
    }
    
    private var paymentDayClarificationMessage: String {
        let calendar = Calendar.current
        let now = Date()
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "MMMM"
        let currentName = formatter.string(from: currentMonthStart)
        let nextName = formatter.string(from: nextMonthStart)
        return String(format: L10n("job.payment_day_clarification_message"), currentName, nextName, paymentDayClarificationDay)
    }
    
    private var paymentDayClarificationYesNoMessage: String {
        let calendar = Calendar.current
        let now = Date()
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = LocalizationManager.shared.currentLocale
        formatter.dateFormat = "MMMM"
        let currentName = formatter.string(from: currentMonthStart)
        let nextName = formatter.string(from: nextMonthStart)
        return String(format: L10n("job.payment_day_clarification_yes_no"), currentName, nextName, paymentDayClarificationDay)
    }
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("job.name"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
            
            TextField("e.g., Software Engineer", text: $name)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColorTheme.elevatedBackground)
                .foregroundColor(AppColorTheme.textPrimary)
                .cornerRadius(12)
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private var paymentTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("job.payment_type"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
            
            HStack(spacing: 12) {
                ForEach(PaymentType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(AppAnimation.standard) {
                            paymentType = type
                        }
                        impactFeedback(style: .light)
                    } label: {
                        Text(L10n(type.localizationKey))
                            .font(.subheadline)
                            .fontWeight(paymentType == type ? .semibold : .regular)
                            .foregroundColor(paymentType == type ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                paymentType == type
                                    ? selectedColor.opacity(0.3)
                                    : AppColorTheme.elevatedBackground
                            )
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var rateAmountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(paymentType == .hourly ? L10n("job.hourly_rate") : L10n("job.fixed_monthly_amount"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
            
            HStack(spacing: 12) {
                AmountInputWithCustomKeyboard(
                    amountDisplay: $rateAmountDisplay,
                    focusTrigger: 0,
                    onFormatChange: { stripped in
                        if paymentType == .hourly {
                            hourlyRateText = stripped
                        } else {
                            fixedMonthlyText = stripped
                        }
                    },
                    onFocusChange: nil
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppColorTheme.elevatedBackground)
                .cornerRadius(12)
                
                Text(userProfileService.profile.currency)
                    .font(.body)
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            .onChange(of: paymentType) { _, _ in
                rateAmountDisplay = CurrencyFormatter.formatAmountForDisplay(
                    paymentType == .hourly ? hourlyRateText : fixedMonthlyText
                )
            }
            .onAppear {
                rateAmountDisplay = CurrencyFormatter.formatAmountForDisplay(
                    paymentType == .hourly ? hourlyRateText : fixedMonthlyText
                )
            }
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private var salaryTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("job.salary_payment_type"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
            
            VStack(spacing: 10) {
                ForEach(SalaryType.allCases, id: \.self) { type in
                    Button {
                        withAnimation(AppAnimation.standard) {
                            salaryType = type
                            selectedPaymentDays.removeAll()
                        }
                        impactFeedback(style: .light)
                    } label: {
                        HStack {
                            Text(L10n(type.localizationKey))
                                .foregroundColor(salaryType == type ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                                .fontWeight(salaryType == type ? .semibold : .regular)
                            
                            Spacer()
                            
                            if salaryType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(selectedColor)
                                    .font(.body)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            salaryType == type
                                ? selectedColor.opacity(0.2)
                                : AppColorTheme.elevatedBackground
                        )
                        .cornerRadius(12)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var paymentDaysSection: some View {
        if salaryType != .daily {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n("job.payment_days"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                
                switch salaryType {
                case .monthly:
                    monthlyPaymentDaysView
                case .twiceMonthly:
                    twiceMonthlyPaymentDaysView
                case .weekly:
                    weeklyPaymentDaysView
                case .daily:
                    EmptyView()
                }
            }
            .padding(16)
            .background(AppColorTheme.cardBackground)
            .cornerRadius(16)
        }
    }
    
    private var monthlyPaymentDaysView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("job.select_day_of_month"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        withAnimation(AppAnimation.snappy) {
                            if selectedPaymentDays.contains(day) {
                                selectedPaymentDays.remove(day)
                            } else {
                                selectedPaymentDays.removeAll()
                                selectedPaymentDays.insert(day)
                                paymentDayClarificationDay = day
                                showPaymentDayClarification = true
                            }
                        }
                        impactFeedback(style: .light)
                    } label: {
                        Text("\(day)")
                            .font(.subheadline)
                            .fontWeight(selectedPaymentDays.contains(day) ? .semibold : .regular)
                            .foregroundColor(selectedPaymentDays.contains(day) ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedPaymentDays.contains(day)
                                    ? selectedColor.opacity(0.3)
                                    : AppColorTheme.elevatedBackground
                            )
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var twiceMonthlyPaymentDaysView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("job.select_two_days"))
                .font(.subheadline)
                .foregroundColor(AppColorTheme.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    Button {
                        withAnimation(AppAnimation.snappy) {
                            if selectedPaymentDays.contains(day) {
                                selectedPaymentDays.remove(day)
                            } else if selectedPaymentDays.count < 2 {
                                selectedPaymentDays.insert(day)
                            }
                        }
                        impactFeedback(style: .light)
                    } label: {
                        Text("\(day)")
                            .font(.subheadline)
                            .fontWeight(selectedPaymentDays.contains(day) ? .semibold : .regular)
                            .foregroundColor(selectedPaymentDays.contains(day) ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(
                                selectedPaymentDays.contains(day)
                                    ? selectedColor.opacity(0.3)
                                    : AppColorTheme.elevatedBackground
                            )
                            .cornerRadius(8)
                            .opacity(selectedPaymentDays.count >= 2 && !selectedPaymentDays.contains(day) ? 0.5 : 1.0)
                    }
                    .disabled(selectedPaymentDays.count >= 2 && !selectedPaymentDays.contains(day))
                }
            }
        }
    }
    
    private var weeklyPaymentDaysView: some View {
        VStack(spacing: 10) {
            let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            ForEach(1...7, id: \.self) { dayIndex in
                Button {
                    withAnimation(AppAnimation.snappy) {
                        if selectedPaymentDays.contains(dayIndex) {
                            selectedPaymentDays.remove(dayIndex)
                        } else {
                            selectedPaymentDays.removeAll()
                            selectedPaymentDays.insert(dayIndex)
                        }
                    }
                    impactFeedback(style: .light)
                } label: {
                    HStack {
                        Text(weekdays[dayIndex - 1])
                            .foregroundColor(selectedPaymentDays.contains(dayIndex) ? AppColorTheme.textPrimary : AppColorTheme.textSecondary)
                            .fontWeight(selectedPaymentDays.contains(dayIndex) ? .semibold : .regular)
                        
                        Spacer()
                        
                        if selectedPaymentDays.contains(dayIndex) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(selectedColor)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        selectedPaymentDays.contains(dayIndex)
                            ? selectedColor.opacity(0.2)
                            : AppColorTheme.elevatedBackground
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var shiftsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n("job.shifts"))
                    .font(.headline)
                    .foregroundColor(AppColorTheme.textPrimary)
                Spacer()
                Button {
                    let defaultStart = 9 * 60
                    let defaultEnd = 17 * 60
                    shifts.append(Shift(name: L10n("shift.morning"), startMinutesFromMidnight: defaultStart, endMinutesFromMidnight: defaultEnd))
                    HapticHelper.selection()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                        Text(L10n("job.add_shift"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(selectedColor)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(shifts.indices, id: \.self) { index in
                    shiftRow(shift: $shifts[index], jobColor: selectedColor) {
                        shifts.remove(at: index)
                        HapticHelper.lightImpact()
                    }
                }
            }
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private func shiftRow(shift: Binding<Shift>, jobColor: Color, onDelete: @escaping () -> Void) -> some View {
        let startDate = Binding(
            get: { dateFromMinutes(shift.wrappedValue.startMinutesFromMidnight) },
            set: { shift.wrappedValue.startMinutesFromMidnight = minutesFromDate($0) }
        )
        let endDate = Binding(
            get: { dateFromMinutes(shift.wrappedValue.endMinutesFromMidnight) },
            set: { shift.wrappedValue.endMinutesFromMidnight = minutesFromDate($0) }
        )
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n("shift.name_label"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    HStack(spacing: 8) {
                        TextField(L10n("shift.name_placeholder"), text: shift.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColorTheme.textPrimary)
                        Image(systemName: "pencil.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(jobColor.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColorTheme.elevatedBackground)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppColorTheme.textTertiary.opacity(0.4), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(AppColorTheme.negative)
                }
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n("shift.start_time"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    DatePicker("", selection: startDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(jobColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n("shift.end_time"))
                        .font(.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                    DatePicker("", selection: endDate, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(jobColor)
                }
                Text(String(format: "%.1fh", shift.wrappedValue.durationHours))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(jobColor)
            }
        }
        .padding(12)
        .background(AppColorTheme.elevatedBackground)
        .cornerRadius(12)
    }
    
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n("job.calendar_color"))
                .font(.headline)
                .foregroundColor(AppColorTheme.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.self) { color in
                        Button {
                            withAnimation(AppAnimation.snappy) {
                                selectedColor = color
                            }
                            impactFeedback(style: .light)
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? AppColorTheme.textPrimary : Color.clear, lineWidth: 3)
                                )
                                .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(AppColorTheme.cardBackground)
        .cornerRadius(16)
    }
    
    private var deleteSection: some View {
        VStack(spacing: 0) {
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text(L10n("job_detail.delete_job"))
                        .font(.headline)
                        .foregroundColor(AppColorTheme.negative)
                    Spacer()
                }
                .padding(.vertical, 16)
                .background(AppColorTheme.cardBackground)
                .cornerRadius(16)
            }
        }
    }
    
    private var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        
        if paymentType == .hourly {
            guard let rate = CurrencyFormatter.parsedAmount(from: hourlyRateText), rate > 0 else { return false }
        } else {
            guard let amount = CurrencyFormatter.parsedAmount(from: fixedMonthlyText), amount > 0 else { return false }
        }
        
        if salaryType != .daily {
            guard !selectedPaymentDays.isEmpty else { return false }
        }
        
        return true
    }
    
    private func loadJobData() {
        if let job = job {
            name = job.name
            paymentType = job.paymentType
            hourlyRateText = job.hourlyRate.map { String(format: "%.2f", $0) } ?? ""
            fixedMonthlyText = job.fixedMonthlyAmount.map { String(format: "%.2f", $0) } ?? ""
            salaryType = job.salaryType
            selectedPaymentDays = Set(job.paymentDays)
            selectedColor = job.color
            shifts = job.shifts
            salaryPaidNextMonth = job.salaryPaidNextMonth
            rateAmountDisplay = CurrencyFormatter.formatAmountForDisplay(
                paymentType == .hourly ? hourlyRateText : fixedMonthlyText
            )
        }
    }
    
    private func saveJob() {
        guard isValid else { return }
        
        let hourlyRate = paymentType == .hourly ? CurrencyFormatter.parsedAmount(from: hourlyRateText) : nil
        let fixedMonthly = paymentType == .fixedMonthly ? CurrencyFormatter.parsedAmount(from: fixedMonthlyText) : nil
        let colorHex = selectedColor.toHex()
        
        let updatedJob = Job(
            id: job?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            paymentType: paymentType,
            hourlyRate: hourlyRate,
            fixedMonthlyAmount: fixedMonthly,
            salaryType: salaryType,
            paymentDays: Array(selectedPaymentDays).sorted(),
            colorHex: colorHex,
            shifts: shifts,
            salaryPaidNextMonth: salaryPaidNextMonth
        )
        
        if isEditing {
            workScheduleService.updateJob(updatedJob)
        } else {
            workScheduleService.addJob(updatedJob)
        }
        
        impactFeedback(style: .medium)
        dismiss()
    }
    
    private func deleteJob() {
        guard let job = job else { return }
        
        workScheduleService.deleteJob(job)
        impactFeedback(style: .medium)
        dismiss()
    }
    
    private func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// Helper extension to convert Color to hex string
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        
        return String(format: "%06X", rgb)
    }
}
