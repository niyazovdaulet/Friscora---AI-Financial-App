//
//  OnboardingGoalView.swift
//  Friscora
//

import SwiftUI

struct OnboardingGoalView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n("onboarding.goal_question"))
                    .font(OnboardingTheme.displayFont(size: 28))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n("onboarding.goal_helper"))
                    .font(OnboardingTheme.bodyFont(size: 15, weight: .medium))
                    .foregroundStyle(OnboardingTheme.textSecondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(OnboardingGoal.allCases, id: \.self) { goal in
                        OnboardingGoalOptionCard(
                            goal: goal,
                            isSelected: coordinator.selectedGoals.contains(goal)
                        ) {
                            HapticManager.light()
                            coordinator.toggleGoal(goal)
                        }
                    }
                }

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

private struct OnboardingGoalOptionCard: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: goal.sfSymbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.tealAccent : OnboardingTheme.textSecondary)

                Text(L10n(goal.titleKey))
                    .font(OnboardingTheme.bodyFont(size: 16, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(L10n(goal.subtitleKey))
                    .font(OnboardingTheme.bodyFont(size: 13, weight: .medium))
                    .foregroundStyle(OnboardingTheme.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(OnboardingTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? OnboardingTheme.borderSelected : OnboardingTheme.border, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Dark") {
    OnboardingGoalView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}
