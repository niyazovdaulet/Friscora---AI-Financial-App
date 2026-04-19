//
//  OnboardingCompletionView.swift
//  Friscora
//

import SwiftUI

struct OnboardingCompletionView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(L10n("onboarding.completion_title"))
                .font(OnboardingTheme.displayFont(size: 30))
                .foregroundStyle(OnboardingTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n("onboarding.completion_subtitle"))
                .font(OnboardingTheme.bodyFont(size: 16, weight: .medium))
                .foregroundStyle(OnboardingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()

            OnboardingPrimaryButton(
                title: L10n("onboarding.get_started"),
                systemImage: "chevron.right",
                isEnabled: true
            ) {
                coordinator.completeOnboarding()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .background(OnboardingTheme.background.ignoresSafeArea())
    }
}

#Preview("Dark") {
    OnboardingCompletionView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}
