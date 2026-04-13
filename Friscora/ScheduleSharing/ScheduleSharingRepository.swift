//
//  ScheduleSharingRepository.swift
//  Friscora
//
//  Local persistence + API orchestration for schedule sharing (single partner, v2).
//

import Foundation
import Combine

@MainActor
protocol ScheduleSharingRepositoryProtocol: AnyObject, ObservableObject {
    var partnership: SchedulePartnership? { get }
    var outgoingInvite: OutgoingScheduleInvite? { get }

    /// If the other user stopped sharing, refresh leaves this set until consumed.
    func consumePeerEndedSharingNotice() -> String?

    func refreshPairingStatus() async throws
    func createInvite(from draft: ShareLinkCreateRequest) async throws -> ShareLinkCreateResponse
    func revokeOutgoingInvite() async throws
    func resolveInviteToken(_ token: String) async throws -> InviteTokenResolveResponse
    func acceptInvite(token: String, recipientDisplayName: String) async throws
    func declineInvite(token: String) async throws
    func stopSharing() async throws
    func partnerSnapshot(for month: Date) async throws -> PartnerScheduleSnapshot
}

@MainActor
final class ScheduleSharingRepository: ObservableObject, ScheduleSharingRepositoryProtocol {
    static let shared = ScheduleSharingRepository()

    @Published private(set) var partnership: SchedulePartnership?
    @Published private(set) var outgoingInvite: OutgoingScheduleInvite?

    private var pendingPeerEndedPartnerNotice: String?

    private let api: ScheduleSharingAPI
    private let defaults: UserDefaults
    private let partnershipKey = "schedule_sharing_partnership_v2"
    private let outgoingKey = "schedule_sharing_outgoing_v2"

    init(
        api: ScheduleSharingAPI? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        if let api {
            self.api = api
        } else {
            self.api = ScheduleSharingBackendMode.useMockAPI ? MockScheduleSharingAPI.shared : LiveScheduleSharingAPI()
        }
        load()
    }

    func consumePeerEndedSharingNotice() -> String? {
        defer { pendingPeerEndedPartnerNotice = nil }
        return pendingPeerEndedPartnerNotice
    }

    /// Called when Firestore reports the pairing document was deleted while we still had a local partnership.
    func applyRemotePairingDocumentRemoved() {
        guard let p = partnership else { return }
        let name = p.partnerDisplayName
        let pid = p.pairingId
        pendingPeerEndedPartnerNotice = name
        partnership = nil
        persistPartnership()
        Task {
            try? await api.revokePairing(pairingId: pid)
        }
        ScheduleShareLogging.trace("Repository.applyRemotePairingDocumentRemoved partner=\(name)")
    }

    func refreshPairingStatus() async throws {
        ScheduleShareLogging.trace(
            "Repository.refreshPairingStatus outgoingToken=\(outgoingInvite.map { ScheduleShareLogging.redactedTokenDescription($0.token) } ?? "nil") pairingId=\(partnership?.pairingId.uuidString ?? "nil")"
        )
        let remote = try await api.fetchActivePairing(
            outgoingToken: outgoingInvite?.token,
            knownPairingId: partnership?.pairingId,
            persistedInviteToken: partnership?.inviteToken,
            persistedRole: partnership?.role
        )
        if let remote {
            ScheduleShareLogging.trace("Repository.refreshPairingStatus: remote partnership role=\(String(describing: remote.role)) partner=\(remote.partnerDisplayName)")
            partnership = remote
            persistPartnership()
            if remote.role == .inviter {
                outgoingInvite = nil
                persistOutgoing()
            }
        } else {
            ScheduleShareLogging.trace("Repository.refreshPairingStatus: no remote partnership")
            if let p = partnership, let tok = p.inviteToken {
                let status = await SchedulePairingFirestoreSync.pairingDocumentStatus(token: tok)
                if status == .missing {
                    ScheduleShareLogging.trace("Repository.refreshPairingStatus: pairing doc missing — clearing local partnership")
                    pendingPeerEndedPartnerNotice = p.partnerDisplayName
                    partnership = nil
                    persistPartnership()
                    try? await api.revokePairing(pairingId: p.pairingId)
                }
            }
        }
    }

    func createInvite(from draft: ShareLinkCreateRequest) async throws -> ShareLinkCreateResponse {
        ScheduleShareLogging.trace(
            "Repository.createInvite begin owner=\(draft.ownerDisplayName) items=\(draft.shareItems.map(\.rawValue)) useMockAPI=\(ScheduleSharingBackendMode.useMockAPI)"
        )
        guard partnership == nil else {
            ScheduleShareLogging.trace("Repository.createInvite failed: alreadyPaired")
            throw ScheduleSharingServiceError.alreadyPaired
        }
        guard outgoingInvite == nil else {
            ScheduleShareLogging.trace("Repository.createInvite failed: outgoingInviteAlreadyActive")
            throw ScheduleSharingServiceError.outgoingInviteAlreadyActive
        }
        let response = try await api.createInvite(draft)
        ScheduleShareLogging.trace(
            "Repository.createInvite success token=\(ScheduleShareLogging.redactedTokenDescription(response.token)) url=\(response.inviteURL.absoluteString)"
        )
        let outgoing = OutgoingScheduleInvite(
            id: UUID(),
            token: response.token,
            inviteURL: response.inviteURL,
            ownerDisplayName: draft.ownerDisplayName.trimmingCharacters(in: .whitespacesAndNewlines),
            shareItems: response.shareItems,
            expiresAt: response.expiresAt,
            createdAt: Date()
        )
        outgoingInvite = outgoing
        persistOutgoing()
        return response
    }

