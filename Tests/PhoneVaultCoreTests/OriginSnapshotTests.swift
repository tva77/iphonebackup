import Foundation
import XCTest
@testable import PhoneVaultCore

final class OriginSnapshotTests: XCTestCase {
    private func backup() throws -> (Harness, URL) {
        let h = try Harness()
        let dir = h.dest.appending(path: h.udid)
        try makePlainBackup(at: dir, udid: h.udid)
        return (h, dir)
    }

    func testFingerprintIsStableWhenNothingChanges() throws {
        let (_, dir) = try backup()
        XCTAssertEqual(try OriginSnapshot.fingerprint(dir), try OriginSnapshot.fingerprint(dir))
    }

    func testFingerprintChangesWhenAnyFileChanges() throws {
        let (_, dir) = try backup()
        let before = try OriginSnapshot.fingerprint(dir)
        try Data("changed".utf8).write(to: dir.appending(path: "aa/aa1"))
        XCTAssertNotEqual(try OriginSnapshot.fingerprint(dir), before)
    }

    func testFingerprintChangesWhenTopFileContentChangesWithSameSizeAndDate() throws {
        let (_, dir) = try backup()
        let info = dir.appending(path: "Info.plist")
        let before = try OriginSnapshot.fingerprint(dir)
        let date = try info.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        var bytes = try Data(contentsOf: info)
        bytes[bytes.count - 1] ^= 0x01
        try bytes.write(to: info)
        try FileManager.default.setAttributes([.modificationDate: date as Any], ofItemAtPath: info.path)
        XCTAssertNotEqual(try OriginSnapshot.fingerprint(dir), before)
    }
}
