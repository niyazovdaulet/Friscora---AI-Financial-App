//
//  ScheduleSharingConfiguration.swift
//  Friscora
//
//  Universal Links base URL and App Store placeholder for schedule sharing.
//
//  MARK: - Firebase Hosting (default, no purchased domain)
//
//  Invite links use `https://<PROJECT_ID>.web.app/...` where `PROJECT_ID` comes from
//  `GoogleService-Info.plist` (`PROJECT_ID`). That matches Firebase Hosting’s default hostname.
//
//  1. Add a real `GoogleService-Info.plist` (from Firebase Console → Project settings → Your apps).
//  2. In Xcode → Signing & Capabilities → Associated Domains, add **both** (same `PROJECT_ID`):
//     - `applinks:<PROJECT_ID>.web.app`
//     - `applinks:<PROJECT_ID>.firebaseapp.com` (optional but matches Firebase’s alternate host)
//  3. Deploy Hosting so AASA is live:
//     `firebase deploy --only hosting`
//     Repo includes `Hosting/.well-known/apple-app-site-association` and `firebase.json` rewrites
//     `/schedule/join/*` to `schedule-share-landing.html`.
//  4. Update `Hosting/.well-known/apple-app-site-association` if Team ID or bundle id changes
//     (`appID` must be `<TeamID>.<bundleId>`).
//
//  MARK: - Apple Developer & hosting setup (Universal Links)
//
//  Verify with Apple’s CDN after deploy; links can take time to propagate after first install.
//
//  If `GoogleService-Info.plist` is missing or still has template IDs, `universalLinkHost` falls
//  back to `legacyFallbackUniversalLinkHost` (see below). Until Firebase is configured, testers
//  can use `friscora://schedule/join/<token>?…`.
//
//  The app still registers the custom URL scheme `friscora` for development and edge cases.
//

import Foundation

enum ScheduleSharingConfiguration {
    /// When `GoogleService-Info.plist` is absent or contains template `PROJECT_ID` values.
    private static let legacyFallbackUniversalLinkHost = "app.friscora.com"

    private static let templateFirebaseProjectIds: Set<String> = [
        "",
        "YOUR_FIREBASE_PROJECT_ID",
        "your-firebase-project-id"
    ]

    /// Firebase / GoogleService `PROJECT_ID` when configured; `nil` if plist missing or still a template.
    static func firebaseProjectIdIfConfigured() -> String? {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let raw = dict["PROJECT_ID"] as? String else {
            return nil
        }
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !templateFirebaseProjectIds.contains(id) else { return nil }
        return id
    }

    /// Host only (no scheme, no path). Prefer Firebase Hosting default: `<PROJECT_ID>.web.app`.
    static var universalLinkHost: String {
        if let pid = firebaseProjectIdIfConfigured() {
            return "\(pid).web.app"
        }
        return legacyFallbackUniversalLinkHost
    }

    /// Recognizes both default Firebase Hosting hostnames for the same project.
    static func matchesScheduleInviteHTTPSHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if let pid = firebaseProjectIdIfConfigured() {
            let p = pid.lowercased()
            if h == "\(p).web.app" || h == "\(p).firebaseapp.com" {
                return true
            }
        }
        let legacy = legacyFallbackUniversalLinkHost.lowercased()
        if h == legacy { return true }
        if h.hasSuffix("." + legacy) { return true }
        return false
    }

    static var httpsInviteBaseURL: URL {
        URL(string: "https://\(universalLinkHost)")!
    }

    /// Path prefix segments after the host: `/schedule/join/<token>`
    static let invitePathComponents = ["schedule", "join"]

    /// Placeholder App Store product page until App Store Connect provides the real id.
    static let appStoreListingURL = URL(string: "https://apps.apple.com/app/id0000000000")!

    /// Optional `friscora://` host for dev (see `ScheduleDeepLinkRouter`).
    static let customURLSchemeScheduleHostLegacy = "schedule-share"
    static let customURLSchemeScheduleHost = "schedule"
}
