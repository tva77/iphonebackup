import AppKit
import Foundation

public struct RunProgress: Sendable, Equatable {
    public var percent: Double
    public var bytesPerSecond: Double
    public var eta: TimeInterval?
    public var bytesTransferred: Int64
}

public struct RunUpdate: Sendable, Equatable {
    public var state: RunState
    public var progress: RunProgress
}

public struct RunOptions: Sendable {
    public var confirmUntested: @Sendable () async -> Bool

    public init(confirmUntested: @escaping @Sendable () async -> Bool) {
        self.confirmUntested = confirmUntested
    }
}

public enum CoordinatorError: Error { case busy, deviceNotFound, noVerifiedBackup }

public actor BackupCoordinator {
    private let store: StateStore
    private let engine: DeviceEngine
    private let pollInterval: Duration
    private let notifications: NotificationCenter
    private var running = false
    private var onUpdate: (@Sendable (RunUpdate) -> Void)?
    private var state = RunState.validating
    private var percent = 0.0
    private var rate = TransferRate()
    private var bytes: Int64 = 0
    private var expected: Int64 = 0
    private var writing = false

    public init(store: StateStore, engine: DeviceEngine, pollInterval: Duration = .seconds(2), notifications: NotificationCenter = .default) {
        self.store = store
        self.engine = engine
        self.pollInterval = pollInterval
        self.notifications = notifications
    }

    public func run(udid: String, options: RunOptions, onUpdate: @escaping @Sendable (RunUpdate) -> Void) async throws -> BackupRun {
        guard !running else { throw CoordinatorError.busy }
        running = true
        self.onUpdate = onUpdate
        percent = 0
        bytes = 0
        rate = TransferRate()
        defer {
            running = false
            self.onUpdate = nil
        }

        guard var device = try await store.load().devices.first(where: { $0.udid == udid }) else { throw CoordinatorError.deviceNotFound }
        var run = BackupRun(udid: udid, destinationPath: device.destination?.path ?? "", kind: device.lastValidBackup == nil ? .full : .incremental)
        let power = PowerAssertion()
        defer { power.release() }
        var staging: StagingArea?

        do {
            guard let destination = device.destination else { throw FailureReason.destinationUnavailable }
            let base = device.lastValidBackup?.sizeBytes ?? device.usedBytes
            expected = base
            report(.validating)
            let check = try DestinationValidator.validate(destination.url, base: base, lastValidSize: device.lastValidBackup?.sizeBytes)
            device.destination = Destination(path: destination.path, bookmark: destination.bookmark, kind: check.kind,
                                             fsType: check.fsType, supportsClone: check.supportsClone)
            let area = StagingArea(destination: destination.url, udid: udid)
            staging = area
            try area.reconcile()

            if !TestedIOSVersions.isTested(device.iosVersion) {
                let confirmed = await options.confirmUntested()
                if !confirmed { throw FailureReason.untestedIOSNotConfirmed }
            }
            report(.preparing)
            if device.lastValidBackup != nil {
                try area.prepare(clone: check.supportsClone)
            } else {
                try area.createEmpty()
            }

            report(.backingUp)
            try await supervise(engine.backup(udid: udid, into: area.stagingParent, full: run.kind == .full), progress: .backingUp) {
                try await self.monitor(udid: udid, destination: destination.url, staging: area.stagingURL)
            }
            try Task.checkCancellation()

            report(.verifying)
            try BackupVerifier.verify(backupDir: area.stagingURL, udid: udid)
            report(.promoting)
            try area.promote()
            run.state = .verified
            device.lastValidBackup = ValidBackup(runID: run.id, completedAt: Date(), sizeBytes: StagingArea.size(area.validURL))
        } catch {
            staging?.discard()
            if Task.isCancelled || error is CancellationError {
                run.state = .cancelled
            } else {
                run.state = .failed
                run.failure = await reason(error, udid: udid)
            }
        }

        run.endedAt = Date()
        run.bytesTransferred = bytes
        report(run.state)
        let finished = run
        let updated = device
        try await store.update { state in
            state.runs.append(finished)
            if let index = state.devices.firstIndex(where: { $0.udid == udid }) { state.devices[index] = updated }
        }
        return run
    }

    public func restore(udid: String, options: RunOptions, onUpdate: @escaping @Sendable (RunUpdate) -> Void) async throws -> BackupRun {
        guard !running else { throw CoordinatorError.busy }
        running = true
        self.onUpdate = onUpdate
        percent = 0
        bytes = 0
        writing = false
        rate = TransferRate()
        defer {
            running = false
            self.onUpdate = nil
        }

        guard let device = try await store.load().devices.first(where: { $0.udid == udid }) else { throw CoordinatorError.deviceNotFound }
        guard let destination = device.destination, device.lastValidBackup != nil else { throw CoordinatorError.noVerifiedBackup }
        var run = BackupRun(udid: udid, destinationPath: destination.path, kind: .restore)
        let origin = StagingArea(destination: destination.url, udid: udid).validURL
        let power = PowerAssertion()
        defer { power.release() }
        var before: String?

        do {
            report(.validating)
            guard FileManager.default.fileExists(atPath: destination.url.path) else { throw FailureReason.destinationUnavailable }
            try BackupVerifier.verify(backupDir: origin, udid: udid)
            before = try OriginSnapshot.fingerprint(origin)
            switch try await engine.pairingState(udid: udid) {
            case .paired: break
            case .locked: throw FailureReason.deviceLocked
            case .needsTrust, .denied: throw FailureReason.trustDenied
            }
            if !TestedIOSVersions.isTested(device.iosVersion) {
                guard await options.confirmUntested() else { throw FailureReason.untestedIOSNotConfirmed }
            }
            report(.preparing)
            report(.restoring)
            try await supervise(engine.restore(udid: udid, from: destination.url, copy: false), progress: .restoring) {
                try await self.watchDevice(udid: udid)
            }
            try Task.checkCancellation()
            run.state = .verified
        } catch {
            if Task.isCancelled || error is CancellationError {
                run.state = .cancelled
                run.failure = writing ? .restoreIncomplete : nil
            } else {
                run.state = .failed
                run.failure = await restoreFailure(error, udid: udid)
            }
        }
        if let before, (try? OriginSnapshot.fingerprint(origin)) != before {
            run.state = .failed
            run.failure = .originChanged
        }

        run.endedAt = Date()
        run.bytesTransferred = bytes
        report(run.state)
        let finished = run
        try await store.update { state in state.runs.append(finished) }
        return run
    }

    private func supervise(_ stream: AsyncThrowingStream<EngineEvent, Error>, progress: RunState,
                           watch: @escaping @Sendable () async throws -> Void) async throws {
        let (sleeps, wake) = AsyncStream.makeStream(of: Void.self)
        let token = notifications.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: nil) { _ in wake.yield() }
        defer {
            notifications.removeObserver(token)
            wake.finish()
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await self.consume(stream, progress: progress) }
            group.addTask { try await watch() }
            group.addTask { for await _ in sleeps { throw FailureReason.sleepOrPowerLoss } }
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func watchDevice(udid: String) async throws {
        while true {
            try await Task.sleep(for: pollInterval)
            guard (try? await engine.listDevices())?.contains(udid) == true else { throw FailureReason.deviceDisconnected }
        }
    }

    private func restoreFailure(_ error: Error, udid: String) async -> FailureReason {
        if writing { return .restoreIncomplete }
        let failure = await reason(error, udid: udid)
        if case .engineCrashed = failure { return .restoreRefused }
        return failure
    }

    private func consume(_ stream: AsyncThrowingStream<EngineEvent, Error>, progress: RunState) async throws {
        for try await event in stream {
            switch event {
            case .progress(let value):
                percent = value
                writing = true
                report(progress)
            case .waitingForDevicePasscode:
                report(.waitingForDevice)
            case .finished:
                return
            }
        }
    }

    private func monitor(udid: String, destination: URL, staging: URL) async throws {
        while true {
            try await Task.sleep(for: pollInterval)
            guard (try? await engine.listDevices())?.contains(udid) == true else { throw FailureReason.deviceDisconnected }
            guard FileManager.default.fileExists(atPath: destination.path) else { throw FailureReason.destinationUnavailable }
            bytes = StagingArea.size(staging)
            rate.add(bytes: bytes, at: Date())
            report(state)
        }
    }

    private func report(_ newState: RunState) {
        state = newState
        onUpdate?(RunUpdate(state: newState, progress: snapshot()))
    }

    private func snapshot() -> RunProgress {
        RunProgress(percent: percent, bytesPerSecond: rate.bytesPerSecond,
                    eta: rate.eta(remaining: max(expected - bytes, 0)), bytesTransferred: bytes)
    }

    private func reason(_ error: Error, udid: String) async -> FailureReason {
        if let failure = error as? FailureReason { return failure }
        if !((try? await engine.listDevices()) ?? []).contains(udid) { return .deviceDisconnected }
        if let engineError = error as? EngineError {
            switch engineError {
            case .cancelledOnDevice: return .cancelledOnDevice
            case .failed(let code): return .engineCrashed(code)
            case .protocolMismatch: return .protocolMismatch
            }
        }
        if case .exit(let code)? = error as? ProcessError { return .engineCrashed(code) }
        return .engineCrashed(-1)
    }
}
