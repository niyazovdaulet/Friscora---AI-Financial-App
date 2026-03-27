//
//  FriscoraApp.swift
//  Friscora
//
//  Created by Daulet on 28/12/2025.
//

import SwiftUI
import UIKit
import FirebaseCore

@main
struct FriscoraApp: App {
    init() {
        FirebaseApp.configure()
    }

    @StateObject private var appState = AppState()
    @ObservedObject private var authService = AuthenticationService.shared
    @State private var showAuthentication = false
    @State private var hasCheckedAuth = false
    
    var body: some Scene {
        WindowGroup {
            AppContentView(
                appState: appState,
                showAuthentication: $showAuthentication,
                hasCheckedAuth: $hasCheckedAuth,
                authService: authService
            )
            .environmentObject(appState)
        }
    }
}

struct AppContentView: View {
    @ObservedObject var appState: AppState
    @Binding var showAuthentication: Bool
    @Binding var hasCheckedAuth: Bool
    @ObservedObject var authService: AuthenticationService
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Root content: ID forces full re-initialization on language change
            MainTabView()
                .id(appState.rootViewId)
                .preferredColorScheme(.dark)
            
            // Full-screen loading during app reload (e.g. language change)
            if appState.isReloading {
                LoadingScreenView()
                    .zIndex(2)
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showAuthentication) {
            // Auth as fullScreenCover so it always appears on top of ChatView, GoalsView, sheets, etc.
            AuthenticationLockView(isPresented: $showAuthentication)
        }
        .task {
            // Delay authentication check slightly to ensure view is ready
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
            await MainActor.run {
                checkAuthentication()
                hasCheckedAuth = true
            }
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if hasCheckedAuth {
                if isAuthenticated {
                    // User authenticated successfully
                    withAnimation(AppAnimation.sheetPresent) {
                        showAuthentication = false
                    }
                } else if shouldShowAuth() {
                    // Need to show authentication
                    dismissKeyboard()
                    withAnimation(AppAnimation.sheetPresent) {
                        showAuthentication = true
                    }
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if hasCheckedAuth {
                    checkAuthentication()
                }
                // Pull from iCloud when app becomes active (e.g. returning from another device)
                DispatchQueue.global(qos: .utility).async {
                    ICloudSyncService.shared.syncFromCloud()
                }
                // Sync Work salary to Dashboard income (today or past only)
                DispatchQueue.main.async {
                    SalarySyncService.shared.syncSalaryToIncome()
                }
            }
        }
    }
    
    private func checkAuthentication() {
        let profile = UserProfileService.shared.profile
        guard profile.isAuthenticationEnabled else {
            showAuthentication = false
            return
        }
        
        // Only show authentication if not already authenticated
        if !authService.isAuthenticated {
            // Dismiss any keyboard from underlying views (e.g. ChatView, GoalsView) so the lock screen
            // is clearly visible and the PIN field can receive focus.
            dismissKeyboard()
            showAuthentication = true
        } else {
            showAuthentication = false
        }
    }
    
    /// Dismisses the keyboard so auth lock is not obscured and PIN field can show its own keyboard.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func shouldShowAuth() -> Bool {
        let profile = UserProfileService.shared.profile
        return profile.isAuthenticationEnabled && !authService.isAuthenticated
    }
}
