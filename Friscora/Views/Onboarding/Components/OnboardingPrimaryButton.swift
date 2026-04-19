//
//  OnboardingPrimaryButton.swift
//  Friscora
//
//  Shared primary button and press behavior for onboarding.
//

import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let systemImage: String?
    let isEnabled: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            guard isEnabled else { return }
            HapticManager.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(OnboardingTheme.bodyFont(size: 17, weight: .semibold))
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(OnboardingTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isEnabled ? OnboardingTheme.tealAccent : OnboardingTheme.surfaceElevated)
            )
            .opacity(isEnabled ? 1.0 : 0.55)
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview("Dark") {
    ZStack {
        OnboardingTheme.background.ignoresSafeArea()
        VStack(spacing: 12) {
            OnboardingPrimaryButton(title: "Next", systemImage: "chevron.right") {}
            OnboardingPrimaryButton(title: "Disabled", isEnabled: false) {}
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    ZStack {
        OnboardingTheme.background.ignoresSafeArea()
        OnboardingPrimaryButton(title: "Next", systemImage: "chevron.right") {}
            .padding()
    }
    .preferredColorScheme(.light)
}
