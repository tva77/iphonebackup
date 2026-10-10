import CryptoKit
import Foundation

public enum OriginSnapshot {
    private static let topFiles = ["Info.plist", "Status.plist", "Manifest.plist", "Manifest.db"]

    public static func fingerprint(_ backupDir: URL) throws -> String {
        var hasher = SHA256()
        let root = backupDir.path
        let files = (FileManager.default.enumerator(at: backupDir, includingPropertiesForKeys: [.isRegularFileKey])?
            .compactMap { $0 as? URL } ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .sorted { $0.path < $1.path }
        for file in files {
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            hasher.update(data: Data("\(file.path.dropFirst(root.count)) \(values.fileSize ?? -1) \(values.contentModificationDate?.timeIntervalSince1970 ?? 0)\n".utf8))
        }
        for name in topFiles { hasher.update(data: try Data(contentsOf: backupDir.appending(path: name))) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
