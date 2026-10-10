import XCTest
@testable import PhoneVaultCore

final class BackupVerifierTests: XCTestCase {
    private func backupDir() throws -> (URL, String) {
        let udid = "U-VERIFY"
        let dir = FileManager.default.temporaryDirectory.appending(path: "pv-verify-\(UUID().uuidString)")
        try makePlainBackup(at: dir, udid: udid)
        return (dir, udid)
    }

    func testValidBackupPasses() throws {
        let (dir, udid) = try backupDir()
        XCTAssertNoThrow(try BackupVerifier.verify(backupDir: dir, udid: udid))
    }

    func testMissingStatusFails() throws {
        let (dir, udid) = try backupDir()
        try FileManager.default.removeItem(at: dir.appending(path: "Status.plist"))
        XCTAssertThrowsError(try BackupVerifier.verify(backupDir: dir, udid: udid)) {
            XCTAssertEqual($0 as? FailureReason, .verificationFailed(missingFiles: ["Status.plist"]))
        }
    }

    func testUnfinishedSnapshotFails() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pv-verify-\(UUID().uuidString)")
        try makePlainBackup(at: dir, udid: "U", status: "incomplete")
        XCTAssertThrowsError(try BackupVerifier.verify(backupDir: dir, udid: "U")) {
            XCTAssertEqual($0 as? FailureReason, .verificationFailed(missingFiles: ["Status.plist"]))
        }
    }

    func testUDIDMismatchFails() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pv-verify-\(UUID().uuidString)")
        try makePlainBackup(at: dir, udid: "U", infoUDID: "OTHER")
        XCTAssertThrowsError(try BackupVerifier.verify(backupDir: dir, udid: "U")) {
            XCTAssertEqual($0 as? FailureReason, .verificationFailed(missingFiles: ["Info.plist"]))
        }
    }

    func testMissingFileListedAsFailure() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pv-verify-\(UUID().uuidString)")
        try makePlainBackup(at: dir, udid: "U", omit: "cc3")
        XCTAssertThrowsError(try BackupVerifier.verify(backupDir: dir, udid: "U")) {
            XCTAssertEqual($0 as? FailureReason, .verificationFailed(missingFiles: ["cc3"]))
        }
    }

    // iOS writes Manifest.db in WAL mode; a read-only open without the -shm file fails on the first query.
    func testWALManifestDatabaseVerifies() throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pv-wal-\(UUID().uuidString)")
        try makePlainBackup(at: dir, udid: "U-WAL")
        XCTAssertEqual(sh("/usr/bin/sqlite3", [dir.appending(path: "Manifest.db").path, "PRAGMA journal_mode=WAL;"]), 0)
        XCTAssertNoThrow(try BackupVerifier.verify(backupDir: dir, udid: "U-WAL"))
    }
}
