import Foundation

public enum DeviceMonitor {
    // shortcut: polling every 2 s, switch to usbmuxd events if CPU cost shows in the prototype
    public static func devices(engine: any DeviceEngine, interval: Duration = .seconds(2)) -> AsyncStream<[String]> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    continuation.yield((try? await engine.listDevices()) ?? [])
                    try? await Task.sleep(for: interval)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

public enum TestedIOSVersions {
    static let majors: [String] = {
        guard let url = Bundle.module.url(forResource: "TestedIOSVersions", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String] else { return [] }
        return list
    }()

    public static func isTested(_ version: String) -> Bool {
        majors.contains(String(version.prefix { $0 != "." }))
    }
}
