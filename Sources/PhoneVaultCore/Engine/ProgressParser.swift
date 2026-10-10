import Foundation

public enum SegmentEvent: Equatable, Sendable {
    case progress(Double), waitingForPasscode, cancelledOnDevice, failed(Int32), success, aborted, protocolMismatch, other
}

public enum ProgressParser {
    public static func classify(_ segment: String) -> SegmentEvent {
        if segment.contains("User has cancelled the backup process on the device.") { return .cancelledOnDevice }
        if let match = segment.firstMatch(of: /(?:Backup|Restore) Failed \(Error Code (-?\d+)\)/), let code = Int32(match.1) { return .failed(code) }
        if segment.contains("Waiting for passcode") { return .waitingForPasscode }
        if segment.firstMatch(of: /(?:Backup|Restore) Successful\./) != nil { return .success }
        if segment.contains("Restore Aborted.") { return .aborted }
        if segment.contains("backup protocol version mismatch") { return .protocolMismatch }
        if let match = segment.firstMatch(of: /\]\s*(\d{1,3})%/), let percent = Double(match.1) { return .progress(percent) }
        return .other
    }
}

public struct TransferRate: Sendable {
    private struct Sample: Sendable { let date: Date; let bytes: Int64 }
    private var samples: [Sample] = []

    public init() {}

    public mutating func add(bytes: Int64, at date: Date) {
        samples.append(Sample(date: date, bytes: bytes))
        samples.removeAll { date.timeIntervalSince($0.date) > 10 }
    }

    public var bytesPerSecond: Double {
        guard let first = samples.first, let last = samples.last, last.date > first.date else { return 0 }
        return Double(last.bytes - first.bytes) / last.date.timeIntervalSince(first.date)
    }

    public func eta(remaining: Int64) -> TimeInterval? {
        let speed = bytesPerSecond
        return speed > 0 ? Double(remaining) / speed : nil
    }
}
