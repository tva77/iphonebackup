# PhoneVault

- Spec Kit project; principles in `.specify/memory/constitution.md`. Active feature: `specs/001-iphone-backup-mvp/` (see `plan.md`).
- Stack: Swift 6.2, one SwiftPM package: `Sources/PhoneVaultCore` (all testable logic) + `Sources/PhoneVault` (SwiftUI app); macOS 13+.
- Backup engine: libimobiledevice 1.4.0 executables as child processes (`brew install libimobiledevice` for development).
- Tests: `swift test`. App bundle: `scripts/make-app.sh` → `.build/PhoneVault.app`.
- Never pass backup passwords as process arguments; never modify `<dest>/<udid>` in place (see `specs/001-iphone-backup-mvp/contracts/`).
