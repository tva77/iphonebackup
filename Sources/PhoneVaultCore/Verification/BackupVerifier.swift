import Foundation
import SQLite3

public enum BackupVerifier {
    public static func verify(backupDir: URL, udid: String) throws {
        guard let info = plist(backupDir.appending(path: "Info.plist")), normalized(info["Unique Identifier"] as? String) == normalized(udid) else {
            throw FailureReason.verificationFailed(missingFiles: ["Info.plist"])
        }
        guard let status = plist(backupDir.appending(path: "Status.plist")), status["SnapshotState"] as? String == "finished" else {
            throw FailureReason.verificationFailed(missingFiles: ["Status.plist"])
        }
        guard plist(backupDir.appending(path: "Manifest.plist")) != nil else {
            throw FailureReason.verificationFailed(missingFiles: ["Manifest.plist"])
        }
        let missing = try fileIDs(backupDir.appending(path: "Manifest.db")).filter { id in
            !FileManager.default.fileExists(atPath: backupDir.appending(path: String(id.prefix(2))).appending(path: id).path)
        }
        guard missing.isEmpty else { throw FailureReason.verificationFailed(missingFiles: missing) }
    }

    // iOS writes the UDID upper-case without dashes; lockdown reports it lower-case.
    private static func normalized(_ udid: String?) -> String {
        (udid ?? "").replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func plist(_ url: URL) -> [String: Any]? {
        (try? Data(contentsOf: url)).flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
    }

    private static func fileIDs(_ url: URL) throws -> [String] {
        let failure = FailureReason.verificationFailed(missingFiles: ["Manifest.db"])
        guard let db = openDatabase(url) else { throw failure }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT fileID FROM Files WHERE flags = 1", -1, &statement, nil) == SQLITE_OK else { throw failure }
        defer { sqlite3_finalize(statement) }
        var ids: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 0) { ids.append(String(cString: text)) }
        }
        return ids
    }

    // Without a -wal file the database is immutable, so reading never touches the backup. A pending
    // -wal (WAL mode, not yet checkpointed) needs read-write access for SQLite to recover it.
    private static func openDatabase(_ url: URL) -> OpaquePointer? {
        let immutable = !FileManager.default.fileExists(atPath: url.path + "-wal")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = immutable ? "immutable=1" : nil
        let flags = SQLITE_OPEN_URI | (immutable ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE)
        var db: OpaquePointer?
        guard let uri = components?.string, sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK else { return nil }
        return db
    }
}
