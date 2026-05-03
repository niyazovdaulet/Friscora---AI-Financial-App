//
//  OnboardingCoordinator.swift
//  Friscora
//
//  Central state coordinator for onboarding navigation and data.
//

import Combine
import Foundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case income
    case goal
    case notifications
    case security
    case completion

    var progressIndex: Int {
        switch self {
        case .welcome:
            return 0
        case .income:
            return 1
        case .goal:
            return 2
        case .notifications:
            return 3
        case .security:
            return 4
        case .completion:
            return 4
        }
    }

    static var progressStepCount: Int { 4 }
}

enum OnboardingGoal: String, CaseIterable, Codable, Hashable {
    case saveMore
    case payOffDebts
    case controlSpending
    case emergencyFund
    case planForGoal

    var titleKey: String {
        switch self {
        case .saveMore: return "onboarding.goal.save_more.title"
        case .payOffDebts: return "onboarding.goal.pay_off_debts.title"
        case .controlSpending: return "onboarding.goal.control_spending.title"
        case .emergencyFund: return "onboarding.goal.emergency_fund.title"
        case .planForGoal: return "onboarding.goal.plan_for_goal.title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .saveMore: return "onboarding.goal.save_more.subtitle"
        case .payOffDebts: return "onboarding.goal.pay_off_debts.subtitle"
        case .controlSpending: return "onboarding.goal.control_spending.subtitle"
        case .emergencyFund: return "onboarding.goal.emergency_fund.subtitle"
        case .planForGoal: return "onboarding.goal.plan_for_goal.subtitle"
        }
    }

    var sfSymbol: String {
        switch self {
        case .saveMore: return "dollarsign.circle"
        case .payOffDebts: return "creditcard"
        case .controlSpending: return "chart.bar"
        case .emergencyFund: return "shield"
        case .planForGoal: return "target"
        }
    }

    var mappedPrimaryGoal: FinancialGoal {
        switch self {
        case .saveMore, .emergencyFund, .planForGoal:
            return .saveMore
        case .payOffDebts:
            return .payDebt
        case .controlSpending:
            return .controlSpending
        }
    }
}

struct OnboardingIncomeEntry: Identifiable, Equatable {
    let id: UUID
    var amount: String

    init(id: UUID = UUID(), amount: String = "") {
        self.id = id
        self.amount = amount
    }
}

