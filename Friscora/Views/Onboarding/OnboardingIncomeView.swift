//
//  OnboardingIncomeView.swift
//  Friscora
//
//  Refactored onboarding income setup screen.
//

import SwiftUI

struct OnboardingIncomeView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var showsCurrencySheet = false

    private let featuredCurrencies = ["USD", "EUR", "GBP", "PLN", "KZT", "RUB", "AED", "CHF"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(heroAmount)
                        .font(OnboardingTheme.displayFont(size: 48))
                        .foregroundStyle(OnboardingTheme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.25), value: heroAmount)
                    Text(L10n("onboarding.income.monthly_income"))
                        .font(OnboardingTheme.bodyFont(size: 14, weight: .medium))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .onboardingEntrance(delay: 0.0)

                VStack(alignment: .leading, spacing: 10) {
                    CurrencyChipRow(currencies: featuredCurrencies, selectedCurrency: $coordinator.selectedCurrency)
                    Button {
                        showsCurrencySheet = true
                    } label: {
                        Text(L10n("onboarding.income.more_currencies"))
                            .font(OnboardingTheme.bodyFont(size: 14, weight: .semibold))
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .onboardingEntrance(delay: 0.1)

                VStack(spacing: 12) {
                    ForEach($coordinator.incomes) { $income in
                        OnboardingCurrencyTextField(
                            value: $income.amount,
                            placeholder: L10n("onboarding.income.placeholder")
                        )
                        .onChange(of: income.amount) { _, newValue in
                            coordinator.hasInteractedWithIncome = coordinator.hasInteractedWithIncome || !newValue.isEmpty
                        }
                    }

                    Button {
                        HapticManager.light()
                        coordinator.addIncomeSource()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text(L10n("onboarding.income.add_source"))
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .font(OnboardingTheme.bodyFont(size: 15, weight: .medium))
                        .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .onboardingEntrance(delay: 0.2)

                OnboardingPrimaryButton(
                    title: L10n("onboarding.next"),
                    systemImage: "chevron.right",
                    isEnabled: coordinator.canAdvance
                ) {
                    coordinator.advance()
                }
                .onboardingEntrance(delay: 0.35)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(OnboardingTheme.background.ignoresSafeArea())
        .onTapGesture {
            dismissKeyboard()
        }
        .sheet(isPresented: $showsCurrencySheet) {
            CurrencyListSheet(
                currencies: coordinator.currencies,
                selectedCurrency: $coordinator.selectedCurrency
            )
        }
    }

    private var heroAmount: String {
        let total = coordinator.incomes
            .compactMap { CurrencyFormatter.parsedAmount(from: $0.amount) }
            .reduce(0, +)
        return CurrencyFormatter.formatWithSymbol(total, currencyCode: coordinator.selectedCurrency)
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private struct CurrencyListSheet: View {
    let currencies: [String]
    @Binding var selectedCurrency: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [String] {
        guard !query.isEmpty else { return currencies }
        return currencies.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filtered, id: \.self) { currency in
                Button(currency) {
                    selectedCurrency = currency
                    dismiss()
                }
            }
            .searchable(text: $query, prompt: L10n("onboarding.income.search_currency"))
            .navigationTitle(L10n("onboarding.income.select_currency"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n("common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Dark") {
    OnboardingIncomeView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    OnboardingIncomeView()
        .environmentObject(OnboardingCoordinator())
        .preferredColorScheme(.light)
}
