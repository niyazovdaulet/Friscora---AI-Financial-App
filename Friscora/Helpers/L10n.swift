//
//  L10n.swift
//  Friscora
//
//  Centralized localized string access. Use these keys instead of hardcoded user-facing text.
//  All strings resolve from LocalizationManager.shared.bundle for runtime language switching.
//

import Foundation
import SwiftUI
import Combine

/// Localized string lookup using the current app language bundle.
/// Use for any user-facing text so language change applies everywhere.
func L10n(_ key: String) -> String {
    NSLocalizedString(key, bundle: LocalizationManager.shared.bundle, value: key, comment: "")
}

/// Convenience for SwiftUI Text: Text(L10n("key"))
extension String {
    /// Returns localized string for this key from the current language bundle.
    static func localized(_ key: String) -> String {
        L10n(key)
    }
}