    func revokeOutgoingInvite() async throws {
        guard let token = outgoingInvite?.token else {
            ScheduleShareLogging.trace("Repository.revokeOutgoingInvite: no outgoing token")
            return
        }
        ScheduleShareLogging.trace("Repository.revokeOutgoingInvite token=\(ScheduleShareLogging.redactedTokenDescription(token))")
        try await api.revokeOutgoingInvite(token: token)
        outgoingInvite = nil
        persistOutgoing()
    }

    func resolveInviteToken(_ token: String) async throws -> InviteTokenResolveResponse {
        try await api.resolveInviteToken(token)
    }

    func acceptInvite(token: String, recipientDisplayName: String) async throws {
        ScheduleShareLogging.trace(
            "Repository.acceptInvite token=\(ScheduleShareLogging.redactedTokenDescription(token)) recipient=\(recipientDisplayName)"
        )
        if let own = outgoingInvite?.token, own == token {
            ScheduleShareLogging.trace("Repository.acceptInvite failed: cannot accept own invite")
            throw ScheduleSharingServiceError.cannotAcceptOwnInvite
        }
        if let p = partnership {
            if p.inviteToken == token {
                if p.role == .inviter {
                    ScheduleShareLogging.trace("Repository.acceptInvite failed: inviter cannot accept own link")
                    throw ScheduleSharingServiceError.cannotAcceptOwnInvite
                }
                ScheduleShareLogging.trace("Repository.acceptInvite failed: invite already accepted")
                throw ScheduleSharingServiceError.inviteAlreadyAccepted
            }
            ScheduleShareLogging.trace("Repository.acceptInvite failed: already paired with someone else")
            throw ScheduleSharingServiceError.alreadyPairedWithDifferentPartner(partnerDisplayName: p.partnerDisplayName)
        }
        let resolved = try await api.resolveInviteToken(token)
        let response = try await api.acceptInvite(
            AcceptInviteRequest(token: token, recipientDisplayName: recipientDisplayName)
        )
        ScheduleShareLogging.trace("Repository.acceptInvite success pairingId=\(response.pairingId) partner=\(response.partnerDisplayName) resolvedItems=\(resolved.shareItems.map(\.rawValue))")
        let p = SchedulePartnership(
            id: response.pairingId,
            pairingId: response.pairingId,
            role: .recipient,
            partnerDisplayName: response.partnerDisplayName,
            shareItems: resolved.shareItems,
            scope: resolved.scope,
            acceptedAt: Date(),
            inviteToken: token
        )
        partnership = p
        persistPartnership()
    }

    func declineInvite(token: String) async throws {
        try await api.declineInvite(token: token)
    }

    func stopSharing() async throws {
        guard let current = partnership else { return }
        let pid = current.pairingId
        if let t = current.inviteToken {
            await SchedulePairingFirestoreSync.deletePairingDocument(token: t)
        }
        try await api.revokePairing(pairingId: pid)
        partnership = nil
        persistPartnership()
    }

    func partnerSnapshot(for month: Date) async throws -> PartnerScheduleSnapshot {
        guard let p = partnership else {
            throw ScheduleSharingServiceError.invalidLink
        }
        if let t = p.inviteToken {
            await SchedulePairingFirestoreSync.reloadSnapshotsFromFirestore(inviteToken: t, pairingId: p.pairingId)
        }
        return try await api.fetchPartnerSchedule(
            pairingId: p.pairingId,
            month: month,
            viewerRole: p.role,
            inviteToken: p.inviteToken
        )
    }

    func replacePartnershipForRestore(_ value: SchedulePartnership?) {
        partnership = value
        persistPartnership()
    }

    func replaceOutgoingForRestore(_ value: OutgoingScheduleInvite?) {
        outgoingInvite = value
        persistOutgoing()
    }

    // MARK: - Persistence

    private func load() {
        if let data = defaults.data(forKey: partnershipKey),
           let p = try? JSONDecoder().decode(SchedulePartnership.self, from: data) {
            partnership = p
        }
        if let data = defaults.data(forKey: outgoingKey),
           let o = try? JSONDecoder().decode(OutgoingScheduleInvite.self, from: data) {
            outgoingInvite = o
        }
    }

    private func persistPartnership() {
        if let partnership {
            if let data = try? JSONEncoder().encode(partnership) {
                defaults.set(data, forKey: partnershipKey)
            }
        } else {
            defaults.removeObject(forKey: partnershipKey)
        }
    }

    private func persistOutgoing() {
        if let outgoingInvite {
            if let data = try? JSONEncoder().encode(outgoingInvite) {
                defaults.set(data, forKey: outgoingKey)
            }
        } else {
            defaults.removeObject(forKey: outgoingKey)
        }
    }
}
