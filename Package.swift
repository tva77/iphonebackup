// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PhoneVault",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "PhoneVault", targets: ["PhoneVault"])],
    targets: [
        .target(
            name: "PhoneVaultCore",
            resources: [.process("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "PhoneVault",
            dependencies: ["PhoneVaultCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "PhoneVaultCoreTests",
            dependencies: ["PhoneVaultCore"],
            resources: [.copy("Fixtures"), .copy("fake-engine.sh")]
        ),
    ]
)
