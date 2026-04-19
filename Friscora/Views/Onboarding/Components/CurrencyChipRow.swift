//
//  CurrencyChipRow.swift
//  Friscora
//
//  Horizontal quick currency selection chips.
//

import SwiftUI

struct CurrencyChipRow: View {
    let currencies: [String]
    @Binding var selectedCurrency: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(currencies, id: \.self) { code in
                    Button {
                        HapticManager.light()
                        selectedCurrency = code
                    } label: {
                        HStack(spacing: 6) {
                            Text(code)
                                .font(OnboardingTheme.bodyFont(size: 14, weight: .semibold))
                            Text(currencySymbol(for: code))
                                .font(OnboardingTheme.bodyFont(size: 14, weight: .medium))
                        }
                        .foregroundStyle(selectedCurrency == code ? OnboardingTheme.textPrimary : OnboardingTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(
                                    selectedCurrency == code
                                    ? OnboardingTheme.tealAccent
                                    : OnboardingTheme.textPrimary.opacity(0.1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("\(code) \(currencySymbol(for: code))"))
                    .accessibilityHint(Text(L10n("onboarding.income.currency_hint")))
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func currencySymbol(for code: String) -> String {
        if let symbol = Locale.commonISOCurrencyCodes.compactMap({
            Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.currencyCode.rawValue: $0]))
        }).first(where: { $0.currency?.identifier == code })?.currencySymbol {
            return symbol
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }
}
