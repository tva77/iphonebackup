import Foundation
import XCTest
@testable import PhoneVaultCore

final class ProgressParserTests: XCTestCase {
    func testExtractsPercentFromBarSegment() {
        XCTAssertEqual(ProgressParser.classify("[=====     ] 50%"), .progress(50))
    }

    func testFinishedMeansOneHundredPercent() {
        XCTAssertEqual(ProgressParser.classify("[==========] 100% Finished"), .progress(100))
    }

    func testFinishedAfterPartialPercentIsNotComplete() {
        XCTAssertEqual(ProgressParser.classify("[=         ]   4% Finished"), .progress(4))
    }

    func testClassifiesEngineMessages() {
        XCTAssertEqual(ProgressParser.classify("*** Waiting for passcode to be entered on the device ***"), .waitingForPasscode)
        XCTAssertEqual(ProgressParser.classify("User has cancelled the backup process on the device."), .cancelledOnDevice)
        XCTAssertEqual(ProgressParser.classify("Backup Failed (Error Code 13)."), .failed(13))
        XCTAssertEqual(ProgressParser.classify("Backup Successful."), .success)
    }

    func testClassifiesRestoreMessages() {
        XCTAssertEqual(ProgressParser.classify("Restore Successful."), .success)
        XCTAssertEqual(ProgressParser.classify("Restore Aborted."), .aborted)
        XCTAssertEqual(ProgressParser.classify("Restore Failed (Error Code 211)."), .failed(211))
        XCTAssertEqual(ProgressParser.classify("backup protocol version mismatch"), .protocolMismatch)
    }

    func testIgnoresOtherSegments() {
        XCTAssertEqual(ProgressParser.classify("Receiving files"), .other)
    }

    func testFixtureSegmentsParseInOrder() throws {
        let url = Bundle.module.url(forResource: "idevicebackup2-progress", withExtension: "txt", subdirectory: "Fixtures")!
        let text = try String(contentsOf: url, encoding: .utf8)
        let events = text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline).map { ProgressParser.classify(String($0)) }
        XCTAssertEqual(events.last, .success)
        XCTAssertTrue(events.contains(.progress(1)))
    }

    func testTransferRateIsAverageOverWindow() {
        var rate = TransferRate()
        let start = Date()
        rate.add(bytes: 0, at: start)
        rate.add(bytes: 2000, at: start.addingTimeInterval(20))
        rate.add(bytes: 2500, at: start.addingTimeInterval(25))
        XCTAssertEqual(rate.bytesPerSecond, 100, accuracy: 0.001)
        XCTAssertEqual(rate.eta(remaining: 1000) ?? -1, 10, accuracy: 0.001)
    }

    func testNoEtaWithoutSpeed() {
        XCTAssertNil(TransferRate().eta(remaining: 1000))
    }
}
