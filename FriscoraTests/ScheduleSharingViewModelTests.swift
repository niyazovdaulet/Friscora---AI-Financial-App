import XCTest
@testable import Friscora

@MainActor
final class ScheduleSharingViewModelTests: XCTestCase {
    func testValidationRequiresNameAndAtLeastOneShareItem() {
        let suite = UserDefaults(suiteName: "vm.\(UUID().uuidString)")!
        let repo = ScheduleSharingRepository(api: MockScheduleSharingAPI(), defaults: suite)
        let vm = ScheduleSharingViewModel(repository: repo)
        vm.nameInput = " "
        vm.selectedShareItems = []
        XCTAssertFalse(vm.canCreateInvite)

        vm.nameInput = "Alex"
        XCTAssertFalse(vm.canCreateInvite)

        vm.selectedShareItems = [.shifts]
        XCTAssertTrue(vm.canCreateInvite)
    }

    func testContinueButtonEnabledState() {
        let suite = UserDefaults(suiteName: "vm.\(UUID().uuidString)")!
        let repo = ScheduleSharingRepository(api: MockScheduleSharingAPI(), defaults: suite)
        let vm = ScheduleSharingViewModel(repository: repo)
        vm.nameInput = "Jamie"
        XCTAssertFalse(vm.canContinueShareOptions)
        vm.toggleShareItem(.events)
        XCTAssertTrue(vm.canContinueShareOptions)
    }

    func testValidateIncomingInviteBlocksOwnOutgoingToken() {
        let suite = UserDefaults(suiteName: "vm.\(UUID().uuidString)")!
        let repo = ScheduleSharingRepository(api: MockScheduleSharingAPI(), defaults: suite)
        let vm = ScheduleSharingViewModel(repository: repo)
        let tok = "abc123def45678901234567890123456"
        repo.replaceOutgoingForRestore(
            OutgoingScheduleInvite(
                id: UUID(),
                token: tok,
                inviteURL: URL(string: "https://example.com/join/\(tok)")!,
                ownerDisplayName: "Me",
                shareItems: [.shifts],
                expiresAt: nil,
                createdAt: Date()
            )
        )
        let invite = ShareInvitePayload(token: tok, senderName: "Me", scope: .allMonths, shareItems: [.shifts], expiresAt: nil)
        XCTAssertFalse(vm.validateIncomingInvite(invite))
        XCTAssertEqual(vm.linkErrorState, .cannotAcceptOwnInvite)
    }

    func testValidateIncomingInviteAllowsWhenUnpaired() {
        let suite = UserDefaults(suiteName: "vm.\(UUID().uuidString)")!
        let repo = ScheduleSharingRepository(api: MockScheduleSharingAPI(), defaults: suite)
        let vm = ScheduleSharingViewModel(repository: repo)
        let invite = ShareInvitePayload(
            token: "7c551d1e33a34be5add0d5d5e0a13cd2",
            senderName: "A",
            scope: .allMonths,
            shareItems: [.shifts],
            expiresAt: nil
        )
        XCTAssertTrue(vm.validateIncomingInvite(invite))
        XCTAssertNil(vm.linkErrorState)
    }

    func testInviteCardRenderingModelFromApiResponse() {
        let suite = UserDefaults(suiteName: "vm.\(UUID().uuidString)")!
        let repo = ScheduleSharingRepository(api: MockScheduleSharingAPI(), defaults: suite)
        let vm = ScheduleSharingViewModel(repository: repo)
        let response = ShareLinkCreateResponse(
            inviteURL: URL(string: "https://\(ScheduleSharingConfiguration.universalLinkHost)/schedule/join/abc")!,
            token: "abc",
            expiresAt: Date(),
            shareItems: [.shifts, .events],
            joinedCount: 2
        )
        let invite = vm.inviteCardDisplayModel(from: response, ownerName: "Taylor")
        XCTAssertEqual(invite.token, "abc")
        XCTAssertEqual(invite.shareItems, [.shifts, .events])
        XCTAssertEqual(invite.ownerDisplayName, "Taylor")
    }
}
