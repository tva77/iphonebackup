import AppKit
import XCTest
@testable import PhoneVaultCore

final class InterruptionTests: XCTestCase {
    private func verifiedHarness() async throws -> (Harness, BackupRun) {
        let h = try Harness()
        try await h.seed(h.device())
        let first = try await h.coordinator().run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(first.state, .verified)
        return (h, first)
    }

    private func assertLastValidIntact(_ h: Harness, _ first: BackupRun, before: String) async throws {
        XCTAssertEqual(try treeHash(h.dest.appending(path: h.udid)), before)
        let saved = try await h.store.load()
        XCTAssertEqual(saved.devices.first?.lastValidBackup?.runID, first.id)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: h.dest.appending(path: ".phonevault/staging").path).isEmpty)
    }

    func testCrashKeepsLastValidBackup() async throws {
        let (h, first) = try await verifiedHarness()
        let before = try treeHash(h.dest.appending(path: h.udid))
        let run = try await h.coordinator(mode: "crash", delay: 0.05).run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .engineCrashed(1))
        try await assertLastValidIntact(h, first, before: before)
    }

    func testDisconnectKeepsLastValidBackup() async throws {
        let (h, first) = try await verifiedHarness()
        let before = try treeHash(h.dest.appending(path: h.udid))
        let run = try await h.coordinator(mode: "disconnect", delay: 0.05).run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .deviceDisconnected)
        try await assertLastValidIntact(h, first, before: before)
    }

    func testUserCancelKeepsLastValidBackup() async throws {
        let (h, first) = try await verifiedHarness()
        let before = try treeHash(h.dest.appending(path: h.udid))
        let coordinator = h.coordinator(mode: "slow", delay: 0.2)
        let task = Task { try await coordinator.run(udid: h.udid, options: h.options()) { _ in } }
        try await Task.sleep(for: .milliseconds(600))
        task.cancel()
        let run = try await task.value
        XCTAssertEqual(run.state, .cancelled)
        try await assertLastValidIntact(h, first, before: before)
    }

    func testDestinationRemovedKeepsLastValidBackup() async throws {
        let (h, first) = try await verifiedHarness()
        let before = try treeHash(h.dest.appending(path: h.udid))
        let away = h.root.appending(path: "away")
        try FileManager.default.moveItem(at: h.dest, to: away)
        defer { try? FileManager.default.moveItem(at: away, to: h.dest) }
        let run = try await h.coordinator().run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .destinationUnavailable)
        try FileManager.default.moveItem(at: away, to: h.dest)
        try await assertLastValidIntact(h, first, before: before)
    }

    func testSleepDuringBackupFailsCleanly() async throws {
        let (h, first) = try await verifiedHarness()
        let before = try treeHash(h.dest.appending(path: h.udid))
        let center = NotificationCenter()
        let coordinator = h.coordinator(mode: "slow", delay: 0.2, center: center)
        let task = Task { try await coordinator.run(udid: h.udid, options: h.options()) { _ in } }
        try await Task.sleep(for: .milliseconds(600))
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        let run = try await task.value
        XCTAssertEqual(run.failure, .sleepOrPowerLoss)
        try await assertLastValidIntact(h, first, before: before)
    }
}
