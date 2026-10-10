import XCTest
@testable import PhoneVaultCore

final class DestinationValidatorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appending(path: "pv-dest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempDir.path)
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testMissingFolderIsUnavailable() {
        XCTAssertThrowsError(try DestinationValidator.validate(tempDir.appending(path: "nope"), base: 0, lastValidSize: nil)) {
            XCTAssertEqual($0 as? FailureReason, .destinationUnavailable)
        }
    }

    func testReadOnlyFolderIsRejected() throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: tempDir.path)
        XCTAssertThrowsError(try DestinationValidator.validate(tempDir, base: 0, lastValidSize: nil, cloneProbe: { _ in true })) {
            XCTAssertEqual($0 as? FailureReason, .destinationReadOnly)
        }
    }

    func testRequiredSpaceWithCloneIsOnePointOneBase() {
        XCTAssertThrowsError(try DestinationValidator.validate(tempDir, base: 1000, lastValidSize: 500,
                                                               available: { _ in 100 }, cloneProbe: { _ in true })) {
            XCTAssertEqual($0 as? FailureReason, .insufficientSpace(missingBytes: 1000))
        }
    }

    func testRequiredSpaceWithoutCloneAddsPreviousBackup() {
        XCTAssertThrowsError(try DestinationValidator.validate(tempDir, base: 1000, lastValidSize: 500,
                                                               available: { _ in 1500 }, cloneProbe: { _ in false })) {
            XCTAssertEqual($0 as? FailureReason, .insufficientSpace(missingBytes: 100))
        }
    }

    func testEnoughSpaceAccepted() throws {
        let check = try DestinationValidator.validate(tempDir, base: 1000, lastValidSize: nil,
                                                      available: { _ in 10_000 }, cloneProbe: { _ in true })
        XCTAssertEqual(check.fsType, "apfs")
        XCTAssertTrue(check.supportsClone)
    }

    func testFAT32IsRejected() throws {
        let image = tempDir.appending(path: "fat.dmg")
        guard sh("/usr/bin/hdiutil", ["create", "-size", "64m", "-fs", "MS-DOS", "-volname", "PVFAT", image.path]) == 0,
              sh("/usr/bin/hdiutil", ["attach", "-nobrowse", "-quiet", image.path]) == 0 else {
            throw XCTSkip("hdiutil unavailable")
        }
        defer { sh("/usr/bin/hdiutil", ["detach", "-force", "/Volumes/PVFAT"]) }
        XCTAssertThrowsError(try DestinationValidator.validate(URL(fileURLWithPath: "/Volumes/PVFAT"), base: 0, lastValidSize: nil)) {
            XCTAssertEqual($0 as? FailureReason, .unsupportedFileSystem("msdos"))
        }
    }
}
