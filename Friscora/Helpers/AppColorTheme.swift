//
//  AppColorTheme.swift
//  Friscora
//
//  Premium Fintech Color System - 3-Layer Hierarchy
//
//  LAYER 1 - App Background (Dark, Calm): Deep Navy #000926
//  LAYER 2 - Primary Cards (Neutral, Consistent): Card Blue #0B1E3A
//  LAYER 3 - Accent Indicators (Color used sparingly): Green/Red/Blue for indicators only
//
//  UX Rules:
//  - 80% Base UI: Navy backgrounds, unified card backgrounds, white/light text
//  - 10% Intelligence: Green only when AI adds value
//  - 10% Actions: Sapphire CTAs, Emerald success, Muted red destructive
//

import SwiftUI

/// Premium Fintech Color Theme for Friscora
/// Designed for: Professional fintech look, Advanced AI feel, Calm premium UX
struct AppColorTheme {
    
    // MARK: - 3-Layer Surface System
    
    /// Layer 1: App Background - Deep Navy (#000926)
    /// Use ONLY for: Screen background, safe areas, behind scroll views
    static let layer1Background = Color(hex: "000926")
    
    /// Layer 2: Primary Cards - Unified Card Background (#0B1E3A)
    /// Use for: ALL major sections (summary, categories, savings, activity)
    /// This creates structure and reduces visual noise
    static let layer2Card = Color(hex: "0B1E3A")
    
    /// Layer 2 Border: Subtle white at 5% opacity
    static let layer2Border = Color.white.opacity(0.05)
    
    /// Layer 3: Inner elements / elevated within cards
    static let layer3Elevated = Color(hex: "0A1628")
    
    // MARK: - 1️⃣ Primary Palette (Foundation / Trust Layer)
    
    /// Deep Navy - App background (dark mode) (#000926)
    /// Use for: Main app background, top bars, tab bar
    static let deepNavy = Color(hex: "000926")
    
    /// Sapphire - Accent blue for CTAs (#0F52BA)
    /// Use for: Primary CTAs, active states, highlights
    static let sapphire = Color(hex: "0F52BA")
    
    /// Ice Blue - Light background (#D6E6F3)
    /// Use for: textSecondary base
    static let iceBlue = Color(hex: "D6E6F3")
    
    /// Powder Blue - Secondary surfaces (#A6C5D7)
    /// Use for: Secondary buttons, inactive states, dividers
    static let powderBlue = Color(hex: "A6C5D7")
    
    // MARK: - 2️⃣ Accent Palette (Money / Success / AI Confirmation)
    
    /// Emerald Green - Positive balance / income (#50C878)
    /// Use for: Income, positive values, success CTAs
    static let emeraldGreen = Color(hex: "50C878")
    
    /// Royal Amethyst - AI success / categorized (#0B6E4F)
    /// Use for: AI confirmations, "categorized", "detected", smart insights
    static let royalAmethyst = Color(hex: "0B6E4F")
    
    /// Mint Whisper - Subtle highlights (#D1F2EB)
    /// Use for: Soft highlights, success backgrounds, subtle green tints
    static let mintWhisper = Color(hex: "D1F2EB")
    
    /// Dark Evergreen - Charts / growth (#013220)
    /// Use for: Chart fills, growth indicators, data visualization
    static let darkEvergreen = Color(hex: "013220")
    
    // MARK: - Semantic Mappings (Backward Compatibility)
    
    /// Primary brand color (Deep Navy)
    static let primary = deepNavy
    
    /// Secondary surface color (Sapphire)
    static let secondary = sapphire
    
    /// Accent color (Emerald Green - for intelligence moments)
    static let accent = emeraldGreen
    
    // MARK: - Neutral Grays (Refined for new palette)
    
    /// Light gray for subtle backgrounds
    static let grayLight = Color(hex: "0D1B2A")
    
    /// Medium gray for secondary text
    static let grayMedium = Color(hex: "8BA0B5")
    
