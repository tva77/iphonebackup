import XCTest
@testable import PhoneVaultCore

final class IncrementalBackupTests: XCTestCase {
    func testSecondRunIsIncrementalAndStartsFromValidBackup() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        let first = try await h.coordinator().run(udid: h.udid, options: h.options()) { _ in }
        let second = try await h.coordinator().run(udid: h.udid, options: h.options()) { _ in }

        XCTAssertEqual(first.kind, .full)
        XCTAssertEqual(second.kind, .incremental)
        XCTAssertEqual(second.state, .verified)
        XCTAssertGreaterThan(second.bytesTransferred, 0)

        let backupLines = h.fakeLog().split(separator: "\n").filter { $0.hasPrefix("idevicebackup2") }
        XCTAssertTrue(backupLines[0].contains("--full"))
        XCTAssertFalse(backupLines[1].contains("--full"))
    }
}
