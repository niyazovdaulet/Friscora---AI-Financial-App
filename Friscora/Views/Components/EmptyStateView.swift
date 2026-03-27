//
//  EmptyStateView.swift
//  Friscora
//
//  Reusable empty state: icon, message, optional primary action.
//  Use for recent activity, goals, categories, history, analytics, etc.
//

import SwiftUI

/// Empty state with SF Symbol, message, and optional CTA. Keeps lists consistent.
struct EmptyStateView: View {
    /// SF Symbol name (e.g. "tray", "target", "chart.pie")
    var icon: String
    /// Short copy (from L10n)
    var message: String
    /// Optional secondary line (e.g. "Try adjusting filters")
    var detail: String? = nil
    /// CTA title (e.g. "Add expense"); nil = no button
    var actionTitle: String? = nil
    /// CTA action; only used if actionTitle != nil
    var action: (() -> Void)? = nil
    
    /// Icon tint (default: accent)
    var iconColor: Color = AppColorTheme.accent
    /// If true, use compact vertical padding (e.g. inside a card)
    var compact: Bool = false
    
    var body: some View {
        VStack(spacing: AppSpacing.l) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 44))
                    .foregroundColor(iconColor)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: AppSpacing.xs) {
                Text(message)
                    .font(AppTypography.cardTitle)
                    .foregroundColor(AppColorTheme.textPrimary)
                    .multilineTextAlignment(.center)
                if let detail = detail {
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColorTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if let title = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(title)
                    }
                }
                .buttonStyle(PrimaryCTAButtonStyle())
                .padding(.top, compact ? 0 : AppSpacing.s)
                .accessibilityLabel(title)
                .accessibilityHint("Double tap to add")
            }
        }
        .padding(compact ? AppSpacing.m : 40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ZStack {
        AppColorTheme.background.ignoresSafeArea()
        EmptyStateView(
            icon: "tray",
            message: "No activity yet",
            detail: "Add your first expense to get started",
            actionTitle: "Add expense",
            action: { }
        )
    }
    .preferredColorScheme(.dark)
}
