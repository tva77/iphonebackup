import XCTest
@testable import PhoneVaultCore

final class ProcessRunnerTests: XCTestCase {
    private let shell = URL(fileURLWithPath: "/bin/sh")

    private func collect(_ script: String, env: [String: String] = [:]) async throws -> [String] {
        var out: [String] = []
        for try await segment in ProcessRunner.run(shell, ["-c", script], environment: env) { out.append(segment) }
        return out
    }

    func testSplitsSegmentsOnCarriageReturnAndNewline() async throws {
        let segments = try await collect("printf 'a\\rb\\nc'")
        XCTAssertEqual(segments, ["a", "b", "c"])
    }

    func testNonZeroExitThrowsExitCode() async {
        do {
            _ = try await collect("exit 3")
            XCTFail("expected ProcessError.exit")
        } catch {
            XCTAssertEqual(error as? ProcessError, .exit(3))
        }
    }

    func testChildReceivesEnvironment() async throws {
        let segments = try await collect("echo $PV_TEST_VALUE", env: ["PV_TEST_VALUE": "v"])
        XCTAssertEqual(segments, ["v"])
    }

    func testCancelInterruptsChild() async throws {
        let stream = ProcessRunner.run(shell, ["-c", "exec sleep 30"])
        let task = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(300))
        let started = Date()
        task.cancel()
        _ = await task.result
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testIgnoredSigintEscalatesToTerminate() async throws {
        let stream = ProcessRunner.run(shell, ["-c", "trap '' INT; exec sleep 30"], grace: .milliseconds(200))
        let task = Task { for try await _ in stream {} }
        try await Task.sleep(for: .milliseconds(300))
        let started = Date()
        task.cancel()
        _ = await task.result
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }
}
