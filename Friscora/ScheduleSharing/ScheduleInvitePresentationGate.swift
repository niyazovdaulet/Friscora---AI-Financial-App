//
//  ScheduleInvitePresentationGate.swift
//  Friscora
//
//  Deep-linked invite sheets wait until onboarding and auth (if enabled) are satisfied.
//

import Foundation

enum ScheduleInvitePresentationGate {
    static var canPresentInviteSheetNow: Bool {
        let profile = UserProfileService.shared.profile
        guard profile.hasCompletedOnboarding else { return false }
        if profile.isAuthenticationEnabled, !AuthenticationService.shared.isAuthenticated {
            return false
        }
        return true
    }

    /// For `ScheduleShareLogging` when diagnosing why a deep-linked invite did not show immediately.
    static var diagnosticLine: String {
        let profile = UserProfileService.shared.profile
        return "onboarding=\(profile.hasCompletedOnboarding) authEnabled=\(profile.isAuthenticationEnabled) authenticated=\(AuthenticationService.shared.isAuthenticated)"
    }
}
