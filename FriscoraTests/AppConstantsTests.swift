import XCTest
@testable import Friscora

/// Run from a Unit Test target that embeds the Friscora app (see README).
final class AppConstantsTests: XCTestCase {
    func testAppStoreIDReadsFromBundleOrPlaceholder() {
        let id = AppConstants.appStoreNumericID
        XCTAssertFalse(id.isEmpty)
    }
}
