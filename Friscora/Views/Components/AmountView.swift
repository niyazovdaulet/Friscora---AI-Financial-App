//
//  AmountView.swift
//  Friscora
//
//  Fintech-style amount display: split major/minor/currency, semantic typography,
//  width-based compact fallback. No character-count scaling.
//

import SwiftUI

enum AmountStyle {
    case hero      // Remaining Balance – primary, largest
    case secondary // Income & Expenses – secondary, fixed smaller
}

/// Renders amount with typographic hierarchy. Uses semantic font styles (Dynamic Type safe).
/// Overflow → compact format (1.4M PLN), never shrinks below design minimum.
struct AmountView: View {
    let amount: Double
    let style: AmountStyle
    let currencyCode: String

    private var components: AmountComponents {
        CurrencyFormatter.components(amount, currencyCode: currencyCode)
    }

    private var isCompactFormat: Bool {
        components.minor.isEmpty && components.currency.isEmpty
    }

    var body: some View {
        if isCompactFormat {
            compactLine
        } else {
            ViewThatFits(in: .horizontal) {
                splitView
                compactLine
            }
        }
    }

    // MARK: - Split layout (major .54 / PLN)

    private var splitView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(components.major)
                .font(majorFont)
                .foregroundColor(AppColorTheme.textPrimary)
                .monospacedDigit()

            Text(components.minor)
                .font(minorFont)
                .foregroundColor(AppColorTheme.textPrimary)
                .monospacedDigit()

            Text(components.currency)
                .font(currencyFont)
                .foregroundColor(AppColorTheme.textSecondary)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Compact fallback (1.4M PLN)

    private var compactLine: some View {
        Text(compactText)
            .font(majorFont)
            .foregroundColor(AppColorTheme.textPrimary)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .minimumScaleFactor(0.8)
    }

    private var compactText: String {
        isCompactFormat ? components.major : CurrencyFormatter.formatCompact(amount, currencyCode: currencyCode)
    }

    // MARK: - Semantic typography (Dynamic Type + device scaling)

    private var majorFont: Font {
        switch style {
        case .hero: return .system(.largeTitle, design: .rounded).weight(.bold)
        case .secondary: return .system(.title2, design: .rounded).weight(.bold)
        }
    }

    private var minorFont: Font {
        switch style {
        case .hero: return .system(.title3, design: .rounded).weight(.medium)
        case .secondary: return .system(.body, design: .rounded)
        }
    }

    private var currencyFont: Font {
        switch style {
        case .hero: return .caption
        case .secondary: return .caption2
        }
    }
}
