import Foundation
import XCTest
@testable import PhoneVaultCore

final class RestoreTests: XCTestCase {
    private func restorable(ios: String? = nil) async throws -> (Harness, String) {
        let h = try Harness()
        let dir = h.dest.appending(path: h.udid)
        try makePlainBackup(at: dir, udid: h.udid)
        var device = h.device(ios: ios)
        device.lastValidBackup = ValidBackup(runID: UUID(), completedAt: Date(), sizeBytes: 1)
        try await h.seed(device)
        return (h, try OriginSnapshot.fingerprint(dir))
    }

    private func assertOriginAndSavedStateIntact(_ h: Harness, before: String) async throws {
        XCTAssertEqual(try OriginSnapshot.fingerprint(h.dest.appending(path: h.udid)), before)
        let saved = try await h.store.load()
        XCTAssertEqual(saved.devices.first?.lastValidBackup?.sizeBytes, 1)
    }

    func testSuccessfulRestoreIsVerifiedAndKeepsOrigin() async throws {
        let (h, before) = try await restorable()
        let run = try await h.coordinator().restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.state, .verified)
        XCTAssertNil(run.failure)
        try await assertOriginAndSavedStateIntact(h, before: before)
    }

    func testExitZeroWithoutSuccessLineIsFailure() async throws {
        let (h, before) = try await restorable()
        let run = try await h.coordinator(mode: "noSuccessLine", delay: 0.05).restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.state, .failed)
        XCTAssertEqual(run.failure, .restoreIncomplete)
        try await assertOriginAndSavedStateIntact(h, before: before)
    }

    func testChangedOriginIsReported() async throws {
        let (h, _) = try await restorable()
        let run = try await h.coordinator(mode: "alter").restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.state, .failed)
        XCTAssertEqual(run.failure, .originChanged)
    }

    func testDisconnectDuringRestoreIsIncomplete() async throws {
        let (h, before) = try await restorable()
        let run = try await h.coordinator(mode: "disconnect", delay: 0.05).restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .restoreIncomplete)
        try await assertOriginAndSavedStateIntact(h, before: before)
    }

    func testCancelDuringRestoreIsIncomplete() async throws {
        let (h, before) = try await restorable()
        let coordinator = h.coordinator(delay: 0.2)
        let task = Task { try await coordinator.restore(udid: h.udid, options: h.options()) { _ in } }
        try await Task.sleep(for: .milliseconds(600))
        task.cancel()
        let run = try await task.value
        XCTAssertEqual(run.state, .cancelled)
        XCTAssertEqual(run.failure, .restoreIncomplete)
        try await assertOriginAndSavedStateIntact(h, before: before)
    }

    func testFindMyRefusalIsReportedWithoutWriting() async throws {
        let (h, _) = try await restorable()
        let run = try await h.coordinator(mode: "refuse").restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .restoreRefused)
    }

    func testProtocolMismatchIsReported() async throws {
        let (h, _) = try await restorable()
        let run = try await h.coordinator(mode: "protocol").restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .protocolMismatch)
    }

    func testRestoreWithoutVerifiedBackupDoesNotCallEngine() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        do {
            _ = try await h.coordinator().restore(udid: h.udid, options: h.options()) { _ in }
            XCTFail("expected noVerifiedBackup")
        } catch {
            XCTAssertEqual(error as? CoordinatorError, .noVerifiedBackup)
        }
        XCTAssertFalse(h.fakeLog().contains("restore"))
    }

    func testLockedIPhoneBlocksBeforeWriting() async throws {
        let (h, _) = try await restorable()
        let run = try await h.coordinator(mode: "locked").restore(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .deviceLocked)
        XCTAssertFalse(h.fakeLog().contains("idevicebackup2"))
    }

    func testUntestedIOSRequiresConfirmation() async throws {
        let (h, _) = try await restorable(ios: "15.0")
        let run = try await h.coordinator().restore(udid: h.udid, options: h.options(untested: false)) { _ in }
        XCTAssertEqual(run.failure, .untestedIOSNotConfirmed)
        XCTAssertFalse(h.fakeLog().contains("idevicebackup2"))
    }

    func testBackupAndRestoreCannotRunTogether() async throws {
        let (h, _) = try await restorable()
        let coordinator = h.coordinator(delay: 0.2)
        let task = Task { try await coordinator.restore(udid: h.udid, options: h.options()) { _ in } }
        try await Task.sleep(for: .milliseconds(300))
        do {
            _ = try await coordinator.run(udid: h.udid, options: h.options()) { _ in }
            XCTFail("expected busy")
        } catch {
            XCTAssertEqual(error as? CoordinatorError, .busy)
        }
        _ = try await task.value
    }
}
