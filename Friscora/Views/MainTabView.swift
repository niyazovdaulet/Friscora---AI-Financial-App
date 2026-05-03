//
//  MainTabView.swift
//  Friscora
//
//  Main tab navigation for the app
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var userProfileService = UserProfileService.shared
    @StateObject private var authService = AuthenticationService.shared
    @State private var showingOnboarding = false
    @State private var selectedTab = 0
    /// Hides the floating tab bar while Add-tab amount field shows its UIKit `inputView` keyboard (otherwise it paints above the keys).
    @State private var suppressFloatingTabBarForAmountKeyboard = false
    @EnvironmentObject private var shareCoordinator: ScheduleShareCoordinator

    /// Lets scroll content extend under the floating tab bar so blur materials have something to sample.
    // FI-UI-REFINE: Match shorter `CustomTabBar` so scroll content isn’t left with excess empty margin above the bar.
    private let tabContentBottomInset: CGFloat = 50
    private let floatingTabBarHorizontalInset: CGFloat = 16
    private let floatingTabBarBottomInset: CGFloat = 10

    var body: some View {
        ZStack {
            AppColorTheme.background
                .ignoresSafeArea()

            ZStack(alignment: .bottom) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(
                        .bottom,
                        (selectedTab == 2 && suppressFloatingTabBarForAmountKeyboard)
                            ? 12
                            : tabContentBottomInset
                    )

                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, floatingTabBarHorizontalInset)
                    .padding(.bottom, floatingTabBarBottomInset)
                    .opacity(suppressFloatingTabBarForAmountKeyboard ? 0 : 1)
                    .allowsHitTesting(!suppressFloatingTabBarForAmountKeyboard)
                    .animation(.easeInOut(duration: 0.22), value: suppressFloatingTabBarForAmountKeyboard)
            }
        }
        .animation(AppAnimation.tabSwitch, value: selectedTab)
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingContainerView()
        }
        .onAppear {
            checkOnboardingStatus()
        }
        .onChange(of: userProfileService.profile.hasCompletedOnboarding) { _, hasCompleted in
            if !hasCompleted {
                withAnimation(AppAnimation.sheetPresent) {
                    showingOnboarding = true
                }
            } else {
                shareCoordinator.flushDeferredInviteIfReady()
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            HapticHelper.selection()
            if newTab != 2 {
                suppressFloatingTabBarForAmountKeyboard = false
            }
        }
        .onChange(of: shareCoordinator.shouldOpenScheduleTab) { _, shouldOpen in
            guard shouldOpen else { return }
            ScheduleShareLogging.trace("MainTabView: switching to Schedule tab (deep link / invite)")
            withAnimation(AppAnimation.tabBarSpring) {
                selectedTab = 3
            }
            shareCoordinator.consumeOpenScheduleFlag()
        }
        .onChange(of: authService.isAuthenticated) { _, _ in
            shareCoordinator.flushDeferredInviteIfReady()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            DashboardView(selectedTab: $selectedTab)
                .opacity(selectedTab == 0 ? 1 : 0)
                .allowsHitTesting(selectedTab == 0)

            AnalyticsView(selectedTab: $selectedTab)
                .opacity(selectedTab == 1 ? 1 : 0)
                .allowsHitTesting(selectedTab == 1)

            AddExpenseView(
                selectedTab: $selectedTab,
                suppressFloatingTabBar: $suppressFloatingTabBarForAmountKeyboard
            )
                .opacity(selectedTab == 2 ? 1 : 0)
                .allowsHitTesting(selectedTab == 2)

            ScheduleView()
                .opacity(selectedTab == 3 ? 1 : 0)
                .allowsHitTesting(selectedTab == 3)

            ProfileView()
                .opacity(selectedTab == 4 ? 1 : 0)
                .allowsHitTesting(selectedTab == 4)
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
