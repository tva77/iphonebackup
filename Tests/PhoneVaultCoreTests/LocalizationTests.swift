import XCTest
@testable import PhoneVaultCore

final class LocalizationTests: XCTestCase {
    private let failureKeys = ["deviceLocked", "trustDenied", "deviceDisconnected", "cancelledOnDevice", "destinationUnavailable",
                               "destinationReadOnly", "insufficientSpace", "unsupportedFileSystem",
                               "untestedIOSNotConfirmed", "sleepOrPowerLoss", "engineCrashed", "verificationFailed",
                               "restoreIncomplete", "restoreRefused", "protocolMismatch", "originChanged"]

    private func strings(_ module: String, _ language: String) throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: "Sources/\(module)/Resources/\(language).lproj/Localizable.strings")
        return try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String] ?? [:]
    }

    private func assertSameKeys(_ module: String) throws {
        let en = try strings(module, "en")
        let pt = try strings(module, "pt")
        XCTAssertFalse(en.isEmpty)
        XCTAssertEqual(Set(en.keys), Set(pt.keys))
        for value in Array(en.values) + Array(pt.values) { XCTAssertFalse(value.isEmpty) }
    }

    func testCoreStringsHaveSameKeysInBothLanguages() throws {
        try assertSameKeys("PhoneVaultCore")
    }

    func testAppStringsHaveSameKeysInBothLanguages() throws {
        try assertSameKeys("PhoneVault")
    }

    func testEveryFailureReasonHasMessages() throws {
        let en = try strings("PhoneVaultCore", "en")
        for key in failureKeys {
            XCTAssertNotNil(en["failure.\(key).cause"], key)
            XCTAssertNotNil(en["failure.\(key).action"], key)
        }
    }

    func testPortugueseBrazilResolvesToBundledTranslation() throws {
        let testBundle = Bundle(for: LocalizationTests.self).bundleURL
        let library = try XCTUnwrap(Bundle(url: testBundle.deletingLastPathComponent().appending(path: "PhoneVault_PhoneVaultCore.bundle")))
        let language = try XCTUnwrap(Bundle.preferredLocalizations(from: library.localizations, forPreferences: ["pt-BR"]).first)
        let translated = try XCTUnwrap(Bundle(path: library.bundlePath + "/\(language).lproj"))
        XCTAssertEqual(translated.localizedString(forKey: "failure.deviceLocked.cause", value: nil, table: "Localizable"), "O iPhone está bloqueado")
        XCTAssertEqual(library.localizedString(forKey: "failure.deviceLocked.cause", value: nil, table: nil), "The iPhone is locked")
    }
}
