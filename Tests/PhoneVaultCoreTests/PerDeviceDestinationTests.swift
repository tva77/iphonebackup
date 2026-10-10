import XCTest
@testable import PhoneVaultCore

final class PerDeviceDestinationTests: XCTestCase {
    func testEachDeviceWritesOnlyToItsDestination() async throws {
        let h = try Harness()
        let destA = h.root.appending(path: "destA")
        let destB = h.root.appending(path: "destB")
        for d in [destA, destB] { try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true) }
        try await h.seed(h.device(udid: "AAAA-FAKE", dest: destA), h.device(udid: "BBBB-FAKE", dest: destB))

        let a = try await h.coordinator(udid: "AAAA-FAKE").run(udid: "AAAA-FAKE", options: h.options()) { _ in }
        let b = try await h.coordinator(udid: "BBBB-FAKE").run(udid: "BBBB-FAKE", options: h.options()) { _ in }

        XCTAssertEqual(a.state, .verified)
        XCTAssertEqual(b.state, .verified)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destA.appending(path: "AAAA-FAKE").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destA.appending(path: "BBBB-FAKE").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destB.appending(path: "BBBB-FAKE").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destB.appending(path: "AAAA-FAKE").path))
    }
}
