//
//  AppConstants.swift
//  Friscora
//
//  Values shared across the app; replace placeholders before App Store submission where noted.
//

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
}
