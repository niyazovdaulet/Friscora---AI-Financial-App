//
//  ScheduleSharingAPI.swift
//  Friscora
//
//  Backend contract + mock (in-memory) implementation. Swap `LiveScheduleSharingAPI` for URLSession when ready.
//

import Foundation

// MARK: - Feature flag

enum ScheduleSharingBackendMode {
    /// `true` — use `MockScheduleSharingAPI.shared` (in-memory invite state + Firestore for cross-device).  
    /// `false` — use `LiveScheduleSharingAPI`, which **delegates to the same shared implementation** backed by **Firebase/Firestore** (no paid REST server).  
    /// Add a URLSession-based `ScheduleSharingAPI` later if you want a custom backend; until then, “live” means Firestore.
    static var useMockAPI: Bool = false
}

// MARK: - Protocol

protocol ScheduleSharingAPI: Sendable {
    func createInvite(_ request: ShareLinkCreateRequest) async throws -> ShareLinkCreateResponse
    func resolveInviteToken(_ token: String) async throws -> InviteTokenResolveResponse
    func acceptInvite(_ request: AcceptInviteRequest) async throws -> AcceptInviteResponse
    func declineInvite(token: String) async throws
    func revokeOutgoingInvite(token: String) async throws
    func revokePairing(pairingId: UUID) async throws
    func fetchPartnerSchedule(pairingId: UUID, month: Date, viewerRole: SchedulePartnershipRole, inviteToken: String?) async throws -> PartnerScheduleSnapshot
    /// Inviter: pass `outgoingToken`; recipient: pass `pairingId` after accept.
    /// When mock RAM is empty (other device / relaunch), pass persisted `inviteToken` + `role` from `SchedulePartnership` so Firestore can restore the doc + snapshot cache.
    func fetchActivePairing(
        outgoingToken: String?,
        knownPairingId: UUID?,
        persistedInviteToken: String?,
        persistedRole: SchedulePartnershipRole?
    ) async throws -> SchedulePartnership?
}

// MARK: - Live (Firebase/Firestore — no separate paid API)

/// Production path: same behavior as `MockScheduleSharingAPI.shared` (Firestore-backed pairing + optional RAM cache).
/// Swap this type’s implementation only if you introduce a non-Firebase HTTP backend.
final class LiveScheduleSharingAPI: ScheduleSharingAPI, @unchecked Sendable {
    private let impl = MockScheduleSharingAPI.shared

    func createInvite(_ request: ShareLinkCreateRequest) async throws -> ShareLinkCreateResponse {
        ScheduleShareLogging.trace("LiveScheduleSharingAPI.createInvite → shared MockScheduleSharingAPI (Firestore)")
        return try await impl.createInvite(request)
    }

    func resolveInviteToken(_ token: String) async throws -> InviteTokenResolveResponse {
        try await impl.resolveInviteToken(token)
    }

    func acceptInvite(_ request: AcceptInviteRequest) async throws -> AcceptInviteResponse {
        try await impl.acceptInvite(request)
    }

    func declineInvite(token: String) async throws {
        try await impl.declineInvite(token: token)
    }

    func revokeOutgoingInvite(token: String) async throws {
        try await impl.revokeOutgoingInvite(token: token)
    }

    func revokePairing(pairingId: UUID) async throws {
        try await impl.revokePairing(pairingId: pairingId)
    }

    func fetchPartnerSchedule(pairingId: UUID, month: Date, viewerRole: SchedulePartnershipRole, inviteToken: String?) async throws -> PartnerScheduleSnapshot {
        try await impl.fetchPartnerSchedule(pairingId: pairingId, month: month, viewerRole: viewerRole, inviteToken: inviteToken)
    }

    func fetchActivePairing(
        outgoingToken: String?,
        knownPairingId: UUID?,
        persistedInviteToken: String?,
        persistedRole: SchedulePartnershipRole?
    ) async throws -> SchedulePartnership? {
        try await impl.fetchActivePairing(
            outgoingToken: outgoingToken,
            knownPairingId: knownPairingId,
            persistedInviteToken: persistedInviteToken,
            persistedRole: persistedRole
        )
    }
}

// MARK: - Mock (in-memory + UserDefaults handoff for same-process inviter/recipient)

final class MockScheduleSharingAPI: ScheduleSharingAPI, @unchecked Sendable {
    /// Single process-wide instance so pairing/invite RAM matches `ScheduleSharingRepository.shared` after relaunch when paired with Firestore.
    static let shared = MockScheduleSharingAPI()

