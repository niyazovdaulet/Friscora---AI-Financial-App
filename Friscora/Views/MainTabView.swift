//
//  MainTabView.swift
//  Friscora
//
//  Main tab navigation for the app
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var userProfileService = UserProfileService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingOnboarding = false
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppColorTheme.tabBarBackground)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColorTheme.tabActive)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColorTheme.tabActive)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColorTheme.tabInactive)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColorTheme.tabInactive)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            AppColorTheme.background
                .ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                DashboardView(selectedTab: $selectedTab)
                    .tabItem {
                        Label(L10n("tab.dashboard"), systemImage: "house.fill")
                    }
                    .tag(0)
                
                AnalyticsView(selectedTab: $selectedTab)
                    .tabItem {
                        Label(L10n("tab.analytics"), systemImage: "chart.pie.fill")
                    }
                    .tag(1)
                
                AddExpenseView(selectedTab: $selectedTab)
                    .tabItem {
                        Label(L10n("tab.add"), systemImage: "plus.circle.fill")
                    }
                    .tag(2)
                
                ScheduleView()
                    .tabItem {
                        Label(L10n("tab.schedule"), systemImage: "calendar.badge.clock")
                    }
                    .tag(3)
                
                ProfileView()
                    .tabItem {
                        Label(L10n("tab.settings"), systemImage: "gearshape.fill")
                    }
                    .tag(4)
            }
            .tint(AppColorTheme.tabActive)
        }
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .onAppear {
            checkOnboardingStatus()
        }
        .onChange(of: userProfileService.profile.hasCompletedOnboarding) { hasCompleted in
            if !hasCompleted {
                withAnimation(AppAnimation.sheetPresent) {
                    showingOnboarding = true
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                authService.clearAuthentication()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            HapticHelper.selection()
        }
    }
    
    private func checkOnboardingStatus() {
        if !userProfileService.hasCompletedOnboarding {
            withAnimation(AppAnimation.sheetPresent) {
                showingOnboarding = true
            }
        }
    }
}
