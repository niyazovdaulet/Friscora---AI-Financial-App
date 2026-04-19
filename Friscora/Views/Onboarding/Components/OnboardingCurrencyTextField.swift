//
//  OnboardingCurrencyTextField.swift
//  Friscora
//
//  Amount input using the same custom numeric keyboard as the Add tab (period decimal, grouped display).
//

import SwiftUI

struct OnboardingCurrencyTextField: View {
    @Binding var value: String
    let placeholder: String

    @State private var amountDisplay: String = ""
    @State private var focusTrigger: Int = 0
    @State private var isFocused: Bool = false

    var body: some View {
        AmountInputWithCustomKeyboard(
            amountDisplay: $amountDisplay,
            placeholder: placeholder,
            focusTrigger: focusTrigger,
            onFormatChange: { stripped in
                value = CurrencyFormatter.sanitizeAmountInput(stripped)
            },
            onFocusChange: { focused in
                isFocused = focused
            }
        )
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(OnboardingTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isFocused ? OnboardingTheme.borderSelected : OnboardingTheme.border, lineWidth: 1)
                )
        )
        .onAppear {
            amountDisplay = CurrencyFormatter.formatAmountForDisplay(value)
        }
        .onChange(of: value) { _, newValue in
            let formatted = CurrencyFormatter.formatAmountForDisplay(newValue)
            if formatted != amountDisplay {
                amountDisplay = formatted
            }
        }
    }
}
