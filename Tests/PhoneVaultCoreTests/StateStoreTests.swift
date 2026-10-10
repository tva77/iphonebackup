import XCTest
@testable import PhoneVaultCore

final class StateStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "pv-state-\(UUID().uuidString)/state.json")
    }

    func testMissingFileLoadsEmptyState() async throws {
        let store = StateStore(url: tempURL())
        let state = try await store.load()
        XCTAssertEqual(state, AppState())
    }

    func testSaveAndLoadRoundTrip() async throws {
        let store = StateStore(url: tempURL())
        var state = AppState()
        state.devices = [Device(udid: "U1", name: "iPhone", model: "iPhone10,4", iosVersion: "17.5")]
        try await store.save(state)
        let loaded = try await store.load()
        XCTAssertEqual(loaded, state)
    }

    func testStateWrittenBeforeEncryptionRemovalStillLoads() async throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let old = #"{"devices":[{"udid":"U1","name":"iPhone","model":"iPhone10,4","iosVersion":"17.5","capacityBytes":0,"usedBytes":0,"encryption":{"enabled":true,"passwordInKeychain":false},"lastValidBackup":{"runID":"00000000-0000-0000-0000-000000000001","completedAt":700000000,"sizeBytes":5,"encrypted":true}}],"runs":[]}"#
        try Data(old.utf8).write(to: url)
        let loaded = try await StateStore(url: url).load()
        XCTAssertEqual(loaded.devices.first?.lastValidBackup?.sizeBytes, 5)
    }
}
