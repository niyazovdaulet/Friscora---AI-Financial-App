//
//  ScheduleShareCoordinator.swift
//  Friscora
//
//  Routes incoming invite links (Universal Links + friscora://) to the Schedule tab.
//

import Foundation
import SwiftUI
import Combine

final class ScheduleShareCoordinator: ObservableObject {
    static let shared = ScheduleShareCoordinator()

    /// Ready to show immediately (onboarding + auth satisfied).
    @Published var pendingInvite: ShareInvitePayload?
    /// Queued until `ScheduleInvitePresentationGate` allows presentation.
    @Published var deferredInvitePayload: ShareInvitePayload?
    @Published var shouldOpenScheduleTab: Bool = false

    func handleIncomingURL(_ url: URL) {
        ScheduleShareLogging.trace(
            "handleIncomingURL scheme=\(url.scheme ?? "?") host=\(url.host ?? "?") path=\(url.path)"
        )
        guard let invite = ScheduleDeepLinkRouter.invitePayload(from: url) else {
            ScheduleShareLogging.trace(
                "handleIncomingURL: URL did not parse as schedule invite (wrong host/path/scheme or missing token). Full: \(url.absoluteString)"
            )
            return
        }
        ScheduleShareLogging.trace(
            "handleIncomingURL: parsed token=\(ScheduleShareLogging.redactedTokenDescription(invite.token)) sender=\(invite.senderName) scope=\(invite.scope.rawValue) items=\(invite.shareItems.map(\.rawValue))"
        )
        routeInvite(invite)
    }

    func handleBrowsingWebActivity(_ userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else {
            ScheduleShareLogging.trace("handleBrowsingWebActivity: ignored activityType=\(userActivity.activityType)")
            return
        }
        guard let url = userActivity.webpageURL else {
            ScheduleShareLogging.trace("handleBrowsingWebActivity: no webpageURL")
            return
        }
        ScheduleShareLogging.trace("handleBrowsingWebActivity: \(url.absoluteString)")
        handleIncomingURL(url)
    }

    private func routeInvite(_ invite: ShareInvitePayload) {
        let gateOK = ScheduleInvitePresentationGate.canPresentInviteSheetNow
        ScheduleShareLogging.trace("routeInvite gate=\(ScheduleInvitePresentationGate.diagnosticLine) → canPresent=\(gateOK)")
        if gateOK {
            pendingInvite = invite
            ScheduleShareLogging.trace("routeInvite: assigned pendingInvite (sheet may show)")
        } else {
            deferredInvitePayload = invite
            ScheduleShareLogging.trace("routeInvite: deferred until onboarding/auth allow presentation")
        }
        shouldOpenScheduleTab = true
    }

    /// Call when onboarding completes or auth unlocks so a queued invite can surface.
    func flushDeferredInviteIfReady() {
        guard let queued = deferredInvitePayload,
              ScheduleInvitePresentationGate.canPresentInviteSheetNow else {
            if deferredInvitePayload != nil {
                ScheduleShareLogging.trace("flushDeferredInviteIfReady: still blocked (\(ScheduleInvitePresentationGate.diagnosticLine))")
            }
            return
        }
        ScheduleShareLogging.trace("flushDeferredInviteIfReady: moving deferred → pendingInvite")
        pendingInvite = queued
        deferredInvitePayload = nil
    }

    func consumeOpenScheduleFlag() {
        ScheduleShareLogging.trace("consumeOpenScheduleFlag")
        shouldOpenScheduleTab = false
    }

    func consumePendingInvite() {
        ScheduleShareLogging.trace("consumePendingInvite")
        pendingInvite = nil
    }
}
