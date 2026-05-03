//
//  AppConstants.swift
//  Friscora
//
//  Values shared across the app; replace placeholders before App Store submission where noted.
//
// Export compliance: exempt-only crypto (TLS, Keychain/LocalAuthentication, OS); app target sets ITSAppUsesNonExemptEncryption false—use YES + App Store Connect questionnaire if you add non-exempt crypto.

import Foundation

enum AppConstants {
    /// Numeric App Store ID used in `https://apps.apple.com/app/id…` links (Profile → rate / open App Store).
    /// Set **FRISCORA_APP_STORE_ID** in the target’s Info custom properties (or replace the default string here) before shipping.
    static var appStoreNumericID: String {
        if let s = Bundle.main.object(forInfoDictionaryKey: "FRISCORA_APP_STORE_ID") as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, t != "YOUR_APP_STORE_ID" { return t }
        }
        return "YOUR_APP_STORE_ID"
    }

    enum Security {
        /// Grace period before re-auth is required after app resumes from background.
        /// Keep in the 60...300 range unless product requirements change.
        static let authGracePeriodSeconds: TimeInterval = 180
    }
}
