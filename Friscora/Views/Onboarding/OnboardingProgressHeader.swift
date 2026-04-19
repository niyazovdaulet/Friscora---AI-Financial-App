//
//  OnboardingProgressHeader.swift
//  Friscora
//
//  Top progress and navigation controls for onboarding.
//

import SwiftUI

struct OnboardingProgressHeader: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator

    private let totalSteps = OnboardingStep.progressStepCount

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if showsBack {
                Button {
                    HapticManager.light()
                    coordinator.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(OnboardingTheme.surfaceElevated)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n("onboarding.progress.back")))
                .accessibilityHint(Text(L10n("onboarding.progress.back.hint")))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(stepLabel)
                    .font(OnboardingTheme.bodyFont(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .accessibilityValue(Text("Step \(visibleStep) of \(totalSteps)"))

                HStack(spacing: 8) {
                    ForEach(1...totalSteps, id: \.self) { step in
                        ProgressPill(
                            state: pillState(for: step),
                            fillFraction: fillFraction(for: step)
                        )
                    }
                }
            }

            Spacer()

            if showsSkip {
                Button {
                    HapticManager.light()
                    coordinator.skip()
                } label: {
                    Text(L10n("onboarding.progress.skip"))
                        .font(OnboardingTheme.bodyFont(size: 14, weight: .semibold))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L10n("onboarding.progress.skip")))
                .accessibilityHint(Text(L10n("onboarding.progress.skip.hint")))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue(Text("Step \(visibleStep) of \(totalSteps)"))
    }

    private var visibleStep: Int {
        let step = max(1, coordinator.currentStep.progressIndex)
        return min(step, totalSteps)
    }

    private var stepLabel: String {
        String(
            format: L10n("onboarding.progress.step_of"),
            visibleStep,
            totalSteps
        )
    }

    private var showsBack: Bool {
        coordinator.currentStep.progressIndex >= 2 && coordinator.currentStep != .completion
    }

    private var showsSkip: Bool {
        coordinator.currentStep == .goal ||
        coordinator.currentStep == .notifications ||
        coordinator.currentStep == .security
    }

    private func pillState(for step: Int) -> ProgressPill.State {
        if step < visibleStep {
            return .completed
        }
        if step == visibleStep {
            return .active
        }
        return .upcoming
    }

    private func fillFraction(for step: Int) -> CGFloat {
        if step < visibleStep { return 1.0 }
        if step == visibleStep { return 1.0 }
        return 0.0
    }
}

private struct ProgressPill: View {
    enum State {
        case active
        case completed
        case upcoming
    }

    let state: State
    let fillFraction: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(OnboardingTheme.textPrimary.opacity(0.15))

            GeometryReader { proxy in
                Capsule()
                    .fill(fillColor)
                    .frame(width: proxy.size.width * fillFraction)
                    .animation(.easeInOut(duration: 0.4), value: fillFraction)
            }
        }
        .frame(height: 8)
    }

    private var fillColor: Color {
        switch state {
        case .active:
            return OnboardingTheme.tealAccent
        case .completed:
            return OnboardingTheme.tealAccent.opacity(0.75)
        case .upcoming:
            return OnboardingTheme.textPrimary.opacity(0.15)
        }
    }
}

#Preview("Dark") {
    ZStack {
        OnboardingTheme.background.ignoresSafeArea()
        OnboardingProgressHeader()
            .environmentObject(OnboardingCoordinator())
            .padding()
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    ZStack {
        OnboardingTheme.background.ignoresSafeArea()
        OnboardingProgressHeader()
            .environmentObject(OnboardingCoordinator())
            .padding()
    }
    .preferredColorScheme(.light)
}
