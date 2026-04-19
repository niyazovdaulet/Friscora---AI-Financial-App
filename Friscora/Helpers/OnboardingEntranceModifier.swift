//
//  OnboardingEntranceModifier.swift
//  Friscora
//
//  Reusable staggered entrance animation for onboarding elements.
//

import SwiftUI

struct OnboardingEntranceModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1.0 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func onboardingEntrance(delay: Double) -> some View {
        modifier(OnboardingEntranceModifier(delay: delay))
    }
}
