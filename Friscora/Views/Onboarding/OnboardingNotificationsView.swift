//
//  OnboardingNotificationsView.swift
//  Friscora
//

import SwiftUI

struct OnboardingNotificationsView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n("onboarding.notifications"))
                    .font(OnboardingTheme.displayFont(size: 28))
                    .foregroundStyle(OnboardingTheme.textPrimary)

                Text(L10n("onboarding.notifications_subtitle"))
                    .font(OnboardingTheme.bodyFont(size: 15, weight: .medium))
                    .foregroundStyle(OnboardingTheme.textSecondary)

                VStack(alignment: .leading, spacing: 16) {
                    Toggle(isOn: $coordinator.notificationsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n("onboarding.custom_reminder"))
                                .font(OnboardingTheme.bodyFont(size: 16, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.textPrimary)
                            Text(L10n("onboarding.custom_reminder_subtitle"))
                                .font(OnboardingTheme.bodyFont(size: 14, weight: .medium))
                                .foregroundStyle(OnboardingTheme.textSecondary)
                        }
                    }
                    .tint(OnboardingTheme.tealAccent)

                    if coordinator.notificationsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n("onboarding.notifications.reminder_time"))
                                .font(OnboardingTheme.bodyFont(size: 14, weight: .semibold))
                                .foregroundStyle(OnboardingTheme.textSecondary)

                            DatePicker(
                                "",
                                selection: $coordinator.selectedReminderTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .colorScheme(.dark)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(OnboardingTheme.surface)
                )

                OnboardingPrimaryButton(
                    title: L10n("onboarding.next"),
                    systemImage: "chevron.right",
                    isEnabled: coordinator.canAdvance
                ) {
                    coordinator.advance()
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .background(OnboardingTheme.background.ignoresSafeArea())
    }
}

#Preview("Dark") {
    OnboardingNotificationsView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}
