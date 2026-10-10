import OSLog

// Paths, device names and UDIDs must be interpolated with privacy: .private.
public enum Log {
    public static let engine = Logger(subsystem: "PhoneVault", category: "engine")
    public static let backup = Logger(subsystem: "PhoneVault", category: "backup")
    public static let destination = Logger(subsystem: "PhoneVault", category: "destination")
}
