//
//  OnboardingTheme.swift
//  Friscora
//
//  Shared design tokens for onboarding flow.
//

import SwiftUI

struct OnboardingTheme {
    static let background = Color(hex: "#0A0F1E")
    static let surface = Color(hex: "#131929")
    static let surfaceElevated = Color(hex: "#1C2438")
    static let tealAccent = Color(hex: "#1DB88A")
    static let tealDim = Color(hex: "#1DB88A").opacity(0.15)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.3)
    static let border = Color.white.opacity(0.1)
    static let borderSelected = Color(hex: "#1DB88A")

    static func displayFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func bodyFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
