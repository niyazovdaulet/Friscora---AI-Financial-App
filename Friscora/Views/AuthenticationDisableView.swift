//
//  AuthenticationDisableView.swift
//  Friscora
//
//  View for disabling authentication from Profile
//

import SwiftUI
import LocalAuthentication

struct AuthenticationDisableView: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    @State private var passcode: String = ""
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.15, green: 0.2, blue: 0.25)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("Disable Authentication")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Enter your passcode to disable authentication")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    if authService.isBiometricEnabled && authService.isBiometricAvailable {
                        Button {
                            authenticateWithBiometric()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: authService.biometricType == .faceID ? "faceid" : "touchid")
                                    .font(.system(size: 24))
                                Text("Use \(authService.biometricType == .faceID ? "Face ID" : "Touch ID")")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.2))
                            )
                        }
                        
                        Text("or")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    PasscodeEntryView(
                        passcode: $passcode,
                        title: "",
                        subtitle: showError ? "Incorrect passcode" : nil
                    ) {
                        verifyAndDisable()
                    }
                }
                .padding(40)
            }
            .navigationTitle("Disable Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func authenticateWithBiometric() {
        authService.authenticateWithBiometric { success, _ in
            if success {
                disableAuthentication()
            }
        }
    }
    
    private func verifyAndDisable() {
        if authService.verifyPasscode(passcode) {
            disableAuthentication()
        } else {
            showError = true
            passcode = ""
        }
    }
    
    private func disableAuthentication() {
        authService.deletePasscode()
        authService.setBiometricEnabled(false)
        var profile = userProfileService.profile
        profile.isAuthenticationEnabled = false
        userProfileService.saveProfile(profile)
        isPresented = false
    }
}

