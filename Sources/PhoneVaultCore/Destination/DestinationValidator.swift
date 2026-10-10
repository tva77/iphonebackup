import Foundation

public struct DestinationCheck: Sendable, Equatable {
    public var fsType: String
    public var kind: DestinationKind
    public var supportsClone: Bool
}

public enum DestinationValidator {
    static let acceptedFileSystems: Set<String> = ["apfs", "hfs", "smbfs", "nfs", "exfat"]

    public static func validate(_ url: URL, base: Int64, lastValidSize: Int64?,
                                available: (URL) -> Int64? = freeSpace,
                                cloneProbe: (URL) -> Bool = StagingArea.probeCloneSupport) throws -> DestinationCheck {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FailureReason.destinationUnavailable
        }
        let fs = fileSystem(url)
        guard acceptedFileSystems.contains(fs) else { throw FailureReason.unsupportedFileSystem(fs) }
        guard StagingArea.isWritable(url) else { throw FailureReason.destinationReadOnly }
        let clone = cloneProbe(url)
        let required = Int64(Double(base) * 1.1) + (clone ? 0 : lastValidSize ?? 0)
        let free = available(url) ?? 0
        guard free >= required else { throw FailureReason.insufficientSpace(missingBytes: required - free) }
        return DestinationCheck(fsType: fs, kind: kind(url), supportsClone: clone)
    }

    public static func freeSpace(_ url: URL) -> Int64? {
        (try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]).volumeAvailableCapacity).map(Int64.init)
    }

    static func fileSystem(_ url: URL) -> String {
        var stats = statfs()
        guard statfs(url.path, &stats) == 0 else { return "unknown" }
        return withUnsafeBytes(of: stats.f_fstypename) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
    }

    static func kind(_ url: URL) -> DestinationKind {
        let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey, .volumeIsRemovableKey, .volumeIsEjectableKey])
        if values?.volumeIsLocal == false { return .network }
        return values?.volumeIsRemovable == true || values?.volumeIsEjectable == true ? .external : .local
    }
}

