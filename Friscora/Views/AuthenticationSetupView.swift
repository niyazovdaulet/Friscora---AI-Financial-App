//
//  AuthenticationSetupView.swift
//  Friscora
//
//  View for setting up authentication from Profile
//

import SwiftUI
import LocalAuthentication

struct AuthenticationSetupView: View {
    @Binding var isPresented: Bool
    @StateObject private var authService = AuthenticationService.shared
    @StateObject private var userProfileService = UserProfileService.shared
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var passcodeStep: Int = 1
    @State private var biometricEnabled: Bool = false
    @State private var showBiometricAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.15, green: 0.2, blue: 0.25)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    if passcodeStep == 1 {
                        VStack(spacing: 24) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Create Passcode")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enter a 4-digit passcode to secure your data")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            PasscodeEntryView(
                                passcode: $passcode,
                                title: "",
                                subtitle: nil
                            ) {
                                if passcode.count == 4 {
                                    withAnimation(AppAnimation.standard) {
                                        passcodeStep = 2
                                        confirmPasscode = ""
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("Confirm Passcode")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Re-enter your passcode")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            
                            PasscodeEntryView(
                                passcode: $confirmPasscode,
                                title: "",
                                subtitle: nil
                            ) {
                                if confirmPasscode.count == 4 {
                                    if passcode == confirmPasscode {
                                        savePasscode()
                                    } else {
                                        // Passcodes don't match
                                        confirmPasscode = ""
                                        passcode = ""
                                        passcodeStep = 1
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(40)
            }
            .navigationTitle("Setup Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Enable \(authService.biometricType == .faceID ? "Face ID" : "Touch ID")?", isPresented: $showBiometricAlert) {
                Button("Enable") {
                    biometricEnabled = true
                    completeSetup()
                }
                Button("Not Now", role: .cancel) {
                    biometricEnabled = false
                    completeSetup()
                }
            } message: {
                Text("You can use \(authService.biometricType == .faceID ? "Face ID" : "Touch ID") to quickly unlock Friscora")
            }
        }
    }
    
    private func savePasscode() {
        if authService.savePasscode(passcode) {
            if authService.isBiometricAvailable {
                showBiometricAlert = true
            } else {
                completeSetup()
            }
        }
    }
    
    private func completeSetup() {
        authService.setBiometricEnabled(biometricEnabled)
        var profile = userProfileService.profile
        profile.isAuthenticationEnabled = true
        userProfileService.saveProfile(profile)
        isPresented = false
    }
}

