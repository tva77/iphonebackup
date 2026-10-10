import AppKit
import PhoneVaultCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var connected: [String] = []
    @Published var pairing: [String: PairingState] = [:]
    @Published var selection: String?
    @Published var activeUdid: String?
    @Published var update: RunUpdate?
    @Published var result: BackupRun?
    @Published var untestedPending = false
    @Published var restoring = false

    private let store = StateStore()
    private let engine = LibimobiledeviceEngine()
    private lazy var coordinator = BackupCoordinator(store: store, engine: engine, notifications: NSWorkspace.shared.notificationCenter)
    private var untestedAnswer: CheckedContinuation<Bool, Never>?
    private var runTask: Task<Void, Never>?

    init() {
        Task { await watchDevices() }
    }

    func watchDevices() async {
        await reload()
        for device in devices { if let url = device.destination?.url { try? StagingArea(destination: url, udid: device.udid).reconcile() } }
        for await udids in DeviceMonitor.devices(engine: engine) {
            connected = udids
            pairing = pairing.filter { udids.contains($0.key) }
            for udid in udids where pairing[udid] == nil { await refresh(udid) }
        }
    }

    func retryPairing(_ udid: String) { pairing[udid] = nil }

    func chooseDestination(_ udid: String, url: URL) {
        Task {
            try? await store.update { state in
                guard let index = state.devices.firstIndex(where: { $0.udid == udid }) else { return }
                state.devices[index].destination = Destination(path: url.path, bookmark: try? url.bookmarkData())
            }
            await reload()
        }
    }

    func startBackup(_ udid: String) {
        start(udid, restoring: false) { try await self.coordinator.run(udid: udid, options: $0, onUpdate: $1) }
    }

    func startRestore(_ udid: String) {
        start(udid, restoring: true) { try await self.coordinator.restore(udid: udid, options: $0, onUpdate: $1) }
    }

    private func start(_ udid: String, restoring isRestore: Bool,
                       _ perform: @escaping (RunOptions, @escaping @Sendable (RunUpdate) -> Void) async throws -> BackupRun) {
        activeUdid = udid
        restoring = isRestore
        update = nil
        result = nil
        runTask = Task {
            let options = RunOptions(confirmUntested: { await self.askUntested() })
            if let run = try? await perform(options, { update in Task { @MainActor in self.update = update } }) {
                result = run
            }
            activeUdid = nil
            await reload()
        }
    }

    func cancelBackup() { runTask?.cancel() }

    func answerUntested(_ proceed: Bool) {
        untestedPending = false
        untestedAnswer?.resume(returning: proceed)
        untestedAnswer = nil
    }

    private func askUntested() async -> Bool {
        await withCheckedContinuation { continuation in
            untestedAnswer = continuation
            untestedPending = true
        }
    }

    private func refresh(_ udid: String) async {
        let state = (try? await engine.pairingState(udid: udid)) ?? .needsTrust
        pairing[udid] = state
        guard state == .paired, let info = try? await engine.info(udid: udid) else { return }
        try? await store.update { appState in
            if let index = appState.devices.firstIndex(where: { $0.udid == udid }) {
                appState.devices[index].name = info.name
                appState.devices[index].model = info.model
                appState.devices[index].iosVersion = info.iosVersion
                appState.devices[index].capacityBytes = info.capacityBytes
                appState.devices[index].usedBytes = info.usedBytes
            } else {
                var device = Device(udid: udid, name: info.name, model: info.model, iosVersion: info.iosVersion)
                device.capacityBytes = info.capacityBytes
                device.usedBytes = info.usedBytes
                appState.devices.append(device)
            }
        }
        await reload()
    }

    private func reload() async {
        devices = (try? await store.load())?.devices ?? []
        if selection == nil { selection = devices.first?.udid }
    }
}
