//
//  LanguageSettingsView.swift
//  Friscora
//
//  Language picker: list of supported languages with optional flag.
//  On selection change, shows confirmation alert and triggers app reload on confirm.
//

import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    @State private var pendingLanguageCode: String?
    @State private var showConfirmation = false
    
    var body: some View {
        List {
            ForEach(localizationManager.supportedLanguages) { language in
                Button {
                    selectLanguage(language)
                } label: {
                    HStack(spacing: 12) {
                        Text(language.flag)
                            .font(.title2)
                        Text(localizationManager.displayName(for: language))
                            .foregroundColor(AppColorTheme.textPrimary)
                        Spacer()
                        if language.code == localizationManager.currentLanguageCode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColorTheme.tabActive)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColorTheme.background)
        .navigationTitle(L10n("settings.language"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n("language.change.title"), isPresented: $showConfirmation) {
            Button(L10n("language.change.cancel"), role: .cancel) {
                pendingLanguageCode = nil
            }
            Button(L10n("language.change.confirm")) {
                applyPendingLanguage()
            }
        } message: {
            Text(L10n("language.change.message"))
        }
    }
    
    private func selectLanguage(_ language: AppLanguage) {
        guard language.code != localizationManager.currentLanguageCode else { return }
        pendingLanguageCode = language.code
        showConfirmation = true
    }
    
    private func applyPendingLanguage() {
        guard let code = pendingLanguageCode else { return }
        pendingLanguageCode = nil
        localizationManager.setLanguage(code)
        appState.triggerReload()
    }
}
