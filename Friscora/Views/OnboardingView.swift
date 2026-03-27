//
//  OnboardingView.swift
//  Friscora
//
//  Onboarding flow for first-time users with beautiful, sophisticated UI
//

import SwiftUI
import LocalAuthentication

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCurrencyPicker = false
    @State private var showBiometricAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Step content
                            if viewModel.currentStep == 1 {
                                step1View
                            } else if viewModel.currentStep == 2 {
                                step2View
                            } else if viewModel.currentStep == 3 {
                                step3View
                            } else {
                                step4View
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                    
                    // Navigation buttons
                    navigationButtons
                        .padding(24)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppColorTheme.background.opacity(0.95),
                                    AppColorTheme.background
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .alert(String(format: L10n("onboarding.enable_biometric_title"), AuthenticationService.shared.biometricType == .faceID ? L10n("auth.face_id") : L10n("auth.touch_id")), isPresented: $showBiometricAlert) {
                Button(L10n("onboarding.enable")) {
                    viewModel.biometricEnabled = true
                }
                Button(L10n("onboarding.not_now"), role: .cancel) {
                    viewModel.biometricEnabled = false
                }
            } message: {
                Text(String(format: L10n("onboarding.face_id_message"), AuthenticationService.shared.biometricType == .faceID ? L10n("auth.face_id") : L10n("auth.touch_id")))
            }
        }
    }
    
    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(1...4, id: \.self) { step in
                    Circle()
                        .fill(step <= viewModel.currentStep ? AppColorTheme.textPrimary : AppColorTheme.textTertiary)
                        .frame(width: 10, height: 10)
                        .scaleEffect(step == viewModel.currentStep ? 1.2 : 1.0)
                        .animation(AppAnimation.standard, value: viewModel.currentStep)
                }
            }
            
            ProgressView(value: Double(viewModel.currentStep), total: 4)
                .progressViewStyle(.linear)
                .tint(AppColorTheme.accent)
                .frame(height: 3)
        }
    }
    
    // MARK: - Step 1 View
    private var step1View: some View {
        VStack(spacing: 24) {
            // App Logo
            Image("app-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .padding(.top, 8)
            
            VStack(spacing: 8) {
            Text(L10n("onboarding.welcome"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(AppColorTheme.textPrimary)
            
            Text(L10n("onboarding.subtitle"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                .multilineTextAlignment(.center)
            }
            
            // Currency Selection
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n("onboarding.select_currency"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Button {
                    showCurrencyPicker = true
                } label: {
                    HStack {
                        Text(viewModel.selectedCurrency)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColorTheme.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.15))
                    )
                }
            }
            .padding(.top, 8)
            
            // Income Entry Section
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n("onboarding.add_income"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                ForEach(Array(viewModel.incomes.enumerated()), id: \.element.id) { index, incomeEntry in
                    ModernIncomeEntryView(
                        income: Binding(
                            get: { viewModel.incomes[index] },
                            set: { viewModel.incomes[index] = $0 }
                        ),
                        currency: viewModel.selectedCurrency,
                        canRemove: viewModel.incomes.count > 1,
                        onRemove: {
                            withAnimation(AppAnimation.standard) {
                                viewModel.removeIncome(at: index)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                Button {
                    withAnimation(AppAnimation.standard) {
                        viewModel.addIncome()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(L10n("onboarding.add_another_income"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.2))
                    )
                }
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet(selectedCurrency: $viewModel.selectedCurrency, currencies: viewModel.currencies)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
    
    // MARK: - Step 2 View
    private var step2View: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColorTheme.accent,
                                AppColorTheme.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: AppColorTheme.accent.opacity(0.4), radius: 20, x: 0, y: 10)
                
            Image(systemName: "target")
                    .font(.system(size: 50, weight: .bold))
                .foregroundColor(AppColorTheme.textPrimary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 12) {
            Text(L10n("onboarding.your_goal"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(AppColorTheme.textPrimary)
            
            Text(L10n("onboarding.goal_question"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                .multilineTextAlignment(.center)
            }
            
            // Goal Selection
            VStack(spacing: 16) {
                ForEach(FinancialGoal.allCases, id: \.self) { goal in
                    GoalSelectionButton(
                        goal: goal,
                        isSelected: viewModel.selectedGoal == goal,
                        action: {
                            withAnimation(AppAnimation.standard) {
                                viewModel.selectedGoal = goal
                            }
                            impactFeedback(style: .medium)
                        }
                    )
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 3 View (Notifications)
    private var step3View: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColorTheme.accent,
                                AppColorTheme.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: AppColorTheme.accent.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Text(L10n("onboarding.notifications"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Text(L10n("onboarding.notifications_subtitle"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Notifications Section
            VStack(alignment: .leading, spacing: 16) {
                // Morning notification
                NotificationToggleRow(
                    title: L10n("onboarding.morning_reminder"),
                    subtitle: L10n("onboarding.morning_subtitle"),
                    isOn: $viewModel.morningNotificationEnabled
                )
                
                // Evening notification
                NotificationToggleRow(
                    title: L10n("onboarding.evening_reminder"),
                    subtitle: L10n("onboarding.evening_subtitle"),
                    isOn: $viewModel.eveningNotificationEnabled
                )
                
                // Custom notification
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: $viewModel.customNotificationEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n("onboarding.custom_reminder"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(AppColorTheme.textPrimary)
                            Text(L10n("onboarding.custom_reminder_subtitle"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColorTheme.textSecondary)
                        }
                    }
                    .tint(AppColorTheme.accent)
                    
                    if viewModel.customNotificationEnabled {
                        DatePicker("", selection: $viewModel.customNotificationTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .colorScheme(.dark)
                            .accentColor(AppColorTheme.accent)
                            .padding(.top, 8)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Step 4 View (Authentication)
    private var step4View: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColorTheme.accent,
                                AppColorTheme.accent.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: AppColorTheme.accent.opacity(0.4), radius: 20, x: 0, y: 10)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            .padding(.top, 20)
            
            VStack(spacing: 12) {
                Text(L10n("onboarding.security"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Text(L10n("onboarding.security_subtitle"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Authentication Section
            if viewModel.passcodeStep == 1 {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 24) {
                        PasscodeEntryView(
                            passcode: $viewModel.passcode,
                            title: L10n("onboarding.create_passcode"),
                            subtitle: L10n("onboarding.create_passcode_subtitle")
                        ) {
                            // Passcode entered, move to confirm
                            if viewModel.passcode.count == 4 {
                                withAnimation(AppAnimation.standard) {
                                    viewModel.passcodeStep = 2
                                    viewModel.confirmPasscode = ""
                                }
                            }
                        }
                        
                    Button {
                            viewModel.skipAuthentication()
                    } label: {
                            Text(L10n("onboarding.skip"))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(AppColorTheme.textSecondary)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            } else if viewModel.passcodeStep == 2 {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 24) {
                        PasscodeEntryView(
                            passcode: $viewModel.confirmPasscode,
                            title: L10n("onboarding.confirm_passcode"),
                            subtitle: L10n("onboarding.confirm_passcode_subtitle")
                        ) {
                            // Check if passcodes match
                            if viewModel.confirmPasscode.count == 4 {
                                if viewModel.passcode == viewModel.confirmPasscode {
                                    // Show biometric prompt after a delay to ensure view is stable
                                    Task {
                                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                                        await MainActor.run {
                                            showBiometricPrompt()
                                        }
                                    }
                                } else {
                                    // Passcodes don't match, reset
                                    viewModel.confirmPasscode = ""
                                    viewModel.passcode = ""
                                    viewModel.passcodeStep = 1
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
        }
    }
    
    private func showBiometricPrompt() {
        let authService = AuthenticationService.shared
        // Check if biometric is available and passcode is set
        guard authService.isBiometricAvailable,
              viewModel.passcode.count == 4,
              viewModel.confirmPasscode.count == 4,
              viewModel.passcode == viewModel.confirmPasscode else {
            viewModel.biometricEnabled = false
            return
        }
        
        // Show biometric alert after a delay to ensure view is stable
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await MainActor.run {
                showBiometricAlert = true
            }
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep > 1 {
                Button {
                    withAnimation(AppAnimation.standard) {
                        viewModel.currentStep -= 1
                    }
                    impactFeedback(style: .light)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text(L10n("onboarding.back"))
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.15))
                    )
                }
            }
            
            Button {
                if viewModel.currentStep == 4 {
                    viewModel.completeOnboarding()
                    dismiss()
                } else {
                    withAnimation(AppAnimation.standard) {
                        viewModel.currentStep += 1
                    }
                }
                impactFeedback(style: .medium)
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.currentStep == 4 ? L10n("onboarding.get_started") : L10n("onboarding.next"))
                        .font(.system(size: 17, weight: .semibold))
                    
                    if viewModel.currentStep < 4 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundColor(AppColorTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canProceed ?
                        [
                            AppColorTheme.accent,
                            AppColorTheme.accent.opacity(0.8)
                        ] :
                        [
                            AppColorTheme.textTertiary,
                            Color.white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(
                    color: canProceed ? AppColorTheme.accent.opacity(0.4) : Color.clear,
                    radius: 15, x: 0, y: 8
                )
            }
            .disabled(!canProceed)
            .opacity(canProceed ? 1.0 : 0.6)
        }
    }
    
    private var canProceed: Bool {
        switch viewModel.currentStep {
        case 1: return viewModel.canProceedToStep2
        case 2: return viewModel.canProceedToStep3
        case 3: return true // Notifications can always proceed
        case 4: return viewModel.canComplete
        default: return false
        }
    }
    
    private func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - Modern Income Entry View
struct ModernIncomeEntryView: View {
    @Binding var income: IncomeEntry
    let currency: String
    let canRemove: Bool
    let onRemove: () -> Void
    @FocusState private var isAmountFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if canRemove {
            HStack {
                    Spacer()
                    Button {
                        onRemove()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColorTheme.textSecondary)
                    }
                }
            }
            
            // Amount Input
            HStack(spacing: 12) {
                // Currency Badge
                Text(currency)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                AppColorTheme.accentGradient
                            )
                    )
                    .shadow(color: AppColorTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Amount Field (comma thousands separator)
                TextField("0", text: Binding(
                    get: { CurrencyFormatter.formatAmountForDisplay(income.amount) },
                    set: { income.amount = CurrencyFormatter.stripAmountFormatting($0) }
                ))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
            }
            
            // Date Picker
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(AppColorTheme.textSecondary)
                    .font(.system(size: 16))
                
                AutoDismissDatePicker(selection: $income.date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .colorScheme(.dark)
                .accentColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isAmountFocused ? Color.white.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1.5)
                )
        )
        .scaleEffect(isAmountFocused ? 1.02 : 1.0)
        .animation(AppAnimation.standard, value: isAmountFocused)
    }
}

// MARK: - Goal Selection Button
struct GoalSelectionButton: View {
    let goal: FinancialGoal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            AppColorTheme.accentGradient :
                            LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: goalIcon(goal))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppColorTheme.textPrimary)
                }
                
                // Text
                Text(goal.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColorTheme.textPrimary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        isSelected ?
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.15),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? AppColorTheme.accent.opacity(0.3) : Color.clear,
                radius: 15, x: 0, y: 8
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private func goalIcon(_ goal: FinancialGoal) -> String {
        switch goal {
        case .saveMore: return "banknote.fill"
        case .payDebt: return "creditcard.fill"
        case .controlSpending: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - App Icon View
struct AppIconView: View {
    var body: some View {
        ZStack {
            // Background matching app icon
            RoundedRectangle(cornerRadius: 26)
                .fill(AppColorTheme.background)
            
            // Stylized F icon (representing Friscora)
            VStack(spacing: -8) {
                // Top curve (lightest teal)
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColorTheme.positive)
                    .frame(width: 60, height: 12)
                    .offset(x: 8, y: 0)
                
                // Middle curve (medium teal)
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColorTheme.accent.opacity(0.8))
                    .frame(width: 60, height: 12)
                    .offset(x: 8, y: 0)
                
                // Bottom curve (darkest teal)
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColorTheme.accent.opacity(0.6))
                    .frame(width: 60, height: 12)
                    .offset(x: 8, y: 0)
            }
        }
    }
}

// MARK: - Notification Toggle Row
struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(AppColorTheme.textSecondary)
            }
        }
        .tint(AppColorTheme.accent)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Currency Picker Sheet
struct CurrencyPickerSheet: View {
    @Binding var selectedCurrency: String
    let currencies: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    var filteredCurrencies: [String] {
        if searchText.isEmpty {
            return currencies
        }
        return currencies.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField(L10n("onboarding.search_currency"), text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(AppColorTheme.elevatedBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Currency list
                List {
                    ForEach(filteredCurrencies, id: \.self) { currency in
                        Button {
                            selectedCurrency = currency
                            dismiss()
                        } label: {
                            HStack {
                                Text(currency)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedCurrency == currency {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(L10n("onboarding.select_currency_sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

