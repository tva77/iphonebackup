import XCTest
@testable import PhoneVaultCore

final class LibimobiledeviceEngineTests: XCTestCase {
    func testListsFakeDevice() async throws {
        let h = try Harness()
        let devices = try await h.engine(mode: "success").listDevices()
        XCTAssertEqual(devices, [h.udid])
    }

    func testPairingStateMapping() async throws {
        let h = try Harness()
        let expected: [(String, PairingState)] = [("success", .paired), ("needsTrust", .needsTrust), ("locked", .locked), ("denied", .denied)]
        for (mode, state) in expected {
            let actual = try await h.engine(mode: mode).pairingState(udid: h.udid)
            XCTAssertEqual(actual, state, mode)
        }
    }

    func testInfoParsesDeviceAndDiskUsage() async throws {
        let h = try Harness()
        let info = try await h.engine(mode: "success").info(udid: h.udid)
        XCTAssertEqual(info.name, "Teste")
        XCTAssertEqual(info.model, "iPhone10,4")
        XCTAssertEqual(info.iosVersion, "17.5")
        XCTAssertEqual(info.capacityBytes, 64_000_000_000)
        XCTAssertEqual(info.usedBytes, 59_144_826_880 - 30_570_889_216)
    }
}