final class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome

    @Published var incomes: [OnboardingIncomeEntry] = [OnboardingIncomeEntry()]
    @Published var selectedCurrency: String
    @Published var selectedGoals: [OnboardingGoal] = []

    @Published var notificationsEnabled: Bool = true
    @Published var selectedReminderTime: Date

    @Published var securityMode: OnboardingSecurityMode = .off
    @Published var passcode: String = ""

    /// After passcode is set on a device with biometrics: user must tap Enable (Face ID / Touch ID) or Skip before continuing.
    @Published var pendingBiometricEnrollmentChoice: Bool = false
    /// Persisted with the passcode when onboarding completes (only if the user successfully completes the biometric prompt).
    @Published var enableBiometricUnlockOnComplete: Bool = false
    @Published var securityUIPhase: OnboardingSecurityUIPhase = .choice

    @Published var didCompleteOnboarding: Bool = false

    let currencies = [
        "USD", "EUR", "GBP", "PLN", "KZT", "RUB", "AED", "CHF", "JPY", "CNY",
        "AUD", "CAD", "HKD", "NZD", "SEK", "KRW", "SGD", "NOK", "MXN", "INR",
        "BYN", "ZAR", "TRY", "BRL", "TWD", "DKK", "THB", "IDR", "HUF", "CZK",
        "ILS", "CLP", "PHP", "COP", "SAR", "MYR", "RON", "BGN", "PKR", "NGN",
        "EGP", "VND", "BDT", "ARS", "UAH", "IQD", "MAD", "QAR", "OMR", "KWD", "BHD"
    ]

    private let userProfileService: UserProfileService
    private let incomeService: IncomeService
    private let authService: AuthenticationService
    private let notificationService: NotificationService

    init(
        userProfileService: UserProfileService = .shared,
        incomeService: IncomeService = .shared,
        authService: AuthenticationService = .shared,
        notificationService: NotificationService = .shared
    ) {
        self.userProfileService = userProfileService
        self.incomeService = incomeService
        self.authService = authService
        self.notificationService = notificationService
        self.selectedCurrency = Locale.current.currency?.identifier ?? "USD"
        self.selectedReminderTime = Calendar.current.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    var canAdvance: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .income:
            return true
        case .goal:
            return !selectedGoals.isEmpty
        case .notifications:
            return true
        case .security:
            if securityMode == .off {
                return true
            }
            guard securityMode == .passcode, passcode.count == 4 else { return false }
            return !pendingBiometricEnrollmentChoice
        case .completion:
            return true
        }
    }

    var primaryGoal: OnboardingGoal? {
        selectedGoals.first
    }

    func advance() {
        guard canAdvance else { return }
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func goBack() {
        guard let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    func skip() {
        switch currentStep {
        case .income, .goal, .notifications:
            advance()
        case .security:
            // Abandon passcode setup and continue without app lock.
            if securityUIPhase == .choice || securityUIPhase == .passcodeEntry {
                resetSecuritySelection()
            }
            guard securityUIPhase != .biometricOffer else { return }
            advance()
        default:
            break
        }
    }

    func completeOnboarding() {
        persistIncome()
        persistNotifications()
        persistSecurity()
        persistProfile()
        didCompleteOnboarding = true
    }

    func addIncomeSource() {
        incomes.append(OnboardingIncomeEntry())
    }

    func removeIncomeSource(id: UUID) {
        guard incomes.count > 1 else { return }
        incomes.removeAll { $0.id == id }
    }

    func toggleGoal(_ goal: OnboardingGoal) {
        if let index = selectedGoals.firstIndex(of: goal) {
            selectedGoals.remove(at: index)
        } else {
            selectedGoals.append(goal)
        }
    }

    func resetSecuritySelection() {
        securityMode = .off
        passcode = ""
        pendingBiometricEnrollmentChoice = false
        enableBiometricUnlockOnComplete = false
        securityUIPhase = .choice
    }

    func beginPasscodeSetup() {
        securityMode = .passcode
        passcode = ""
        pendingBiometricEnrollmentChoice = false
        enableBiometricUnlockOnComplete = false
        securityUIPhase = .passcodeEntry
    }

    func markPasscodeConfirmedForBiometricOfferIfNeeded(authService: AuthenticationService = .shared) {
        if authService.isBiometricAvailable {
            pendingBiometricEnrollmentChoice = true
            securityUIPhase = .biometricOffer
        } else {
            pendingBiometricEnrollmentChoice = false
            securityUIPhase = .finished
        }
    }

    func skipBiometricEnrollment() {
        pendingBiometricEnrollmentChoice = false
        enableBiometricUnlockOnComplete = false
        securityUIPhase = .finished
    }

    func completeBiometricEnrollmentSuccess() {
        pendingBiometricEnrollmentChoice = false
        enableBiometricUnlockOnComplete = true
        securityUIPhase = .finished
    }

    private func persistIncome() {
        for entry in incomes {
            guard let amount = CurrencyFormatter.parsedAmount(from: entry.amount), amount > 0 else { continue }
            incomeService.addIncome(Income(amount: amount, date: Date(), currency: selectedCurrency))
        }
    }

    private func persistNotifications() {
        let schedule = NotificationSchedule(
            morningEnabled: notificationsEnabled,
            morningTime: selectedReminderTime,
            eveningEnabled: false,
            eveningTime: selectedReminderTime,
            customEnabled: false,
            customTime: nil
        )
        notificationService.saveSchedule(schedule)
    }

    private func persistSecurity() {
        switch securityMode {
        case .off:
            authService.setBiometricEnabled(false)
            authService.clearAuthentication()
        case .passcode:
            guard passcode.count == 4 else { return }
            let enableBio = enableBiometricUnlockOnComplete && authService.isBiometricAvailable
            if authService.savePasscode(passcode) {
                authService.setBiometricEnabled(enableBio)
            }
        }
    }

    private func persistProfile() {
        let goal = primaryGoal?.mappedPrimaryGoal ?? .saveMore
        var profile = UserProfile(
            primaryGoal: goal,
            hasCompletedOnboarding: true,
            currency: selectedCurrency,
            isAuthenticationEnabled: securityMode != .off,
            notificationSchedule: NotificationSchedule(
                morningEnabled: notificationsEnabled,
                morningTime: selectedReminderTime,
                eveningEnabled: false,
                eveningTime: selectedReminderTime,
                customEnabled: false,
                customTime: nil
            )
        )
        userProfileService.saveProfile(profile)
    }
}

enum OnboardingSecurityMode: String, Codable {
    case off
    case passcode
}

enum OnboardingSecurityUIPhase: Equatable {
    case choice
    case passcodeEntry
    case biometricOffer
    case finished
}
