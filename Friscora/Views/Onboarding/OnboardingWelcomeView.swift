//
//  OnboardingWelcomeView.swift
//  Friscora
//
//  Welcome splash screen for onboarding.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    @State private var logoScale: CGFloat = 0.6
    @State private var glowRadius: CGFloat = 30
    @State private var titleVisible = false
    @State private var taglineVisible = false
    @State private var ctaVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 18) {
                logoMark
                    .scaleEffect(logoScale)

                Text(L10n("onboarding.welcome.title"))
                    .font(OnboardingTheme.displayFont(size: 36))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : 20)

                Text(L10n("onboarding.welcome.tagline"))
                    .font(OnboardingTheme.bodyFont(size: 17))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(taglineVisible ? 1 : 0)
            }

            Spacer()

            OnboardingPrimaryButton(
                title: L10n("onboarding.welcome.get_started"),
                systemImage: "chevron.right"
            ) {
                coordinator.advance()
            }
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 20)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(OnboardingTheme.background.ignoresSafeArea())
        .onAppear(perform: runEntranceAnimations)
    }

    private var logoMark: some View {
        Image("app-logo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 120, height: 120)
            .shadow(color: OnboardingTheme.tealAccent.opacity(0.55), radius: glowRadius * 0.6)
            .accessibilityLabel("Friscora")
    }

    private func runEntranceAnimations() {
        logoScale = 0.6
        glowRadius = 30
        titleVisible = false
        taglineVisible = false
        ctaVisible = false

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            logoScale = 1.0
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowRadius = 50
        }

        withAnimation(.easeInOut(duration: 0.45).delay(0.35)) {
            titleVisible = true
        }

        withAnimation(.easeInOut(duration: 0.45).delay(0.55)) {
            taglineVisible = true
        }

        withAnimation(.easeInOut(duration: 0.45).delay(0.75)) {
            ctaVisible = true
        }
    }
}

#Preview("Dark") {
    OnboardingWelcomeView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    OnboardingWelcomeView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.light)
}