    private let lock = NSLock()
    private var inviteStates: [String: MockInviteState] = [:]
    private var pairingById: [UUID: MockPairingState] = [:]

    private struct MockInviteState {
        let ownerDisplayName: String
        let shareItems: [ShareItem]
        let expiresAt: Date?
        let inviterSnapshot: PartnerScheduleSnapshot
        var acceptance: MockAcceptance?
    }

    private struct MockAcceptance {
        let pairingId: UUID
        let recipientDisplayName: String
        let recipientSnapshot: PartnerScheduleSnapshot
    }

    private struct MockPairingState {
        let pairingId: UUID
        let inviterDisplayName: String
        let recipientDisplayName: String
        let inviterSnapshot: PartnerScheduleSnapshot
        let recipientSnapshot: PartnerScheduleSnapshot
        let shareItems: [ShareItem]
        let scope: ShareScope
    }

    func createInvite(_ request: ShareLinkCreateRequest) async throws -> ShareLinkCreateResponse {
        ScheduleShareLogging.trace(
            "MockScheduleSharingAPI.createInvite owner=\(request.ownerDisplayName) items=\(request.shareItems.map(\.rawValue)) exp=\(request.expiresAt.map { "\($0)" } ?? "nil")"
        )
        try await Task.sleep(nanoseconds: 80_000_000)
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let shareSet = Set(request.shareItems)
        let inviterSnapshot = ScheduleSharingScheduleExporter.exportSnapshot(shareItems: shareSet)

        do {
            try await SchedulePairingFirestoreSync.publishInviterInviteDraft(
                token: token,
                inviterDisplayName: request.ownerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
                inviterSnapshot: inviterSnapshot,
                shareItems: request.shareItems,
                scope: ShareScope.allMonths
            )
        } catch {
            ScheduleShareLogging.trace("MockScheduleSharingAPI.createInvite: Firestore draft failed \(String(describing: error))")
            throw ScheduleSharingServiceError.networkFailure
        }

        lock.lock()
        inviteStates[token] = MockInviteState(
            ownerDisplayName: request.ownerDisplayName,
            shareItems: request.shareItems,
            expiresAt: request.expiresAt,
            inviterSnapshot: inviterSnapshot,
            acceptance: nil
        )
        lock.unlock()

        let inviteURL = Self.buildHTTPSInviteURL(
            token: token,
            sender: request.ownerDisplayName,
            scope: ShareScope.allMonths,
            shareItems: request.shareItems,
            expiresAt: request.expiresAt
        )

        return ShareLinkCreateResponse(
            inviteURL: inviteURL,
            token: token,
            expiresAt: request.expiresAt,
            shareItems: request.shareItems,
            joinedCount: 0
        )
    }

    func resolveInviteToken(_ token: String) async throws -> InviteTokenResolveResponse {
        ScheduleShareLogging.trace("MockScheduleSharingAPI.resolveInviteToken token=\(ScheduleShareLogging.redactedTokenDescription(token))")
        try await Task.sleep(nanoseconds: 50_000_000)
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw ScheduleSharingServiceError.invalidLink }
        if t.lowercased().contains("expired") { throw ScheduleSharingServiceError.expired }
        if t.lowercased().contains("revoked") { throw ScheduleSharingServiceError.revoked }

        lock.lock()
        let state = inviteStates[t]
        lock.unlock()

        if let state {
            return InviteTokenResolveResponse(
                senderName: state.ownerDisplayName,
                scope: ShareScope.allMonths,
                shareItems: state.shareItems,
                expiresAt: state.expiresAt
            )
        }