    /// Dark gray for borders and dividers
    static let grayDark = Color(hex: "1B3A5C")
    
    // MARK: - Semantic Colors
    
    /// Positive/Income color (Emerald Green)
    /// Shows when: income detected, positive balance, growth
    static let positive = emeraldGreen
    
    /// Negative/Expense color (Bright coral red)
    static let negative = Color(hex: "FF6B6B")
    
    /// Negative muted (for text, not containers)
    static let negativeMuted = Color(hex: "FF8585")
    
    /// Warning color (Soft amber)
    static let warning = Color(hex: "E6A23C")
    
    /// Balance highlight color (Sapphire Blue)
    static let balanceHighlight = sapphire
    
    /// AI Intelligence color (Royal Amethyst)
    /// Shows when: AI categorized, detected patterns, smart insights
    static let aiSuccess = royalAmethyst
    
    /// Gold accent for AI / premium actions (sparkles, adviser)
    /// Distinct from green accent and month picker
    static let goldAccent = Color(hex: "D4AF37")
    
    // MARK: - Indicator Colors (Layer 3 - Sparingly used)
    
    /// Income indicator (icon/strip color)
    static let incomeIndicator = emeraldGreen

    /// Savings / goal allocations — darker emerald so KPI and charts don’t match income.
    static let savingsIndicator = Color(hex: "047857")
    
    /// Expense indicator (icon/strip color)
    static let expenseIndicator = Color(hex: "FF6B6B")
    
    /// Balance indicator (icon/strip color)
    static let balanceIndicator = sapphire
    
    /// Neutral/inactive indicator
    static let inactiveIndicator = Color(hex: "5A6B7D")
    
    // MARK: - Tab Bar Colors
    
    /// Tab bar background
    static let tabBarBackground = deepNavy
    
    /// Active tab icon
    static let tabActive = emeraldGreen
    
    /// Inactive tab icon
    static let tabInactive = Color(hex: "5A7A99")
    
    // MARK: - Background Colors
    
    /// Main background (Deep Navy) - Layer 1
    static let background = layer1Background
    
    /// Card/Container background - Layer 2 (unified for all sections)
    static let cardBackground = layer2Card
    
    /// Elevated surface background - Layer 3 (within cards)
    static let elevatedBackground = layer3Elevated
    
    /// Card border color
    static let cardBorder = layer2Border
    
    /// Subtle full-screen dim behind the schedule day composer. Prefer this over strong blur/material so the calendar stays contextual.
    static let scheduleComposerBackdropDim = Color.black.opacity(0.14)
    
    // MARK: - Text Colors
    
    /// Primary text color (Pure white for dark backgrounds)
    static let textPrimary = Color.white
    
    /// Secondary text color (Ice Blue tinted)
    static let textSecondary = iceBlue.opacity(0.85)
    
    /// Tertiary text color (Powder Blue)
    static let textTertiary = powderBlue.opacity(0.7)
    
    /// Text on light backgrounds
    static let textOnLight = deepNavy
    
    // MARK: - CTA Colors (Action System)
    
    /// Primary CTA color (Sapphire Blue)
    static let ctaPrimary = sapphire
    
    /// Success CTA color (Emerald Green)
    static let ctaSuccess = emeraldGreen
    
    /// Destructive action color (Coral red)
    static let ctaDestructive = Color(hex: "FF6B6B")
    
    // MARK: - Gradient Helpers
    
