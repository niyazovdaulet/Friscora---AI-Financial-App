//
//  OnboardingContainerView.swift
//  Friscora
//
//  Root onboarding container with page navigation.
//

import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            OnboardingTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if coordinator.currentStep != .welcome {
                    OnboardingProgressHeader()
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }

                Group {
                    switch coordinator.currentStep {
                    case .welcome:
                        OnboardingWelcomeView()
                    case .income:
                        OnboardingIncomeView()
                    case .goal:
                        OnboardingGoalView()
                    case .notifications:
                        OnboardingNotificationsView()
                    case .security:
                        OnboardingSecurityView()
                    case .completion:
                        OnboardingCompletionView()
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: coordinator.currentStep)
                .id(coordinator.currentStep)
            }
        }
        .environmentObject(coordinator)
        .onChange(of: coordinator.didCompleteOnboarding) { _, didComplete in
            guard didComplete else { return }
            dismiss()
        }
    }
}

#Preview("Dark") {
    OnboardingContainerView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    OnboardingContainerView()
        .preferredColorScheme(.light)
}
