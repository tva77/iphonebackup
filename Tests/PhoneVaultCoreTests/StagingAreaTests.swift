import XCTest
@testable import PhoneVaultCore

final class StagingAreaTests: XCTestCase {
    private func area() throws -> (StagingArea, URL) {
        let dest = FileManager.default.temporaryDirectory.appending(path: "pv-staging-\(UUID().uuidString)")
        try makePlainBackup(at: dest.appending(path: "U"), udid: "U")
        return (StagingArea(destination: dest, udid: "U"), dest)
    }

    func testCloneAndCopyBothReproduceValidBackup() throws {
        let (staging, _) = try area()
        let valid = try treeHash(staging.validURL)
        try staging.prepare(clone: true)
        XCTAssertEqual(try treeHash(staging.stagingURL), valid)
        try staging.prepare(clone: false)
        XCTAssertEqual(try treeHash(staging.stagingURL), valid)
    }

    func testCloneIsSupportedOnTemporaryAPFSVolume() {
        let dir = FileManager.default.temporaryDirectory.appending(path: "pv-clone-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertTrue(StagingArea.probeCloneSupport(dir))
    }

    func testReconcileRestoresPreviousWhenValidMissing() throws {
        let (staging, _) = try area()
        try FileManager.default.createDirectory(at: staging.previousURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: staging.validURL, to: staging.previousURL)
        try staging.reconcile()
        XCTAssertTrue(FileManager.default.fileExists(atPath: staging.validURL.path))
    }

    func testReconcileDeletesLeftoverStaging() throws {
        let (staging, _) = try area()
        try staging.createEmpty()
        try staging.reconcile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: staging.stagingURL.path))
    }
}
