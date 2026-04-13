//
//  SchedulePairingFirestoreSync.swift
//  Friscora
//
//  Cross-device schedule sharing uses Firestore: inviter uploads a draft snapshot at invite creation;
//  recipient merges their snapshot on accept without overwriting the inviter’s data.
//

import Foundation
import FirebaseFirestore

enum SchedulePairingFirestoreSyncError: Error {
    case inviterSnapshotEncodingFailed
    case recipientSnapshotEncodingFailed
    case snapshotCacheReloadFailed
}

enum SchedulePairingFirestoreSync {
    private static let collectionName = "schedulePairings"
    private static let db = Firestore.firestore()

    private static let cacheLock = NSLock()
    private static var snapshotCache: [UUID: (inviter: PartnerScheduleSnapshot, recipient: PartnerScheduleSnapshot)] = [:]

    private static var pairingListener: ListenerRegistration?
    /// After accept: listens for inviter/recipient snapshot JSON changes (live partner updates).
    private static var pairedSnapshotListener: ListenerRegistration?

    static func cacheSnapshots(pairingId: UUID, inviter: PartnerScheduleSnapshot, recipient: PartnerScheduleSnapshot) {
        cacheLock.lock()
        snapshotCache[pairingId] = (inviter, recipient)
        cacheLock.unlock()
    }