        // Token not created in this session: synthesize for deep link QA
        return InviteTokenResolveResponse(
            senderName: L10n("schedule.share.resolve.placeholder_sender"),
            scope: .allMonths,
            shareItems: [.shifts, .events],
            expiresAt: nil
        )
    }

    func acceptInvite(_ request: AcceptInviteRequest) async throws -> AcceptInviteResponse {
        try await Task.sleep(nanoseconds: 120_000_000)
        let token = request.token.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().contains("networkfail") { throw ScheduleSharingServiceError.networkFailure }

        let recipientSnapshot = ScheduleSharingScheduleExporter.exportSnapshot(
            shareItems: Set(ShareItem.allCases)
        )

        // Load inviter’s real exported snapshot from Firestore (uploaded by inviter at create time).
        // Never use the recipient’s local export as the inviter snapshot — that caused empty/wrong partner views.
        let inviterDraft = await SchedulePairingFirestoreSync.fetchInviterDraftFromFirestore(token: token)

        lock.lock()
        if inviteStates[token] == nil {
            if let draft = inviterDraft {
                inviteStates[token] = MockInviteState(
                    ownerDisplayName: draft.name,
                    shareItems: draft.shareItems,
                    expiresAt: nil,
                    inviterSnapshot: draft.snapshot,
                    acceptance: nil
                )
                ScheduleShareLogging.trace("MockScheduleSharingAPI.acceptInvite: loaded inviter draft from Firestore")
            } else {
                inviteStates[token] = MockInviteState(
                    ownerDisplayName: L10n("schedule.share.resolve.placeholder_sender"),
                    shareItems: [.shifts, .events],
                    expiresAt: nil,
                    inviterSnapshot: PartnerScheduleSnapshot(days: [:], shareItems: [.shifts, .events]),
                    acceptance: nil
                )
                ScheduleShareLogging.trace(
                    "MockScheduleSharingAPI.acceptInvite: no inviter Firestore draft — using empty inviter snapshot (check network / rules)"
                )
            }
        }
        guard let state = inviteStates[token] else {
            lock.unlock()
            throw ScheduleSharingServiceError.invalidLink
        }
        if state.acceptance != nil {
            lock.unlock()
            throw ScheduleSharingServiceError.revoked
        }

        let inviterName = state.ownerDisplayName
        let pairingId = UUID()
        let shareItems = state.shareItems
        let inviterSnapshotForPairing = state.inviterSnapshot
        lock.unlock()

        // Persist pairing to Firestore before mutating mock RAM so we never report success if the doc/cache sync failed.
        do {
            try await SchedulePairingFirestoreSync.mergeRecipientAcceptance(
                token: token,
                pairingId: pairingId,
                recipientDisplayName: request.recipientDisplayName,
                recipientSnapshot: recipientSnapshot,
                shareItems: shareItems,
                scope: ShareScope.allMonths
            )
        } catch {
            ScheduleShareLogging.trace("MockScheduleSharingAPI.acceptInvite: merge failed \(String(describing: error))")
            throw ScheduleSharingServiceError.networkFailure
        }

        lock.lock()
        guard var committed = inviteStates[token], committed.acceptance == nil else {
            lock.unlock()
            throw ScheduleSharingServiceError.revoked
        }
        committed.acceptance = MockAcceptance(
            pairingId: pairingId,
            recipientDisplayName: request.recipientDisplayName,
            recipientSnapshot: recipientSnapshot
        )
        inviteStates[token] = committed
        pairingById[pairingId] = MockPairingState(
            pairingId: pairingId,
            inviterDisplayName: inviterName,
            recipientDisplayName: request.recipientDisplayName,
            inviterSnapshot: inviterSnapshotForPairing,
            recipientSnapshot: recipientSnapshot,
            shareItems: shareItems,
            scope: ShareScope.allMonths
        )
        lock.unlock()

        return AcceptInviteResponse(
            pairingId: pairingId,
            partnerDisplayName: inviterName
        )
    }

    func declineInvite(token: String) async throws {
        try await Task.sleep(nanoseconds: 40_000_000)
    }

    func revokeOutgoingInvite(token: String) async throws {
        try await Task.sleep(nanoseconds: 60_000_000)
        if token.lowercased().contains("networkfail") { throw ScheduleSharingServiceError.networkFailure }
        lock.lock()
        inviteStates.removeValue(forKey: token)
        lock.unlock()
    }

    func revokePairing(pairingId: UUID) async throws {
        try await Task.sleep(nanoseconds: 60_000_000)
        if pairingId.uuidString.lowercased().contains("networkfail") { throw ScheduleSharingServiceError.networkFailure }
        lock.lock()
        pairingById.removeValue(forKey: pairingId)
        for (tok, var st) in inviteStates {
            if st.acceptance?.pairingId == pairingId {
                st.acceptance = nil
                inviteStates[tok] = st
            }
        }
        lock.unlock()
    }

    func fetchPartnerSchedule(pairingId: UUID, month: Date, viewerRole: SchedulePartnershipRole, inviteToken: String?) async throws -> PartnerScheduleSnapshot {
        try await Task.sleep(nanoseconds: 40_000_000)
        lock.lock()
        let local = pairingById[pairingId]
        lock.unlock()

        func partnerBase(from p: MockPairingState) -> PartnerScheduleSnapshot {
            switch viewerRole {
            case .inviter: return p.recipientSnapshot
            case .recipient: return p.inviterSnapshot
            }
        }

        /// Full snapshot: grid keys by `yyyy-MM-dd`; filtering by `month` dropped valid cells when boundaries didn’t match.
        func monthFilteredIfNeeded(_ base: PartnerScheduleSnapshot) -> PartnerScheduleSnapshot {
            ScheduleShareLogging.trace(
                "MockScheduleSharingAPI.fetchPartnerSchedule role=\(String(describing: viewerRole)) monthSkipped=true dayKeys=\(base.days.count)"
            )
            return base
        }

        if let p = local {
            return monthFilteredIfNeeded(partnerBase(from: p))
        }
        if let cached = SchedulePairingFirestoreSync.cachedSnapshots(pairingId: pairingId) {
            let base = viewerRole == .inviter ? cached.recipient : cached.inviter
            return monthFilteredIfNeeded(base)
        }
        if let t = inviteToken {
            await SchedulePairingFirestoreSync.hydrateSnapshotsFromFirestore(inviteToken: t, pairingId: pairingId)
            if let cached = SchedulePairingFirestoreSync.cachedSnapshots(pairingId: pairingId) {
                let base = viewerRole == .inviter ? cached.recipient : cached.inviter
                return monthFilteredIfNeeded(base)
            }
        }
        throw ScheduleSharingServiceError.invalidLink
    }

    func fetchActivePairing(
        outgoingToken: String?,
        knownPairingId: UUID?,
        persistedInviteToken: String?,
        persistedRole: SchedulePartnershipRole?
    ) async throws -> SchedulePartnership? {
        try await Task.sleep(nanoseconds: 40_000_000)
        lock.lock()

        if let ot = outgoingToken, let st = inviteStates[ot], let acc = st.acceptance, let pairing = pairingById[acc.pairingId] {
            let result = SchedulePartnership(
                id: pairing.pairingId,
                pairingId: pairing.pairingId,
                role: .inviter,
                partnerDisplayName: pairing.recipientDisplayName,
                shareItems: pairing.shareItems,
                scope: pairing.scope,
                acceptedAt: Date(),
                inviteToken: ot
            )
            lock.unlock()
            return result
        }

        if let pid = knownPairingId, let pairing = pairingById[pid] {
            let tokenForPairing = inviteStates.first(where: { $0.value.acceptance?.pairingId == pid })?.key
            let result = SchedulePartnership(
                id: pairing.pairingId,
                pairingId: pairing.pairingId,
                role: .recipient,
                partnerDisplayName: pairing.inviterDisplayName,
                shareItems: pairing.shareItems,
                scope: pairing.scope,
                acceptedAt: Date(),
                inviteToken: tokenForPairing
            )
            lock.unlock()
            return result
        }
        lock.unlock()

        if let ot = outgoingToken,
           let remote = await SchedulePairingFirestoreSync.fetchInviterPartnership(outgoingToken: ot) {
            return remote
        }
        if let token = persistedInviteToken,
           let pid = knownPairingId,
           let role = persistedRole,
           let remote = await SchedulePairingFirestoreSync.restorePartnershipFromFirestore(
               inviteToken: token,
               expectedPairingId: pid,
               role: role
           ) {
            return remote
        }

        return nil
    }

    // MARK: - HTTPS URL builder (percent-encoded)

    static func buildHTTPSInviteURL(
        token: String,
        sender: String,
        scope: ShareScope,
        shareItems: [ShareItem],
        expiresAt: Date?
    ) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = ScheduleSharingConfiguration.universalLinkHost
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        components.path = "/" + ScheduleSharingConfiguration.invitePathComponents.joined(separator: "/") + "/" + encodedToken

        var items: [URLQueryItem] = [
            URLQueryItem(name: "sender", value: sender),
            URLQueryItem(name: "scope", value: scope.rawValue),
            URLQueryItem(
                name: "items",
                value: shareItems.map(\.rawValue).joined(separator: ",")
            )
        ]
        if let expiresAt {
            items.append(URLQueryItem(name: "exp", value: ISO8601DateFormatter().string(from: expiresAt)))
        }
        components.queryItems = items
        let url = components.url ?? ScheduleSharingConfiguration.httpsInviteBaseURL
        ScheduleShareLogging.trace(
            "MockScheduleSharingAPI built inviteURL host=\(ScheduleSharingConfiguration.universalLinkHost) token=\(ScheduleShareLogging.redactedTokenDescription(token))"
        )
        return url
    }
}
