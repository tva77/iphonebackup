import CryptoKit
import Foundation
@testable import PhoneVaultCore

struct Harness {
    let root: URL
    let dest: URL
    let state: URL
    let log: URL
    let tools: URL
    let udid: String
    let ios: String
    let store: StateStore

    init(udid: String = "00008110-FAKE", ios: String = "17.5") throws {
        let fm = FileManager.default
        root = fm.temporaryDirectory.appending(path: "pv-\(UUID().uuidString)")
        dest = root.appending(path: "dest")
        state = root.appending(path: "state")
        log = root.appending(path: "fake.log")
        tools = root.appending(path: "tools")
        self.udid = udid
        self.ios = ios
        store = StateStore(url: root.appending(path: "state.json"))
        for dir in [dest, state, tools] { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
        let script = Bundle.module.url(forResource: "fake-engine", withExtension: "sh")!
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        for name in ["idevice_id", "idevicepair", "ideviceinfo", "idevicebackup2"] {
            try fm.createSymbolicLink(at: tools.appending(path: name), withDestinationURL: script)
        }
    }

    func engine(mode: String, udid: String? = nil, delay: Double = 0.02) -> LibimobiledeviceEngine {
        LibimobiledeviceEngine(toolsDirectory: tools, environment: [
            "FAKE_MODE": mode, "FAKE_UDID": udid ?? self.udid, "FAKE_IOS": ios,
            "FAKE_STATE_DIR": state.path, "FAKE_LOG": log.path, "FAKE_DELAY": String(delay),
        ])
    }

    func coordinator(mode: String = "success", delay: Double = 0.02, udid: String? = nil,
                     center: NotificationCenter = NotificationCenter()) -> BackupCoordinator {
        BackupCoordinator(store: store, engine: engine(mode: mode, udid: udid, delay: delay),
                          pollInterval: .milliseconds(200), notifications: center)
    }

    func device(udid: String? = nil, dest: URL? = nil, ios: String? = nil) -> Device {
        var device = Device(udid: udid ?? self.udid, name: "Teste", model: "iPhone10,4", iosVersion: ios ?? self.ios)
        device.destination = Destination(path: (dest ?? self.dest).path)
        return device
    }

    func seed(_ devices: Device...) async throws {
        try await store.update { $0.devices = devices }
    }

    func options(untested: Bool = true) -> RunOptions {
        RunOptions(confirmUntested: { untested })
    }

    func fakeLog() -> String {
        (try? String(contentsOf: log, encoding: .utf8)) ?? ""
    }
}

final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var states: [RunState] = []

    func add(_ state: RunState) {
        lock.lock()
        defer { lock.unlock() }
        if states.last != state { states.append(state) }
    }
}

func treeHash(_ url: URL) throws -> String {
    var hasher = SHA256()
    let root = url.resolvingSymlinksInPath().path
    let files = (FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey])?
        .compactMap { ($0 as? URL)?.resolvingSymlinksInPath() } ?? [])
        .filter { (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
        .sorted { $0.path < $1.path }
    for file in files {
        hasher.update(data: Data(file.path.dropFirst(root.count).utf8))
        hasher.update(data: try Data(contentsOf: file))
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

@discardableResult
func sh(_ executable: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    } catch {
        return -1
    }
}

func makePlainBackup(at dir: URL, udid: String, omit: String? = nil, status: String = "finished", infoUDID: String? = nil) throws {
    let fm = FileManager.default
    for sub in ["aa", "bb", "cc"] { try fm.createDirectory(at: dir.appending(path: sub), withIntermediateDirectories: true) }
    let plists: [(String, [String: Any])] = [
        ("Info.plist", ["Unique Identifier": infoUDID ?? udid]),
        ("Status.plist", ["SnapshotState": status]),
        ("Manifest.plist", [:]),
    ]
    for (name, dict) in plists {
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: dir.appending(path: name))
    }
    sh("/usr/bin/sqlite3", [dir.appending(path: "Manifest.db").path,
        "DROP TABLE IF EXISTS Files; CREATE TABLE Files(fileID TEXT, domain TEXT, relativePath TEXT, flags INTEGER, file BLOB); INSERT INTO Files VALUES('aa1','D','a',1,NULL),('bb2','D','b',1,NULL),('cc3','D','c',1,NULL);"])
    for id in ["aa1", "bb2", "cc3"] where id != omit {
        try Data("x".utf8).write(to: dir.appending(path: String(id.prefix(2))).appending(path: id))
    }
}
