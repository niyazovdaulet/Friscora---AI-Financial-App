import XCTest
@testable import Friscora

final class ScheduleDeepLinkRouterTests: XCTestCase {
    func testHTTPSPathOnlyTokenParses() {
        let host = ScheduleSharingConfiguration.universalLinkHost
        let url = URL(string: "https://\(host)/schedule/join/abc123token")!
        let p = ScheduleDeepLinkRouter.invitePayload(from: url)
        XCTAssertEqual(p?.token, "abc123token")
        XCTAssertEqual(p?.scope, .allMonths)
    }

    func testHTTPSQueryEncodesUnicodeSender() throws {
        var c = URLComponents()
        c.scheme = "https"
        c.host = ScheduleSharingConfiguration.universalLinkHost
        c.path = "/schedule/join/tok1"
        c.queryItems = [
            URLQueryItem(name: "sender", value: "José 北京"),
            URLQueryItem(name: "scope", value: ShareScope.allMonths.rawValue),
            URLQueryItem(name: "items", value: "shifts,events")
        ]
        let url = try XCTUnwrap(c.url)
        let p = ScheduleDeepLinkRouter.invitePayload(from: url)
        XCTAssertEqual(p?.senderName, "José 北京")
        XCTAssertEqual(p?.shareItems, [.shifts, .events])
    }

    func testFriscoraLegacyScheduleShareQuery() {
        let url = URL(string: "friscora://schedule-share?token=xyz&sender=Alex&scope=allMonths&items=shifts")!
        let p = ScheduleDeepLinkRouter.invitePayload(from: url)
        XCTAssertEqual(p?.token, "xyz")
        XCTAssertEqual(p?.senderName, "Alex")
        XCTAssertEqual(p?.shareItems, [.shifts])
    }

    func testFriscoraScheduleJoinPath() {
        let url = URL(string: "friscora://schedule/join/pathonlytok")!
        let p = ScheduleDeepLinkRouter.invitePayload(from: url)
        XCTAssertEqual(p?.token, "pathonlytok")
    }
}