    static func cachedSnapshots(pairingId: UUID) -> (inviter: PartnerScheduleSnapshot, recipient: PartnerScheduleSnapshot)? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return snapshotCache[pairingId]
    }

    /// Inviter device: upload real schedule snapshot when the invite is created (before anyone accepts).
    static func publishInviterInviteDraft(
        token: String,
        inviterDisplayName: String,
        inviterSnapshot: PartnerScheduleSnapshot,
        shareItems: [ShareItem],
        scope: ShareScope
    ) async throws {
        let invData = try JSONEncoder().encode(inviterSnapshot)
        guard let invJSON = String(data: invData, encoding: .utf8) else {
            throw SchedulePairingFirestoreSyncError.inviterSnapshotEncodingFailed
        }
        let data: [String: Any] = [
            "token": token,
            "inviterDisplayName": inviterDisplayName,
            "inviterSnapshotJSON": invJSON,
            "shareItems": shareItems.map(\.rawValue),
            "scope": scope.rawValue,
            "status": "awaiting_recipient",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection(collectionName).document(token).setData(data, merge: true)
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync: inviter draft uploaded token=\(ScheduleShareLogging.redactedTokenDescription(token))")
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync inviter draft failed: \(String(describing: error))")
            throw error
        }
    }

    struct InviterFirestoreDraft: Sendable {
        let name: String
        let snapshot: PartnerScheduleSnapshot
        let shareItems: [ShareItem]
        let scope: ShareScope
    }

    /// Fetches inviter snapshot + name from Firestore (written by inviter at create time). Used on recipient at accept.
    static func fetchInviterDraftFromFirestore(token: String) async -> InviterFirestoreDraft? {
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
            if let result = await fetchInviterDraftOnce(token: token) {
                return result
            }
        }
        return nil
    }

    private static func fetchInviterDraftOnce(token: String) async -> InviterFirestoreDraft? {
        do {
            let doc = try await db.collection(collectionName).document(token).getDocument()
            guard doc.exists, let data = doc.data(),
                  let invJSON = data["inviterSnapshotJSON"] as? String,
                  let invData = invJSON.data(using: .utf8) else { return nil }
            let snap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: invData)
            let name = (data["inviterDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let resolvedName = name.isEmpty ? L10n("schedule.share.resolve.placeholder_sender") : name
            let rawItems = data["shareItems"] as? [String] ?? []
            let shareItems = rawItems.compactMap { ShareItem(rawValue: $0) }
            let items = shareItems.isEmpty ? [.shifts, .events] : shareItems
            let scopeStr = data["scope"] as? String ?? ShareScope.allMonths.rawValue
            let scope = ShareScope(rawValue: scopeStr) ?? .allMonths
            return InviterFirestoreDraft(name: resolvedName, snapshot: snap, shareItems: items, scope: scope)
        } catch {
            return nil
        }
    }

    /// Recipient: merge acceptance fields — must not replace inviterSnapshotJSON from inviter draft.
    static func mergeRecipientAcceptance(
        token: String,
        pairingId: UUID,
        recipientDisplayName: String,
        recipientSnapshot: PartnerScheduleSnapshot,
        shareItems: [ShareItem],
        scope: ShareScope
    ) async throws {
        let recData = try JSONEncoder().encode(recipientSnapshot)
        guard let recJSON = String(data: recData, encoding: .utf8) else {
            throw SchedulePairingFirestoreSyncError.recipientSnapshotEncodingFailed
        }
        let data: [String: Any] = [
            "pairingId": pairingId.uuidString,
            "token": token,
            "recipientDisplayName": recipientDisplayName,
            "recipientSnapshotJSON": recJSON,
            "shareItems": shareItems.map(\.rawValue),
            "scope": scope.rawValue,
            "status": "paired",
            "pairedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection(collectionName).document(token).setData(data, merge: true)
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync mergeRecipient setData failed: \(String(describing: error))")
            throw error
        }
        guard await reloadSnapshotCacheFromDocument(token: token, pairingId: pairingId) else {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync mergeRecipient: reload cache failed after write token=\(ScheduleShareLogging.redactedTokenDescription(token))")
            throw SchedulePairingFirestoreSyncError.snapshotCacheReloadFailed
        }
        ScheduleShareLogging.trace("SchedulePairingFirestoreSync: recipient merged accept token=\(ScheduleShareLogging.redactedTokenDescription(token))")
    }

    /// Loads both snapshots into the process cache. Retries briefly to reduce races right after `setData`.
    private static func reloadSnapshotCacheFromDocument(token: String, pairingId: UUID) async -> Bool {
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            if await reloadSnapshotCacheFromDocumentOnce(token: token, pairingId: pairingId) {
                ScheduleShareLogging.trace(
                    "SchedulePairingFirestoreSync: snapshot cache reloaded pairingId=\(pairingId.uuidString) attempt=\(attempt + 1)"
                )
                return true
            }
        }
        ScheduleShareLogging.trace(
            "SchedulePairingFirestoreSync reloadSnapshotCache: failed after retries token=\(ScheduleShareLogging.redactedTokenDescription(token))"
        )
        return false
    }

    private static func reloadSnapshotCacheFromDocumentOnce(token: String, pairingId: UUID) async -> Bool {
        do {
            let doc = try await db.collection(collectionName).document(token).getDocument()
            guard doc.exists, let data = doc.data(),
                  let invJSON = data["inviterSnapshotJSON"] as? String,
                  let recJSON = data["recipientSnapshotJSON"] as? String,
                  let invD = invJSON.data(using: .utf8),
                  let recD = recJSON.data(using: .utf8) else { return false }
            let inviterSnap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: invD)
            let recipientSnap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: recD)
            cacheSnapshots(pairingId: pairingId, inviter: inviterSnap, recipient: recipientSnap)
            return true
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync reloadSnapshotCacheOnce failed: \(String(describing: error))")
            return false
        }
    }

    /// Inviter: load partnership after recipient merged (document has pairingId + both snapshots).
    static func fetchInviterPartnership(outgoingToken: String) async -> SchedulePartnership? {
        do {
            let doc = try await db.collection(collectionName).document(outgoingToken).getDocument()
            guard doc.exists, let data = doc.data(),
                  let pairingIdStr = data["pairingId"] as? String,
                  let pairingId = UUID(uuidString: pairingIdStr),
                  let recipientName = data["recipientDisplayName"] as? String,
                  let invJSON = data["inviterSnapshotJSON"] as? String,
                  let recJSON = data["recipientSnapshotJSON"] as? String,
                  let invData = invJSON.data(using: .utf8),
                  let recData = recJSON.data(using: .utf8) else {
                return nil
            }
            let inviterSnap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: invData)
            let recipientSnap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: recData)
            let shareRaw = data["shareItems"] as? [String] ?? []
            let shareItems = shareRaw.compactMap { ShareItem(rawValue: $0) }
            let scopeStr = data["scope"] as? String ?? ShareScope.allMonths.rawValue
            let scope = ShareScope(rawValue: scopeStr) ?? .allMonths

            cacheSnapshots(pairingId: pairingId, inviter: inviterSnap, recipient: recipientSnap)

            return SchedulePartnership(
                id: pairingId,
                pairingId: pairingId,
                role: .inviter,
                partnerDisplayName: recipientName,
                shareItems: shareItems.isEmpty ? [.shifts, .events] : shareItems,
                scope: scope,
                acceptedAt: Date(),
                inviteToken: outgoingToken
            )
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync fetchInviterPartnership failed: \(String(describing: error))")
            return nil
        }
    }

    /// When mock in-RAM pairing state is empty (inviter device, relaunch, or stale ID), reload the pairing doc by token + expected id and repopulate the snapshot cache.
    static func restorePartnershipFromFirestore(
        inviteToken: String,
        expectedPairingId: UUID,
        role: SchedulePartnershipRole
    ) async -> SchedulePartnership? {
        do {
            let doc = try await db.collection(collectionName).document(inviteToken).getDocument()
            guard doc.exists, let data = doc.data(),
                  let pairingIdStr = data["pairingId"] as? String,
                  let pairingId = UUID(uuidString: pairingIdStr),
                  pairingId == expectedPairingId,
                  let invJSON = data["inviterSnapshotJSON"] as? String,
                  let recJSON = data["recipientSnapshotJSON"] as? String,
                  let invData = invJSON.data(using: .utf8),
                  let recData = recJSON.data(using: .utf8) else {
                return nil
            }
            let inviterSnap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: invData)
            let recipientSnap = try JSONDecoder().decode(PartnerScheduleSnapshot.self, from: recData)
            let shareRaw = data["shareItems"] as? [String] ?? []
            let shareItems = shareRaw.compactMap { ShareItem(rawValue: $0) }
            let scopeStr = data["scope"] as? String ?? ShareScope.allMonths.rawValue
            let scope = ShareScope(rawValue: scopeStr) ?? .allMonths
            let inviterName = (data["inviterDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let recipientName = (data["recipientDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            cacheSnapshots(pairingId: pairingId, inviter: inviterSnap, recipient: recipientSnap)

            let partnerName: String
            switch role {
            case .inviter:
                partnerName = recipientName.isEmpty ? L10n("schedule.share.partner.fallback_name") : recipientName
            case .recipient:
                partnerName = inviterName.isEmpty ? L10n("schedule.share.partner.fallback_name") : inviterName
            }

            ScheduleShareLogging.trace(
                "SchedulePairingFirestoreSync: restored partnership from Firestore role=\(String(describing: role)) token=\(ScheduleShareLogging.redactedTokenDescription(inviteToken)) inviterDayKeys=\(inviterSnap.days.count) recipientDayKeys=\(recipientSnap.days.count)"
            )

            return SchedulePartnership(
                id: pairingId,
                pairingId: pairingId,
                role: role,
                partnerDisplayName: partnerName,
                shareItems: shareItems.isEmpty ? [.shifts, .events] : shareItems,
                scope: scope,
                acceptedAt: Date(),
                inviteToken: inviteToken
            )
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync restorePartnershipFromFirestore failed: \(String(describing: error))")
            return nil
        }
    }

    static func hydrateSnapshotsFromFirestore(inviteToken: String, pairingId: UUID) async {
        guard cachedSnapshots(pairingId: pairingId) == nil else { return }
        await reloadSnapshotCacheFromDocument(token: inviteToken, pairingId: pairingId)
    }

    /// Always fetch fresh JSON from Firestore into the cache (mock path). Avoids stale/empty cache and skips the “skip if cached” early exit.
    static func reloadSnapshotsFromFirestore(inviteToken: String, pairingId: UUID) async {
        await reloadSnapshotCacheFromDocument(token: inviteToken, pairingId: pairingId)
    }

    static func deletePairingDocument(token: String) async {
        stopListeningForPairedDocumentSnapshotUpdates()
        do {
            try await db.collection(collectionName).document(token).delete()
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync delete failed: \(String(describing: error))")
        }
    }

    /// Writes the current user’s exported schedule into the pairing doc so the partner’s listener picks it up.
    static func publishUpdatedScheduleSnapshot(token: String, role: SchedulePartnershipRole, snapshot: PartnerScheduleSnapshot) async throws {
        let invData = try JSONEncoder().encode(snapshot)
        guard let invJSON = String(data: invData, encoding: .utf8) else {
            throw role == .inviter
                ? SchedulePairingFirestoreSyncError.inviterSnapshotEncodingFailed
                : SchedulePairingFirestoreSyncError.recipientSnapshotEncodingFailed
        }
        let field = role == .inviter ? "inviterSnapshotJSON" : "recipientSnapshotJSON"
        let data: [String: Any] = [
            field: invJSON,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db.collection(collectionName).document(token).setData(data, merge: true)
        ScheduleShareLogging.trace("SchedulePairingFirestoreSync: pushed \(field) token=\(ScheduleShareLogging.redactedTokenDescription(token)) dayKeys=\(snapshot.days.count)")
    }

    enum PairingDocumentStatus: Sendable {
        case exists
        case missing
        case unknown
    }

    /// Used when refreshing local pairing: if the document was deleted, the other user stopped sharing.
    static func pairingDocumentStatus(token: String) async -> PairingDocumentStatus {
        do {
            let doc = try await db.collection(collectionName).document(token).getDocument()
            return doc.exists ? .exists : .missing
        } catch {
            ScheduleShareLogging.trace("SchedulePairingFirestoreSync pairingDocumentStatus failed: \(String(describing: error))")
            return .unknown
        }
    }

    /// `onDocumentRemoved`: pairing doc deleted (e.g. partner tapped Stop sharing).
    static func startListeningForPairedDocumentSnapshotUpdates(
        token: String,
        pairingId: UUID,
        onUpdate: @escaping @Sendable () -> Void,
        onDocumentRemoved: @escaping @Sendable () -> Void
    ) {
        stopListeningForPairedDocumentSnapshotUpdates()
        let docRef = db.collection(collectionName).document(token)
        pairedSnapshotListener = docRef.addSnapshotListener { snapshot, error in
            if error != nil { return }
            if snapshot?.exists != true {
                DispatchQueue.main.async {
                    onDocumentRemoved()
                }
                return
            }
            guard let data = snapshot?.data(),
                  data["pairingId"] is String,
                  data["recipientSnapshotJSON"] is String,
                  data["inviterSnapshotJSON"] is String else { return }
            Task {
                let ok = await reloadSnapshotCacheFromDocument(token: token, pairingId: pairingId)
                if ok {
                    await MainActor.run {
                        onUpdate()
                    }
                }
            }
        }
    }

    static func stopListeningForPairedDocumentSnapshotUpdates() {
        pairedSnapshotListener?.remove()
        pairedSnapshotListener = nil
    }

    // MARK: - Inviter: listen until recipient completes accept (no tab switching required)

    /// Starts a snapshot listener on `schedulePairings/{token}`. When `pairingId` and `recipientSnapshotJSON` appear, invokes `onPaired` on the main actor.
    static func startListeningForRecipientAcceptance(token: String, onPaired: @escaping @Sendable () -> Void) {
        stopListeningForRecipientAcceptance()
        let docRef = db.collection(collectionName).document(token)
        pairingListener = docRef.addSnapshotListener { snapshot, error in
            if error != nil { return }
            guard let data = snapshot?.data(),
                  let pid = data["pairingId"] as? String,
                  !pid.isEmpty,
                  data["recipientSnapshotJSON"] is String else { return }
            DispatchQueue.main.async {
                onPaired()
            }
        }
    }

    static func stopListeningForRecipientAcceptance() {
        pairingListener?.remove()
        pairingListener = nil
    }
}
