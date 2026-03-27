//
//  LocalizationManager.swift
//  Friscora
//
//  Manages in-app language selection and runtime bundle-based localization.
//  Supports dynamic language switching without app restart via controlled UI reload.
//

import SwiftUI
import Combine

/// Supported app language: language code and display metadata.
struct AppLanguage: Identifiable, Equatable {
    let id: String
    let code: String
    let flag: String
    /// Localization key for the language name (e.g. "language.name.en").
    let nameKey: String
    
    static func == (lhs: AppLanguage, rhs: AppLanguage) -> Bool {
        lhs.code == rhs.code
    }
}

/// Keys for UserDefaults persistence.
private enum StorageKey {
    static let selectedLanguageCode = "friscora_selected_language_code"
}

/// Manages current language, persistence, and provides the correct .lproj bundle
/// for runtime string lookup. All user-facing strings should be loaded via
/// this manager's bundle (e.g. through L10n or NSLocalizedString(..., bundle: manager.bundle)).
final class LocalizationManager: ObservableObject {
    
    static let shared = LocalizationManager()
    
    /// Currently selected language code (e.g. "en", "pl", "ru").
    /// Persisted; on launch we load this and apply before first paint.
    @Published private(set) var currentLanguageCode: String
    
    /// Supported languages. Extend this array to add more languages.
    let supportedLanguages: [AppLanguage] = [
        AppLanguage(id: "en", code: "en", flag: "🇬🇧", nameKey: "language.name.en"),
        AppLanguage(id: "pl", code: "pl", flag: "🇵🇱", nameKey: "language.name.pl"),
        AppLanguage(id: "ru", code: "ru", flag: "🇷🇺", nameKey: "language.name.ru"),
        AppLanguage(id: "kk", code: "kk", flag: "🇰🇿", nameKey: "language.name.kk")
    ]
    
    /// Bundle for the current language. Use this for all NSLocalizedString / String(localized:)
    /// lookups so that runtime language selection is respected.
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
    
    /// Locale for the current language (for date/number formatting if needed).
    var currentLocale: Locale {
        Locale(identifier: currentLanguageCode)
    }
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: StorageKey.selectedLanguageCode)
        if let saved = saved, Self.supportedCodes.contains(saved) {
            currentLanguageCode = saved
        } else {
            // Use system language if supported, otherwise fallback to English.
            let preferred = Locale.preferredLanguages.first ?? "en"
            let preferredBase = String(preferred.prefix(2))
            currentLanguageCode = Self.supportedCodes.contains(preferredBase) ? preferredBase : "en"
        }
    }
    
    private static let supportedCodes: Set<String> = ["en", "pl", "ru", "kk"]
    
    /// Updates the app language and persists it. Call this after user confirms in the language picker.
    /// Does not reload the UI; the caller (e.g. AppState) is responsible for triggering a root view reload.
    func setLanguage(_ code: String) {
        guard Self.supportedCodes.contains(code), code != currentLanguageCode else { return }
        currentLanguageCode = code
        UserDefaults.standard.set(code, forKey: StorageKey.selectedLanguageCode)
        objectWillChange.send()
    }
    
    /// Display name for a language in the current UI language (for the picker).
    func displayName(for language: AppLanguage) -> String {
        NSLocalizedString(language.nameKey, bundle: bundle, comment: "Language name in picker")
    }
    
    /// Month + year string for display (e.g. in pickers and calendar headers).
    /// Uses standalone (nominative) month symbols so Russian shows "Февраль" instead of "февраля".
    func monthYearString(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = currentLocale
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        let symbols = cal.standaloneMonthSymbols
        guard month >= 1, month <= 12, month <= symbols.count else {
            let f = DateFormatter()
            f.dateFormat = "MMMM yyyy"
            f.locale = currentLocale
            return f.string(from: date)
        }
        let monthName = symbols[month - 1]
        let capitalized = monthName.prefix(1).uppercased() + monthName.dropFirst()
        return "\(capitalized) \(year)"
    }
}
