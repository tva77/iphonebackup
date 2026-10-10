import Foundation

public enum DestinationKind: String, Codable, Sendable { case local, external, network }

public struct Destination: Codable, Sendable, Equatable {
    public var path: String
    public var bookmark: Data?
    public var kind: DestinationKind
    public var fsType: String?
    public var supportsClone: Bool?

    public init(path: String, bookmark: Data? = nil, kind: DestinationKind = .local, fsType: String? = nil, supportsClone: Bool? = nil) {
        self.path = path
        self.bookmark = bookmark
        self.kind = kind
        self.fsType = fsType
        self.supportsClone = supportsClone
    }

    public var url: URL {
        var stale = false
        if let bookmark, let resolved = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) { return resolved }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}

public struct ValidBackup: Codable, Sendable, Equatable {
    public var runID: UUID
    public var completedAt: Date
    public var sizeBytes: Int64
}

public struct Device: Codable, Sendable, Equatable, Identifiable {
    public var id: String { udid }
    public var udid: String
    public var name: String
    public var model: String
    public var iosVersion: String
    public var capacityBytes: Int64 = 0
    public var usedBytes: Int64 = 0
    public var destination: Destination?
    public var lastValidBackup: ValidBackup?

    public init(udid: String, name: String, model: String, iosVersion: String) {
        self.udid = udid
        self.name = name
        self.model = model
        self.iosVersion = iosVersion
    }
}

public enum RunKind: String, Codable, Sendable { case full, incremental, restore }

public enum RunState: String, Codable, Sendable {
    case validating, preparing, backingUp, waitingForDevice, verifying, promoting, restoring, verified, failed, cancelled
}

public enum FailureReason: Codable, Sendable, Equatable, Error {
    case deviceLocked, trustDenied, deviceDisconnected, cancelledOnDevice
    case destinationUnavailable, destinationReadOnly
    case insufficientSpace(missingBytes: Int64), unsupportedFileSystem(String)
    case untestedIOSNotConfirmed, sleepOrPowerLoss
    case engineCrashed(Int32), verificationFailed(missingFiles: [String])
    case restoreIncomplete, restoreRefused, protocolMismatch, originChanged
}

public struct BackupRun: Codable, Sendable, Identifiable, Equatable {
    public var id = UUID()
    public var udid: String
    public var destinationPath: String
    public var kind: RunKind
    public var startedAt = Date()
    public var endedAt: Date?
    public var bytesTransferred: Int64 = 0
    public var state: RunState = .validating
    public var failure: FailureReason?

    public init(udid: String, destinationPath: String, kind: RunKind) {
        self.udid = udid
        self.destinationPath = destinationPath
        self.kind = kind
    }
}

public struct AppState: Codable, Sendable, Equatable {
    public var devices: [Device] = []
    public var runs: [BackupRun] = []
    public init() {}
}
