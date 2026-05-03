import XCTest
@testable import Friscora

/// Run from a Unit Test target that embeds the Friscora app (see README).
final class AppConstantsTests: XCTestCase {
    func testAppStoreIDReadsFromBundleOrPlaceholder() {
        let id = AppConstants.appStoreNumericID
        XCTAssertFalse(id.isEmpty)
    }

    func testAuthGracePeriodDefaultIsThreeMinutes() {
        XCTAssertEqual(AppConstants.Security.authGracePeriodSeconds, 180, accuracy: 0.001)
    }

    func testAuthGracePeriodIsWithinSupportedRange() {
        XCTAssertTrue((60...300).contains(Int(AppConstants.Security.authGracePeriodSeconds)))
    }
}
