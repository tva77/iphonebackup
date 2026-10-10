import XCTest
@testable import PhoneVaultCore

final class FirstBackupTests: XCTestCase {
    func testFirstBackupVerifiesAndPromotes() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        let recorder = Recorder()
        let run = try await h.coordinator().run(udid: h.udid, options: h.options()) { recorder.add($0.state) }
        XCTAssertEqual(run.state, .verified)
        XCTAssertEqual(run.kind, .full)
        XCTAssertEqual(recorder.states, [.validating, .preparing, .backingUp, .verifying, .promoting, .verified])
        XCTAssertTrue(FileManager.default.fileExists(atPath: h.dest.appending(path: h.udid).path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: h.dest.appending(path: ".phonevault/staging").path).isEmpty)
        let saved = try await h.store.load()
        XCTAssertEqual(saved.devices.first?.lastValidBackup?.runID, run.id)
        XCTAssertEqual(saved.runs.count, 1)
    }

    func testVerificationFailureNeverPromotes() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        let run = try await h.coordinator(mode: "verifyMissingFile").run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.state, .failed)
        XCTAssertEqual(run.failure, .verificationFailed(missingFiles: ["cc3"]))
        XCTAssertFalse(FileManager.default.fileExists(atPath: h.dest.appending(path: h.udid).path))
        let saved = try await h.store.load()
        XCTAssertNil(saved.devices.first?.lastValidBackup)
    }

    func testExitZeroWithoutSuccessLineFails() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        let run = try await h.coordinator(mode: "exitZeroButFailed").run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .engineCrashed(1))
        XCTAssertFalse(FileManager.default.fileExists(atPath: h.dest.appending(path: h.udid).path))
    }

    func testPasscodePromptShowsWaitingThenVerifies() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        let recorder = Recorder()
        let run = try await h.coordinator(mode: "passcode").run(udid: h.udid, options: h.options()) { recorder.add($0.state) }
        XCTAssertEqual(run.state, .verified)
        XCTAssertTrue(recorder.states.contains(.waitingForDevice))
    }

    func testCancelOnDeviceIsReported() async throws {
        let h = try Harness()
        try await h.seed(h.device())
        let run = try await h.coordinator(mode: "cancelOnDevice").run(udid: h.udid, options: h.options()) { _ in }
        XCTAssertEqual(run.failure, .cancelledOnDevice)
    }

    func testUntestedIOSWithoutConfirmationWritesNothing() async throws {
        let h = try Harness()
        try await h.seed(h.device(ios: "19.0"))
        let run = try await h.coordinator().run(udid: h.udid, options: h.options(untested: false)) { _ in }
        XCTAssertEqual(run.failure, .untestedIOSNotConfirmed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: h.dest.appending(path: h.udid).path))
        XCTAssertFalse(h.fakeLog().contains("idevicebackup2"))
    }
}

final class TestedIOSVersionsTests: XCTestCase {
    func testMajorVersionsAreMatched() {
        XCTAssertTrue(TestedIOSVersions.isTested("18.1"))
        XCTAssertFalse(TestedIOSVersions.isTested("19.0"))
    }
}
