import Foundation

public enum PairingState: Sendable, Equatable { case paired, needsTrust, locked, denied }

public struct DeviceInfo: Sendable, Equatable {
    public var name: String
    public var model: String
    public var iosVersion: String
    public var capacityBytes: Int64
    public var usedBytes: Int64
}

public enum EngineEvent: Sendable, Equatable { case progress(percent: Double), waitingForDevicePasscode, finished }

public enum EngineError: Error, Equatable { case cancelledOnDevice, failed(Int32), protocolMismatch }

public protocol DeviceEngine: Sendable {
    func listDevices() async throws -> [String]
    func pairingState(udid: String) async throws -> PairingState
    func pair(udid: String) async throws -> PairingState
    func info(udid: String) async throws -> DeviceInfo
    func backup(udid: String, into parentDir: URL, full: Bool) -> AsyncThrowingStream<EngineEvent, Error>
    func restore(udid: String, from parentDir: URL, copy: Bool) -> AsyncThrowingStream<EngineEvent, Error>
}

public struct LibimobiledeviceEngine: DeviceEngine {
    public let toolsDirectory: URL
    public let environment: [String: String]

    public init(toolsDirectory: URL = LibimobiledeviceEngine.defaultToolsDirectory, environment: [String: String] = [:]) {
        self.toolsDirectory = toolsDirectory
        self.environment = environment
    }

    public static var defaultToolsDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["PHONEVAULT_TOOLS_DIR"] { return URL(fileURLWithPath: custom) }
        let helpers = Bundle.main.bundleURL.appending(path: "Contents/Helpers")
        return FileManager.default.fileExists(atPath: helpers.appending(path: "idevicebackup2").path)
            ? helpers : URL(fileURLWithPath: "/opt/homebrew/bin")
    }

    public func listDevices() async throws -> [String] {
        let (status, output) = await query("idevice_id", ["-l"])
        guard status == 0 else { return [] }
        return output.split(separator: "\n").map(String.init)
    }

    public func pairingState(udid: String) async throws -> PairingState {
        await pairing(["-u", udid, "validate"])
    }

    public func pair(udid: String) async throws -> PairingState {
        await pairing(["-u", udid, "pair"])
    }

    public func info(udid: String) async throws -> DeviceInfo {
        let (status, output) = await query("ideviceinfo", ["-u", udid, "-x"])
        let (_, diskOutput) = await query("ideviceinfo", ["-u", udid, "-x", "-q", "com.apple.disk_usage"])
        guard status == 0, let device = plist(output), let disk = plist(diskOutput) else { throw EngineError.failed(status) }
        let total = number(disk["TotalDataCapacity"])
        return DeviceInfo(
            name: device["DeviceName"] as? String ?? udid,
            model: device["ProductType"] as? String ?? "",
            iosVersion: device["ProductVersion"] as? String ?? "",
            capacityBytes: number(disk["TotalDiskCapacity"]),
            usedBytes: total - number(disk["TotalDataAvailable"]))
    }

    public func backup(udid: String, into parentDir: URL, full: Bool) -> AsyncThrowingStream<EngineEvent, Error> {
        events(["-u", udid, "backup"] + (full ? ["--full"] : []) + [parentDir.path])
    }

    public func restore(udid: String, from parentDir: URL, copy: Bool) -> AsyncThrowingStream<EngineEvent, Error> {
        events(["-u", udid, "restore"] + (copy ? ["--copy"] : []) + [parentDir.path])
    }

    private func events(_ args: [String]) -> AsyncThrowingStream<EngineEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var succeeded = false
                do {
                    for try await line in ProcessRunner.run(toolsDirectory.appending(path: "idevicebackup2"), args, environment: environment) {
                        switch ProgressParser.classify(line) {
                        case .progress(let percent): continuation.yield(.progress(percent: percent))
                        case .waitingForPasscode: continuation.yield(.waitingForDevicePasscode)
                        case .cancelledOnDevice: throw EngineError.cancelledOnDevice
                        case .failed(let code): throw EngineError.failed(code)
                        case .aborted: throw EngineError.failed(-1)
                        case .protocolMismatch: throw EngineError.protocolMismatch
                        case .success: succeeded = true
                        case .other: break
                        }
                    }
                    guard succeeded else { throw EngineError.failed(-1) }
                    continuation.yield(.finished)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func pairing(_ args: [String]) async -> PairingState {
        let (status, output) = await query("idevicepair", args)
        if status == 0 { return .paired }
        let text = output.lowercased()
        if text.contains("passcode") || text.contains("locked") { return .locked }
        if text.contains("denied") { return .denied }
        return .needsTrust
    }

    private func query(_ tool: String, _ args: [String]) async -> (Int32, String) {
        var lines: [String] = []
        var status: Int32 = 0
        do {
            for try await line in ProcessRunner.run(toolsDirectory.appending(path: tool), args, environment: environment) {
                lines.append(line)
            }
        } catch ProcessError.exit(let code) {
            status = code
        } catch {
            status = -1
        }
        return (status, lines.joined(separator: "\n"))
    }

    private func plist(_ text: String) -> [String: Any]? {
        (try? PropertyListSerialization.propertyList(from: Data(text.utf8), format: nil)) as? [String: Any]
    }

    private func number(_ value: Any?) -> Int64 {
        (value as? NSNumber)?.int64Value ?? 0
    }
}
