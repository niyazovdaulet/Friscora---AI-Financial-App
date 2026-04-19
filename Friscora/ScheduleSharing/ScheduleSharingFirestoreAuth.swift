//
//  ScheduleSharingFirestoreAuth.swift
//  Friscora
//
//  Anonymous Firebase Auth for Firestore-backed schedule sharing (see firestore.rules header).
//

import Foundation
import FirebaseAuth

/// Ensures the default Firebase app has a signed-in user before Firestore reads/writes on `schedulePairings`.
/// Uses Firebase Anonymous Auth — capability is still the invite token (document id); auth blocks fully unauthenticated clients and bots without tokens.
actor ScheduleSharingFirestoreAuth {
    static let shared = ScheduleSharingFirestoreAuth()

    func ensureSignedIn() async throws {
        if Auth.auth().currentUser != nil { return }
        _ = try await Auth.auth().signInAnonymously()
    }
}
