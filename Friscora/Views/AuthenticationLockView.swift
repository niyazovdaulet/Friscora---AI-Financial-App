//
//  AuthenticationLockView.swift
//  Friscora
//
//  Lock screen view for authentication
//

import SwiftUI
import LocalAuthentication
import UIKit

struct AuthenticationLockView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var authService = AuthenticationService.shared
    @State private var passcode: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var attempts = 0
    
    var body: some View {
        ZStack {
            // Background
            AppColorTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // App Logo
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(AppColorTheme.textSecondary)
                
                VStack(spacing: 16) {
                    Text(L10n("auth.friscora"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(AppColorTheme.textPrimary)
                    
                    if authService.isBiometricEnabled && authService.isBiometricAvailable {
                        Button {
                            authenticateWithBiometric()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: authService.biometricType == .faceID ? "faceid" : "touchid")
                                    .font(.system(size: 24))
                                Text(String(format: L10n("auth.unlock_with_biometric"), authService.biometricType == .faceID ? L10n("auth.face_id") : L10n("auth.touch_id")))
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(AppColorTheme.textPrimary)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColorTheme.cardBackground)
                            )
                        }
                        .padding(.top, 20)
                    }
                    
                    Text(L10n("auth.or"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColorTheme.textSecondary)
                        .padding(.top, 8)
                    
                    PasscodeEntryView(
                        passcode: $passcode,
                        title: L10n("auth.enter_passcode"),
                        subtitle: showError ? errorMessage : nil
                    ) {
                        verifyPasscode()
                    }
                }
            }
            .padding(40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .onAppear {
            // Dismiss any keyboard from the previous screen (e.g. ChatView) so our PIN field can show its keyboard.
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            
            // Ensure passcode exists before trying biometric
            guard authService.hasPasscode else {
                return
            }
            
            // Try biometric first if available, with a small delay to ensure view is ready
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    if authService.isBiometricEnabled && authService.isBiometricAvailable {
                        authenticateWithBiometric()
                    }
                }
            }
        }
    }
    
    private func authenticateWithBiometric() {
        guard authService.isBiometricEnabled && authService.isBiometricAvailable else {
            return
        }
        
        authService.authenticateWithBiometric { success, error in
            DispatchQueue.main.async {
                if success {
                    self.authService.isAuthenticated = true
                    self.isPresented = false
                } else if let error = error {
                    // Only show error if it's not a user cancellation
                    let nsError = error as NSError
                    if nsError.domain == "com.apple.LocalAuthentication" && nsError.code == LAError.userCancel.rawValue {
                        // User cancelled - don't show error
                        return
                    }
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    private func verifyPasscode() {
        // Ensure passcode is not empty
        guard !passcode.isEmpty, passcode.count == 4 else {
            return
        }
        
        // Verify passcode
        if authService.verifyPasscode(passcode) {
            // Success - authenticate and dismiss
            DispatchQueue.main.async {
                self.authService.isAuthenticated = true
                self.isPresented = false
                self.passcode = ""
                self.attempts = 0
                self.showError = false
            }
        } else {
            // Failed - show error
            attempts += 1
            errorMessage = L10n("auth.incorrect_passcode")
            showError = true
            passcode = ""
            
            if attempts >= 5 {
                errorMessage = L10n("auth.too_many_attempts")
            }
        }
    }
}

