import Foundation

public enum ProcessError: Error, Equatable { case exit(Int32) }

public enum ProcessRunner {
    public static func run(_ executable: URL, _ arguments: [String], environment: [String: String] = [:],
                           grace: Duration = .seconds(10)) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let child = Child(executable, arguments, environment, grace)
            continuation.onTermination = { _ in child.stop() }
            child.start(continuation)
        }
    }
}

private final class Child: @unchecked Sendable {
    private let process = Process()
    private let output = Pipe()
    private let errors = Pipe()
    private let lock = NSLock()
    private var splitter = SegmentSplitter()
    private let grace: Duration

    init(_ executable: URL, _ arguments: [String], _ environment: [String: String], _ grace: Duration) {
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = errors
        self.grace = grace
    }

    func start(_ continuation: AsyncThrowingStream<String, Error>.Continuation) {
        let drained = DispatchGroup()
        drained.enter()
        for pipe in [output, errors] {
            drained.enter()
            pipe.fileHandleForReading.readabilityHandler = { [self] handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    handle.readabilityHandler = nil
                    drained.leave()
                    return
                }
                emit(String(decoding: data, as: UTF8.self), continuation)
            }
        }
        process.terminationHandler = { [self] finished in
            let status = finished.terminationStatus
            drained.notify(queue: .global()) { [self] in
                lock.lock()
                let tail = splitter.flush()
                lock.unlock()
                tail.forEach { continuation.yield($0) }
                if status == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(throwing: ProcessError.exit(status))
                }
            }
            drained.leave()
        }
        do {
            try process.run()
            try? output.fileHandleForWriting.close()
            try? errors.fileHandleForWriting.close()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    func stop() {
        guard process.isRunning else { return }
        process.interrupt()
        Task { [self] in
            try? await Task.sleep(for: grace)
            if process.isRunning { process.terminate() }
        }
    }

    private func emit(_ text: String, _ continuation: AsyncThrowingStream<String, Error>.Continuation) {
        lock.lock()
        let segments = splitter.feed(text)
        lock.unlock()
        segments.forEach { continuation.yield($0) }
    }
}

struct SegmentSplitter {
    private var pending = ""

    mutating func feed(_ text: String) -> [String] {
        let parts = (pending + text).split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        pending = parts.last ?? ""
        return parts.dropLast().filter { !$0.isEmpty }
    }

    mutating func flush() -> [String] {
        defer { pending = "" }
        return pending.isEmpty ? [] : [pending]
    }
}
