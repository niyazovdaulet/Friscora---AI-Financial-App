//
//  OnboardingView.swift
//  Friscora
//
//  Onboarding flow for first-time users with beautiful, sophisticated UI
//

import SwiftUI
import LocalAuthentication
import os

struct OnboardingView: View {
    private enum NavigationDirection {
        case forward
        case backward
    }
    
    @StateObject private var viewModel = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showCurrencyPicker = false
    @State private var showBiometricAlert = false
    @State private var showSecuritySetup = false
    @State private var heroPulse = false
    @State private var showPasscodeMismatchError = false
    @State private var navigationDirection: NavigationDirection = .forward
    @State private var passcodeConfirmationTask: Task<Void, Never>?
    @State private var biometricPromptTask: Task<Void, Never>?
    
    private let totalSetupSteps = 4
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Primary background color
                AppColorTheme.background
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            Color.clear
                                .frame(height: 0)
                                .id("onboardingTop")
                            
                            ZStack {
                                if viewModel.currentOnboardingStep == .valueSetup {
                                    step1View
                                        .transition(stepTransition)
                                } else if viewModel.currentOnboardingStep == .goal {
                                    step2View
                                        .transition(stepTransition)
                                } else if viewModel.currentOnboardingStep == .notifications {
                                    step3View
                                        .transition(stepTransition)
                                } else if viewModel.currentOnboardingStep == .security {
                                    step4View
                                        .transition(stepTransition)
                                } else {
                                    completionView
                                        .transition(stepTransition)
                                }
                            }
                            .animation(AppAnimation.standard, value: viewModel.currentStep)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 100)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: viewModel.currentStep) { _, _ in
                            withAnimation(AppAnimation.standard) {
                                proxy.scrollTo("onboardingTop", anchor: .top)
                            }
                        }
                    }
                    
                    // Navigation buttons
                    if showsBottomNavigation {
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .alert(String(format: L10n("onboarding.enable_biometric_title"), AuthenticationService.shared.biometricType == .faceID ? L10n("auth.face_id") : L10n("auth.touch_id")), isPresented: $showBiometricAlert) {
                Button(L10n("onboarding.enable")) {
                    viewModel.biometricEnabled = true
                    OnboardingLogging.trace("biometric_choice enabled=true")
                    advanceToCompletionStep()
                }
                Button(L10n("onboarding.not_now"), role: .cancel) {
                    viewModel.biometricEnabled = false
                    OnboardingLogging.trace("biometric_choice enabled=false")
                    advanceToCompletionStep()
                }
            } message: {
                Text(String(format: L10n("onboarding.face_id_message"), AuthenticationService.shared.biometricType == .faceID ? L10n("auth.face_id") : L10n("auth.touch_id")))
            }
            .onAppear {
                OnboardingLogging.trace("step_viewed step=\(viewModel.currentStep)")
            }
            .onChange(of: viewModel.currentStep) { _, step in
                OnboardingLogging.trace("step_viewed step=\(step)")
                if step != OnboardingViewModel.OnboardingStep.security.rawValue {
                    cancelSecurityTasks()
                }
            }
            .onDisappear {
                cancelSecurityTasks()
            }
        }
    }
    
    private var stepTransition: AnyTransition {
        switch navigationDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }
    
    private var showsBottomNavigation: Bool {
        (1...3).contains(viewModel.currentStep)
    }
    
    private var topBar: some View {
        HStack(alignment: .center) {
            progressIndicator
            Spacer()
            if (1...3).contains(viewModel.currentStep) {
                Button {
                    OnboardingLogging.trace("skip_tapped step=\(viewModel.currentStep)")
                    viewModel.completeOnboarding()
                    dismiss()
                } label: {
                    Text(L10n("onboarding.global_skip"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColorTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            } else if viewModel.currentStep == 4 {
                Button {
                    cancelSecurityTasks()
                    navigationDirection = .backward
                    withAnimation(AppAnimation.standard) {
                        viewModel.currentStep = 3
                        showSecuritySetup = false
                        showPasscodeMismatchError = false
                    }
                    OnboardingLogging.trace("back_tapped step=4 via_top_bar")
                    impactFeedback(style: .light)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(L10n("onboarding.back"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
    }
    
    // MARK: - Progress
    private var progressIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentStep <= totalSetupSteps ? String(format: L10n("onboarding.progress_step_of"), viewModel.currentStep, totalSetupSteps) : L10n("onboarding.progress_completed"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColorTheme.textSecondary)
            
            ProgressView(value: Double(min(viewModel.currentStep, totalSetupSteps)), total: Double(totalSetupSteps))
                .progressViewStyle(.linear)
                .tint(AppColorTheme.accent)
                .frame(height: 3)
                .frame(width: 120)
        }
    }
    
    // MARK: - Step 1 View
    private var step1View: some View {
        VStack(spacing: 18) {
            // App Logo
            Image("app-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 110, height: 110)
                .padding(.top, 0)
                .scaleEffect(heroPulse ? 1.03 : 0.97)
                .opacity(heroPulse ? 1.0 : 0.85)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroPulse)
            
            VStack(spacing: 8) {
                Text(L10n("onboarding.value_title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            
            Text(L10n("onboarding.setup_fast"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColorTheme.textSecondary)
                .padding(.top, 2)
            
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
                Text(L10n("onboarding.main_income"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                if !viewModel.incomes.isEmpty {
                    ModernIncomeEntryView(
                        income: Binding(
                            get: { viewModel.incomes[0] },
                            set: { viewModel.incomes[0] = $0 }
                        ),
                        currency: viewModel.selectedCurrency,
                        canRemove: false,
                        onRemove: {}
                    )
                }
                
                if viewModel.incomes.count > 1 {
                    ForEach(Array(viewModel.incomes.dropFirst())) { incomeEntry in
                        if let incomeIndex = viewModel.incomes.firstIndex(where: { $0.id == incomeEntry.id }) {
                            ModernIncomeEntryView(
                                income: Binding(
                                    get: { viewModel.incomes[incomeIndex] },
                                    set: { updatedIncome in
                                        guard let latestIndex = viewModel.incomes.firstIndex(where: { $0.id == incomeEntry.id }) else { return }
                                        viewModel.incomes[latestIndex] = updatedIncome
                                    }
                                ),
                                currency: viewModel.selectedCurrency,
                                canRemove: true,
                                onRemove: {
                                    withAnimation(AppAnimation.standard) {
                                        guard let latestIndex = viewModel.incomes.firstIndex(where: { $0.id == incomeEntry.id }) else { return }
                                        viewModel.removeIncome(at: latestIndex)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                }
                
                Button {
                    withAnimation(AppAnimation.standard) {
                        viewModel.addIncome()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 17))
                        Text(L10n("onboarding.add_another_income_secondary"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(AppColorTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            .padding(.top, 8)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n("onboarding.value_subtitle"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                
                VStack(spacing: 12) {
                    dashboardPreviewRow(title: L10n("onboarding.preview_income"), value: "\(viewModel.selectedCurrency) 6,000", color: AppColorTheme.positive)
                    dashboardPreviewRow(title: L10n("onboarding.preview_expenses"), value: "\(viewModel.selectedCurrency) 3,400", color: AppColorTheme.negative)
                    dashboardPreviewRow(title: L10n("onboarding.preview_remaining"), value: "\(viewModel.selectedCurrency) 2,600", color: AppColorTheme.accent)
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerSheet(selectedCurrency: $viewModel.selectedCurrency, currencies: viewModel.currencies)
                .presentationCornerRadius(24)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onAppear {
            restartHeroPulse()
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
    }
    
    private func dashboardPreviewRow(title: String, value: String, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColorTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
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
            .scaleEffect(heroPulse ? 1.03 : 0.97)
            .opacity(heroPulse ? 1.0 : 0.85)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroPulse)
            
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
                        title: localizedGoalLabel(goal),
                        isSelected: viewModel.selectedGoal == goal,
                        action: {
                            withAnimation(AppAnimation.standard) {
                                viewModel.selectedGoal = goal
                            }
                            impactFeedback(style: .medium)
                        }
                    )
                }
                
                Text(goalPersonalizationText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            .padding(.top, 20)
        }
        .onAppear {
            restartHeroPulse()
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
            .scaleEffect(heroPulse ? 1.03 : 0.97)
            .opacity(heroPulse ? 1.0 : 0.85)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroPulse)
            
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
                Text(reminderSummaryText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .padding(.horizontal, 2)
                
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
                
                VStack(alignment: .leading, spacing: 10) {
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
        .onAppear {
            restartHeroPulse()
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
            .scaleEffect(heroPulse ? 1.03 : 0.97)
            .opacity(heroPulse ? 1.0 : 0.85)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroPulse)
            
            VStack(spacing: 12) {
                Text(showSecuritySetup ? L10n("onboarding.security") : L10n("onboarding.secure_data_title"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                
                Text(showSecuritySetup ? L10n("onboarding.security_subtitle") : L10n("onboarding.secure_data_subtitle"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Authentication Section
            if !showSecuritySetup {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        OnboardingLogging.trace("passcode_enable_tapped")
                        withAnimation(AppAnimation.standard) {
                            showSecuritySetup = true
                            showPasscodeMismatchError = false
                        }
                    } label: {
                        Text(L10n("onboarding.enable_protection"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColorTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [AppColorTheme.accent, AppColorTheme.accent.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: AppColorTheme.accent.opacity(0.4), radius: 15, x: 0, y: 8)
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                    
                    Button {
                        OnboardingLogging.trace("passcode_skipped")
                        cancelSecurityTasks()
                        viewModel.skipAuthentication()
                        navigationDirection = .forward
                        withAnimation(AppAnimation.standard) {
                            viewModel.currentStep = 5
                        }
                    } label: {
                        Text(L10n("onboarding.security_skip_for_now"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColorTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                }
            } else if viewModel.passcodeStep == 1 {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 24) {
                        PasscodeEntryView(
                            passcode: $viewModel.passcode,
                            title: L10n("onboarding.create_passcode"),
                            subtitle: L10n("onboarding.create_passcode_subtitle")
                        ) {
                            if viewModel.passcode.count == 4 {
                                withAnimation(AppAnimation.standard) {
                                    viewModel.passcodeStep = 2
                                    viewModel.confirmPasscode = ""
                                    showPasscodeMismatchError = false
                                }
                            }
                        }
                        .onChange(of: viewModel.passcode) { _, newValue in
                            if !newValue.isEmpty && showPasscodeMismatchError {
                                showPasscodeMismatchError = false
                            }
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
                                    schedulePasscodeConfirmationFlow()
                                } else {
                                    showPasscodeMismatchError = true
                                    notificationFeedback(type: .error)
                                    viewModel.confirmPasscode = ""
                                }
                            }
                        }
                        .onChange(of: viewModel.confirmPasscode) { _, newValue in
                            if !newValue.isEmpty && showPasscodeMismatchError {
                                showPasscodeMismatchError = false
                            }
                        }
                        
                        if showPasscodeMismatchError {
                            Text(L10n("onboarding.passcode_mismatch_error"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColorTheme.negative)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity)
                        }
                        
                        Button {
                            cancelSecurityTasks()
                            viewModel.passcode = ""
                            viewModel.confirmPasscode = ""
                            viewModel.passcodeStep = 1
                            showPasscodeMismatchError = false
                        } label: {
                            Text(L10n("onboarding.re_enter_passcode"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColorTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                    )
                }
            }
        }
        .onAppear {
            restartHeroPulse()
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColorTheme.accent, AppColorTheme.positive],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: AppColorTheme.accent.opacity(0.35), radius: 16, x: 0, y: 8)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(AppColorTheme.textPrimary)
            }
            .padding(.top, 30)
            .scaleEffect(heroPulse ? 1.03 : 0.97)
            .opacity(heroPulse ? 1.0 : 0.85)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: heroPulse)
            
            VStack(spacing: 10) {
                Text(L10n("onboarding.completion_title"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)
                Text(L10n("onboarding.completion_subtitle"))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                completionSummaryRow(title: L10n("onboarding.summary_currency"), value: viewModel.selectedCurrency)
                completionSummaryRow(title: L10n("onboarding.summary_goal"), value: localizedGoalLabel(viewModel.selectedGoal))
                completionSummaryRow(title: L10n("onboarding.summary_reminders"), value: reminderSummaryText)
                completionSummaryRow(
                    title: L10n("onboarding.summary_security"),
                    value: viewModel.passcode.count == 4 && viewModel.confirmPasscode == viewModel.passcode
                    ? L10n("onboarding.summary_security_enabled")
                    : L10n("onboarding.summary_security_skipped")
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )
            
            Button {
                OnboardingLogging.trace("completion_confirmed")
                viewModel.completeOnboarding()
                dismiss()
            } label: {
                Text(L10n("onboarding.get_started"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [AppColorTheme.accent, AppColorTheme.accent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: AppColorTheme.accent.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(PressableScaleButtonStyle())
            .frame(minHeight: 44)
        }
        .onAppear {
            restartHeroPulse()
        }
    }
    
    private func completionSummaryRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColorTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColorTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
    
    private func continueAfterPasscodeConfirmation() {
        if canShowBiometricPrompt {
            scheduleBiometricPrompt()
        } else {
            viewModel.biometricEnabled = false
            advanceToCompletionStep()
        }
    }
    
    private var canShowBiometricPrompt: Bool {
        let authService = AuthenticationService.shared
        return authService.isBiometricAvailable &&
              viewModel.passcode.count == 4 &&
              viewModel.confirmPasscode.count == 4 &&
              viewModel.passcode == viewModel.confirmPasscode
    }
    
    private var isSecuritySetupActive: Bool {
        viewModel.currentOnboardingStep == .security && showSecuritySetup
    }
    
    private func schedulePasscodeConfirmationFlow() {
        passcodeConfirmationTask?.cancel()
        passcodeConfirmationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard isSecuritySetupActive,
                      viewModel.passcodeStep == 2,
                      viewModel.passcode.count == 4,
                      viewModel.confirmPasscode.count == 4,
                      viewModel.passcode == viewModel.confirmPasscode else {
                    return
                }
                showPasscodeMismatchError = false
                continueAfterPasscodeConfirmation()
            }
        }
    }
    
    private func scheduleBiometricPrompt() {
        biometricPromptTask?.cancel()
        biometricPromptTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard isSecuritySetupActive, canShowBiometricPrompt else { return }
                showBiometricAlert = true
            }
        }
    }
    
    private func cancelSecurityTasks() {
        passcodeConfirmationTask?.cancel()
        passcodeConfirmationTask = nil
        biometricPromptTask?.cancel()
        biometricPromptTask = nil
        showBiometricAlert = false
    }
    
    private func restartHeroPulse() {
        heroPulse = false
        DispatchQueue.main.async {
            heroPulse = true
        }
    }
    
    private func advanceToCompletionStep() {
        navigationDirection = .forward
        withAnimation(AppAnimation.standard) {
            viewModel.currentStep = 5
        }
    }
    
    // MARK: - Navigation Buttons
    private var navigationButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.currentStep == 1 && !canProceed {
                Text(L10n("onboarding.step1_helper"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColorTheme.textSecondary)
            }
            
            HStack(spacing: 12) {
                if viewModel.currentStep > 1 {
                    Button {
                        let sourceStep = viewModel.currentStep
                        navigationDirection = .backward
                        withAnimation(AppAnimation.standard) {
                            viewModel.goToPreviousStep()
                        }
                        OnboardingLogging.trace("back_tapped step=\(sourceStep)")
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
                        .frame(minHeight: 40)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.15))
                        )
                    }
                }
                
                Button {
                    let sourceStep = viewModel.currentStep
                    navigationDirection = .forward
                    withAnimation(AppAnimation.standard) {
                        viewModel.goToNextStep()
                    }
                    OnboardingLogging.trace("next_tapped step=\(sourceStep)")
                    impactFeedback(style: .medium)
                } label: {
                    HStack(spacing: 8) {
                        Text(L10n("onboarding.next"))
                            .font(.system(size: 17, weight: .semibold))
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(AppColorTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 40)
                    .padding(.vertical, 10)
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
    }
    
    private var canProceed: Bool {
        switch viewModel.currentStep {
        case 1: return viewModel.canProceedToStep2
        case 2: return true
        case 3: return true // Notifications can always proceed
        case 4: return true
        case 5: return true
        default: return false
        }
    }
    
    private var goalPersonalizationText: String {
        switch viewModel.selectedGoal {
        case .saveMore:
            return L10n("onboarding.goal_microcopy_save_more")
        case .payDebt:
            return L10n("onboarding.goal_microcopy_pay_debts")
        case .controlSpending:
            return L10n("onboarding.goal_microcopy_control_spending")
        }
    }
    
    private func localizedGoalLabel(_ goal: FinancialGoal) -> String {
        switch goal {
        case .saveMore: return L10n("onboarding.goal_label_save_more")
        case .payDebt: return L10n("onboarding.goal_label_pay_debts")
        case .controlSpending: return L10n("onboarding.goal_label_control_spending")
        }
    }
    
    private var reminderSummaryText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        
        var times: [String] = []
        if viewModel.morningNotificationEnabled {
            times.append(formatter.string(from: viewModel.defaultMorningReminderTime))
        }
        if viewModel.eveningNotificationEnabled {
            times.append(formatter.string(from: viewModel.defaultEveningReminderTime))
        }
        if viewModel.customNotificationEnabled {
            times.append(formatter.string(from: viewModel.customNotificationTime))
        }
        
        guard !times.isEmpty else {
            return L10n("onboarding.reminders_summary_none")
        }
        
        return String(
            format: L10n("onboarding.reminders_summary_format"),
            times.count,
            times.joined(separator: ", ")
        )
    }
    
    private func impactFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    private func notificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Modern Income Entry View
struct ModernIncomeEntryView: View {
    @Binding var income: IncomeEntry
    let currency: String
    let canRemove: Bool
    let onRemove: () -> Void
    @State private var isAmountFocused: Bool = false
    @State private var amountDisplay: String = ""
    
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
                
                // Amount Field with custom numeric keyboard (period decimal)
                AmountInputWithCustomKeyboard(
                    amountDisplay: $amountDisplay,
                    placeholder: "0",
                    focusTrigger: 0,
                    onFormatChange: { stripped in
                        income.amount = CurrencyFormatter.sanitizeAmountInput(stripped)
                    },
                    onFocusChange: { focused in
                        isAmountFocused = focused
                    }
                )
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
        .onAppear {
            amountDisplay = CurrencyFormatter.formatAmountForDisplay(income.amount)
        }
        .onChange(of: income.amount) { _, newValue in
            let formatted = CurrencyFormatter.formatAmountForDisplay(newValue)
            if amountDisplay != formatted {
                amountDisplay = formatted
            }
        }
    }
}

// MARK: - Goal Selection Button
struct GoalSelectionButton: View {
    let goal: FinancialGoal
    let title: String
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
                Text(title)
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
            .frame(minHeight: 52)
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

// MARK: - Micro Interaction Button Style
struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

enum OnboardingLogging {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Friscora"
    private static let logger = Logger(subsystem: subsystem, category: "Onboarding")
    
    static func trace(_ message: @autoclosure () -> String) {
        let text = message()
        logger.info("\(text, privacy: .public)")
        #if DEBUG
        print("[Onboarding] \(text)")
        #endif
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

