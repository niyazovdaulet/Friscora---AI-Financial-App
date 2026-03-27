//
//  AppDesignSystem.swift
//  Friscora
//
//  Spacing, typography, and CTA constants for consistent visual hierarchy
//  and alignment across Dashboard, Analytics, Goals, Profile, and other screens.
//

import SwiftUI

// MARK: - Spacing

/// Consistent spacing for padding and VStack/HStack. Use these so all screens feel aligned.
enum AppSpacing {
    /// 8pt – tight (e.g. between icon and label in a chip)
    static let xs: CGFloat = 8
    /// 12pt – compact (e.g. internal card padding, small gaps)
    static let s: CGFloat = 12
    /// 16pt – default (e.g. card padding, section spacing)
    static let m: CGFloat = 16
    /// 20pt – relaxed (e.g. between sections)
    static let l: CGFloat = 20
    /// 24pt – spacious (e.g. screen horizontal padding, large section gaps)
    static let xl: CGFloat = 24
}

// MARK: - Typography

/// Typography tokens: hero numbers, card titles, body, captions.
/// Prefer these over ad-hoc font sizes; use rounded design for headings.
enum AppTypography {
    /// Hero numbers (balance, big KPIs) – rounded, bold, 28pt
    static let heroNumber = Font.system(size: 28, weight: .bold, design: .rounded)
    /// Card/section titles – rounded, semibold, 17pt
    static let cardTitle = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Body – regular, 16pt (primary content)
    static let body = Font.system(size: 16, weight: .regular)
    /// Body medium – 16pt semibold for emphasis
    static let bodySemibold = Font.system(size: 16, weight: .semibold)
    /// Secondary body – 15pt (slightly smaller for supporting text)
    static let bodySecondary = Font.system(size: 15, weight: .regular)
    /// Caption – 14pt (hints, labels, secondary)
    static let caption = Font.system(size: 14, weight: .regular)
    /// Caption medium – 14pt medium for small buttons
    static let captionMedium = Font.system(size: 14, weight: .medium)
}

// MARK: - Corner radius

/// Card and button corner radii (align with 3-layer system).
enum AppRadius {
    /// 12pt – buttons, chips, small cards
    static let button: CGFloat = 12
    /// 16pt – list rows, medium cards
    static let cardMedium: CGFloat = 16
    /// 20pt – section cards (Layer 2)
    static let card: CGFloat = 20
}

// MARK: - CTA

/// Primary CTA: min height 50pt, corner radius 14, subtle gradient, press scale.
struct PrimaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodySemibold)
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColorTheme.accentGradient)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.quickUI, value: configuration.isPressed)
    }
}

/// Secondary CTA: outlined or subtle fill, same corner radius.
struct SecondaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.captionMedium)
            .foregroundColor(AppColorTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.button)
                    .fill(AppColorTheme.layer3Elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.button)
                            .stroke(AppColorTheme.cardBorder, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(AppAnimation.quickUI, value: configuration.isPressed)
    }
}
