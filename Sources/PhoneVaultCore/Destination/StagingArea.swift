import Foundation

public struct StagingArea: Sendable {
    public let destination: URL
    public let udid: String

    public init(destination: URL, udid: String) {
        self.destination = destination
        self.udid = udid
    }

    var root: URL { destination.appending(path: ".phonevault") }
    public var validURL: URL { destination.appending(path: udid) }
    public var stagingParent: URL { root.appending(path: "staging") }
    public var stagingURL: URL { stagingParent.appending(path: udid) }
    var previousURL: URL { root.appending(path: "previous").appending(path: udid) }

    public func createEmpty() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: stagingParent, withIntermediateDirectories: true)
        try? fm.removeItem(at: stagingURL)
    }

    public func prepare(clone: Bool) throws {
        try createEmpty()
        if clone, copyfile(validURL.path, stagingURL.path, nil, copyfile_flags_t(COPYFILE_CLONE | COPYFILE_RECURSIVE)) == 0 { return }
        try? FileManager.default.removeItem(at: stagingURL)
        try FileManager.default.copyItem(at: validURL, to: stagingURL)
    }

    public func reconcile() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: previousURL.path) {
            if fm.fileExists(atPath: validURL.path) {
                try fm.removeItem(at: previousURL)
            } else {
                try fm.moveItem(at: previousURL, to: validURL)
            }
        }
        try? fm.removeItem(at: stagingURL)
    }

    public func promote() throws {
        let fm = FileManager.default
        try? fm.removeItem(at: previousURL)
        if fm.fileExists(atPath: validURL.path) {
            try fm.createDirectory(at: previousURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: validURL, to: previousURL)
        }
        try fm.moveItem(at: stagingURL, to: validURL)
        try? fm.removeItem(at: previousURL)
    }

    public func discard() {
        try? FileManager.default.removeItem(at: stagingURL)
    }

    public static func isWritable(_ destination: URL) -> Bool {
        let probe = destination.appending(path: ".phonevault/write-probe")
        do {
            try FileManager.default.createDirectory(at: probe.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: probe)
            try FileManager.default.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }

    public static func probeCloneSupport(_ destination: URL) -> Bool {
        let fm = FileManager.default
        let dir = destination.appending(path: ".phonevault")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let source = dir.appending(path: "clone-src")
        let target = dir.appending(path: "clone-dst")
        defer {
            try? fm.removeItem(at: source)
            try? fm.removeItem(at: target)
        }
        guard (try? Data("probe".utf8).write(to: source)) != nil else { return false }
        return copyfile(source.path, target.path, nil, copyfile_flags_t(COPYFILE_CLONE_FORCE)) == 0
    }

    public static func size(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else { return 0 }
        return enumerator.compactMap { $0 as? URL }.reduce(0) { total, file in
            total + Int64((try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
        }
    }
}
