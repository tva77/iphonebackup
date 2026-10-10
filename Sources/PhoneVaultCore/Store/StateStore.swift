import Foundation

public actor StateStore {
    private let url: URL

    public init(url: URL = StateStore.defaultURL) { self.url = url }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "PhoneVault/state.json")
    }

    public func load() throws -> AppState {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppState() }
        return try JSONDecoder().decode(AppState.self, from: Data(contentsOf: url))
    }

    public func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }

    public func update(_ body: @Sendable (inout AppState) -> Void) throws {
        var state = try load()
        body(&state)
        try save(state)
    }
}
