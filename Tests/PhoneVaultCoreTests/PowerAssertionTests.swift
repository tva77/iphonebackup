import XCTest
@testable import PhoneVaultCore

final class PowerAssertionTests: XCTestCase {
    func testAssertionIsHeldUntilReleased() {
        let assertion = PowerAssertion()
        XCTAssertTrue(assertion.isHeld)
        assertion.release()
        XCTAssertFalse(assertion.isHeld)
    }
}
