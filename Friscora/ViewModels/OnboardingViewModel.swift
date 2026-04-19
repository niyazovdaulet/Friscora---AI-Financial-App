//
//  OnboardingViewModel.swift
//  Friscora
//
//  ViewModel for onboarding flow
//

import Foundation
import Combine

struct IncomeEntry: Identifiable {
    let id: UUID = UUID()
    var amount: String = ""
    var date: Date = Date()
}

class OnboardingViewModel: ObservableObject {
    enum OnboardingStep: Int, CaseIterable {
        case valueSetup = 1
        case goal = 2
        case notifications = 3
        case security = 4
        case completion = 5
    }
    
    @Published var incomes: [IncomeEntry] = [IncomeEntry()]
    @Published var selectedGoal: FinancialGoal = .saveMore
    @Published var currentStep: Int = 1
    @Published var selectedCurrency: String = "PLN"
    
    // Step 3: Notifications & Authentication
    @Published var morningNotificationEnabled: Bool = true
    @Published var eveningNotificationEnabled: Bool = true
    @Published var customNotificationEnabled: Bool = false
    @Published var customNotificationTime: Date = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    @Published var passcode: String = ""
    @Published var confirmPasscode: String = ""
    @Published var passcodeStep: Int = 1 // 1 = enter, 2 = confirm
    @Published var biometricEnabled: Bool = false
    
    var defaultMorningReminderTime: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    var defaultEveningReminderTime: Date {
        Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    }
    
    private let userProfileService = UserProfileService.shared
    private let incomeService = IncomeService.shared
    private let authService = AuthenticationService.shared
    private let notificationService = NotificationService.shared
    
    // All major currencies
    let currencies = [
        "USD", "EUR", "GBP", "JPY", "CNY", "AUD", "CAD", "CHF", "HKD", "NZD",
        "SEK", "KRW", "SGD", "NOK", "MXN", "INR", "RUB", "BYN", "ZAR", "TRY", "BRL",
        "TWD", "DKK", "PLN", "THB", "IDR", "HUF", "CZK", "ILS", "CLP", "PHP",
        "AED", "COP", "SAR", "MYR", "RON", "BGN", "PKR", "NGN", "EGP", "VND",
        "BDT", "ARS", "UAH", "IQD", "MAD", "KZT", "QAR", "OMR", "KWD", "BHD"
    ]
    
    var canProceedToStep2: Bool {
        !incomes.isEmpty && incomes.allSatisfy { !$0.amount.isEmpty && (CurrencyFormatter.parsedAmount(from: $0.amount) ?? 0) > 0 }
    }
    
    var canProceedToStep3: Bool {
        true
    }
    
    var canComplete: Bool {
        // Can complete if:
        // 1. Passcode is not set (user skipped)
        // 2. Passcode is set and confirmed (both steps done and match)
        if passcode.isEmpty {
            return true // User skipped authentication
        }
        if passcodeStep == 1 {
            return false // Need to confirm passcode
        }
        if passcodeStep == 2 {
            if passcode.count == 4 && confirmPasscode.count == 4 {
                return passcode == confirmPasscode
            }
            return false // Still entering passcode
        }
        return true
    }
    
    var currentOnboardingStep: OnboardingStep {
        OnboardingStep(rawValue: currentStep) ?? .valueSetup
    }
    
    func goToNextStep() {
        currentStep = min(currentStep + 1, OnboardingStep.completion.rawValue)
    }
    
    func goToPreviousStep() {
        currentStep = max(currentStep - 1, OnboardingStep.valueSetup.rawValue)
    }
    
    func addIncome() {
        incomes.append(IncomeEntry())
    }
    
    func removeIncome(at index: Int) {
        guard incomes.count > 1 else { return }
        incomes.remove(at: index)
    }
    
    func completeOnboarding() {
        // Save incomes
        for incomeEntry in incomes {
            if let amount = CurrencyFormatter.parsedAmount(from: incomeEntry.amount), amount > 0 {
                let income = Income(amount: amount, date: incomeEntry.date, currency: selectedCurrency)
                incomeService.addIncome(income)
            }
        }
        
        // Save notification schedule
        let notificationSchedule = NotificationSchedule(
            morningEnabled: morningNotificationEnabled,
            morningTime: defaultMorningReminderTime,
            eveningEnabled: eveningNotificationEnabled,
            eveningTime: defaultEveningReminderTime,
            customEnabled: customNotificationEnabled,
            customTime: customNotificationEnabled ? customNotificationTime : nil
        )
        notificationService.saveSchedule(notificationSchedule)
        
        // Save authentication if passcode was set
        var isAuthEnabled = false
        if passcode.count == 4 && confirmPasscode.count == 4 && passcode == confirmPasscode {
            if authService.savePasscode(passcode) {
                isAuthEnabled = true
                authService.setBiometricEnabled(biometricEnabled)
            }
        }
        
        // Save profile
        var profile = UserProfile(
            primaryGoal: selectedGoal,
            hasCompletedOnboarding: true,
            currency: selectedCurrency,
            isAuthenticationEnabled: isAuthEnabled,
            notificationSchedule: notificationSchedule
        )
        userProfileService.saveProfile(profile)
    }
    
    func skipAuthentication() {
        passcode = ""
        confirmPasscode = ""
        passcodeStep = 1
    }
}