    /// Primary gradient (Deep Navy depth)
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [deepNavy, Color(hex: "001033")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Card gradient (Sapphire variations)
    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [sapphire, sapphire.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Accent gradient (Emerald Green)
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [emeraldGreen, emeraldGreen.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Positive gradient (for income) - Emerald to Mint
    static var positiveGradient: LinearGradient {
        LinearGradient(
            colors: [emeraldGreen, royalAmethyst],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Negative gradient (for expenses) - Muted red
    static var negativeGradient: LinearGradient {
        LinearGradient(
            colors: [negative, negative.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Neutral gradient (for balance and neutral states)
    static var neutralGradient: LinearGradient {
        LinearGradient(
            colors: [sapphire.opacity(0.6), grayDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Balance gradient (Sapphire Blue emphasis)
    static var balanceGradient: LinearGradient {
        LinearGradient(
            colors: [sapphire, Color(hex: "1A5DC8")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// AI Success gradient (Royal Amethyst for intelligence moments)
    static var aiSuccessGradient: LinearGradient {
        LinearGradient(
            colors: [royalAmethyst, darkEvergreen],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Goals-Specific Colors (Pro / Luxury Palette)
    
    /// Goals base background (Deep Navy variant)
    static let goalsBackground = Color(hex: "000D1A")
    
    /// Goals primary accent (aligned with savings, distinct from income emerald)
    static let goalsAccent = savingsIndicator
    
    /// Goals secondary accent (Mint Whisper)
    static let goalsSecondaryAccent = mintWhisper
    
    /// Goals completed state (Powder Blue muted)
    static let goalsCompleted = powderBlue.opacity(0.6)
    
    /// Goals/Savings card background (slightly darker than layer2)
    static let savingsCardBackground = Color(hex: "102A5C")
    
    /// Goals card gradient top (Sapphire dark)
    static let goalsCardTop = Color(hex: "0A3D8F")
    
    /// Goals card gradient bottom (Deep Sapphire)
    static let goalsCardBottom = Color(hex: "083070")
    
    /// Goals card gradient
    static var goalsCardGradient: LinearGradient {
        LinearGradient(
            colors: [goalsCardTop, goalsCardBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    /// Goals accent gradient (deep emerald)
    static var goalsAccentGradient: LinearGradient {
        LinearGradient(
            colors: [savingsIndicator, savingsIndicator.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Goals completed gradient
    static var goalsCompletedGradient: LinearGradient {
        LinearGradient(
            colors: [powderBlue.opacity(0.5), powderBlue.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Chart Colors (Data Visualization)
    
    /// Chart primary (Dark Evergreen for growth)
    static let chartPrimary = darkEvergreen
    
    /// Chart secondary (Sapphire)
    static let chartSecondary = sapphire
    
    /// Chart accent (Emerald Green)
    static let chartAccent = emeraldGreen
    
    /// Chart bar background (muted blue-gray)
    static let chartBarBackground = Color(hex: "1A3A5C")
    
    /// Chart bar fill (teal-blue tint)
    static let chartBarFill = Color(hex: "2E8B9A")
    
    /// Chart colors array for multi-series
    static let chartColors: [Color] = [
        emeraldGreen,
        sapphire,
        royalAmethyst,
        powderBlue,
        darkEvergreen
    ]
    
    // MARK: - Row Divider
    
    /// Subtle divider for list rows (white @ 6%)
    static let rowDivider = Color.white.opacity(0.06)
    
    // MARK: - Category Colors (Spending by Category progress bars)
    
    /// Hex for built-in category chart color (single source with `color(for:)`).
    static func chartColorHex(for category: ExpenseCategory) -> String {
        switch category {
        case .food: return "E6A23C"
        case .rent: return "0F52BA"
        case .transport: return "2E8B9A"
        case .entertainment: return "8E44AD"
        case .subscriptions: return "E879A9"
        case .other: return "A6C5D7"
        }
    }

    /// Distinct, modern color per built-in expense category. Keeps palette consistency (navy/sapphire/emerald/teal).
    /// Custom categories use `CategoryDisplayInfo.chartTintColor` / `defaultCustomCategoryChartColor`.
    static func color(for category: ExpenseCategory) -> Color {
        Color(hex: chartColorHex(for: category))
    }

    /// Fallback when a custom category has no valid hex.
    static let defaultCustomCategoryChartColor = chartBarFill
}

// MARK: - Color Extension

extension Color {
    /// Initialize Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
