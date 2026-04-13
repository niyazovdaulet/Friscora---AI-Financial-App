import XCTest
@testable import Friscora

@MainActor
final class ScheduleSharingRepositoryTests: XCTestCase {
    func testPersistenceRoundTripPartnership() throws {
        let defaults = UserDefaults(suiteName: "ScheduleSharingRepositoryTests.\(UUID().uuidString)")!

        let api = MockScheduleSharingAPI()
        let repo = ScheduleSharingRepository(api: api, defaults: defaults)
        XCTAssertNil(repo.partnership)

        let p = SchedulePartnership(
            id: UUID(),
            pairingId: UUID(),
            role: .recipient,
            partnerDisplayName: "Jamie",
            shareItems: [.shifts],
            scope: .allMonths,
            acceptedAt: Date(),
            inviteToken: nil
        )
        repo.replacePartnershipForRestore(p)

        let repo2 = ScheduleSharingRepository(api: api, defaults: defaults)
        XCTAssertEqual(repo2.partnership?.partnerDisplayName, "Jamie")
        XCTAssertEqual(repo2.partnership?.role, .recipient)
    }

    func testCannotCreateSecondOutgoingWithoutRevoke() async throws {
        let defaults = UserDefaults(suiteName: "ScheduleSharingRepositoryTests.\(UUID().uuidString)")!
        let api = MockScheduleSharingAPI()
        let repo = ScheduleSharingRepository(api: api, defaults: defaults)

        _ = try await repo.createInvite(
            from: ShareLinkCreateRequest(ownerDisplayName: "A", shareItems: [.shifts], expiresAt: nil)
        )
        do {
            _ = try await repo.createInvite(
                from: ShareLinkCreateRequest(ownerDisplayName: "B", shareItems: [.events], expiresAt: nil)
            )
            XCTFail("expected throw")
        } catch ScheduleSharingServiceError.outgoingInviteAlreadyActive {
            // ok
        } catch {
            XCTFail("wrong error \(error)")
        }
    }

    /// Mock API has no `createInvite` on this “device”; token only exists from another user’s link — accept still succeeds.
    func testMockAcceptInviteSucceedsForTokenCreatedOnAnotherDevice() async throws {
        let defaults = UserDefaults(suiteName: "ScheduleSharingRepositoryTests.\(UUID().uuidString)")!
        let api = MockScheduleSharingAPI()
        let repo = ScheduleSharingRepository(api: api, defaults: defaults)

        let foreignToken = "7c551d1e33a34be5add0d5d5e0a13cd2"
        try await repo.acceptInvite(token: foreignToken, recipientDisplayName: "Recipient")

        XCTAssertEqual(repo.partnership?.role, .recipient)
        XCTAssertNotNil(repo.partnership?.pairingId)
    }
}
