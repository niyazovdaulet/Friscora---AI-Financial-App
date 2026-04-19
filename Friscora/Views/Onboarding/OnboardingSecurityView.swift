//
//  OnboardingSecurityView.swift
//  Friscora
//

import LocalAuthentication
import SwiftUI
import UIKit

struct OnboardingSecurityView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    private let auth = AuthenticationService.shared

    @State private var showPasscodeFlow = false
    @State private var passcodeStep = 1
    @State private var firstPasscode = ""
    @State private var confirmPasscode = ""
    @State private var mismatch = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                secureDataHeader

                if !showPasscodeFlow {
                    VStack(spacing: 12) {
                        if auth.isBiometricAvailable {
                            securityChoiceButton(
                                title: String(format: L10n("onboarding.security.use_biometric"), biometricName)
                            ) {
                                coordinator.securityMode = .biometric
                                coordinator.passcode = ""
                                mismatch = false
                            }
                        }

                        securityChoiceButton(title: L10n("onboarding.security.passcode_option")) {
                            coordinator.securityMode = .passcode
                            coordinator.passcode = ""
                            showPasscodeFlow = true
                            passcodeStep = 1
                            firstPasscode = ""
                            confirmPasscode = ""
                            mismatch = false
                        }

                        securityChoiceButton(title: L10n("onboarding.security.not_now"), isSecondary: true) {
                            coordinator.securityMode = .off
                            coordinator.passcode = ""
                            mismatch = false
                        }
                    }
                } else {
                    passcodeSection
                }

                OnboardingPrimaryButton(
                    title: L10n("onboarding.next"),
                    systemImage: "chevron.right",
                    isEnabled: coordinator.canAdvance
                ) {
                    coordinator.advance()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollIndicators(.hidden)
        .background(OnboardingTheme.background.ignoresSafeArea())
    }

    /// Lock + title; while entering a passcode, tap here (outside the passcode card) to dismiss the keyboard.
    private var secureDataHeader: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.tealAccent.opacity(0.2))
                    .frame(width: 88, height: 88)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(OnboardingTheme.tealAccent)
            }
            .padding(.top, 8)

            Text(L10n("onboarding.secure_data_title"))
                .font(OnboardingTheme.displayFont(size: 26))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(L10n("onboarding.secure_data_subtitle"))
                .font(OnboardingTheme.bodyFont(size: 15, weight: .medium))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard showPasscodeFlow else { return }
            resignPasscodeKeyboard()
        }
    }

    private func resignPasscodeKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var biometricName: String {
        switch auth.biometricType {
        case .faceID:
            return L10n("auth.face_id")
        case .touchID:
            return L10n("auth.touch_id")
        default:
            return L10n("auth.touch_id")
        }
    }

    private func securityChoiceButton(title: String, isSecondary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            Text(title)
                .font(OnboardingTheme.bodyFont(size: 16, weight: .semibold))
                .foregroundStyle(isSecondary ? OnboardingTheme.textSecondary : OnboardingTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSecondary ? OnboardingTheme.textPrimary.opacity(0.08) : OnboardingTheme.tealAccent)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var passcodeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                resetPasscodeFlow()
            } label: {
                Text(L10n("common.cancel"))
                    .font(OnboardingTheme.bodyFont(size: 15, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.textSecondary)
            }
            .buttonStyle(.plain)

            if passcodeStep == 1 {
                PasscodeEntryView(
                    passcode: $firstPasscode,
                    title: L10n("onboarding.create_passcode"),
                    subtitle: L10n("onboarding.create_passcode_subtitle")
                ) {
                    guard firstPasscode.count == 4 else { return }
                    passcodeStep = 2
                    confirmPasscode = ""
                }
            } else {
                PasscodeEntryView(
                    passcode: $confirmPasscode,
                    title: L10n("onboarding.confirm_passcode"),
                    subtitle: L10n("onboarding.confirm_passcode_subtitle")
                ) {
                    guard confirmPasscode.count == 4 else { return }
                    if confirmPasscode == firstPasscode {
                        coordinator.passcode = firstPasscode
                        coordinator.securityMode = .passcode
                        mismatch = false
                    } else {
                        mismatch = true
                        confirmPasscode = ""
                    }
                }

                if mismatch {
                    Text(L10n("onboarding.passcode_mismatch_error"))
                        .font(OnboardingTheme.bodyFont(size: 14, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.9))
                }

                Button {
                    passcodeStep = 1
                    confirmPasscode = ""
                    coordinator.passcode = ""
                    mismatch = false
                } label: {
                    Text(L10n("onboarding.re_enter_passcode"))
                        .font(OnboardingTheme.bodyFont(size: 15, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(OnboardingTheme.surface)
        )
    }

    private func resetPasscodeFlow() {
        showPasscodeFlow = false
        passcodeStep = 1
        firstPasscode = ""
        confirmPasscode = ""
        coordinator.passcode = ""
        coordinator.securityMode = .off
        mismatch = false
    }
}

#Preview("Dark") {
    OnboardingSecurityView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}
