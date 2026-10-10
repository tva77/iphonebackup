---

description: "Task list for MVP de backup completo do iPhone"
---

# Tasks: MVP de backup completo do iPhone para destino escolhido

**Input**: Design documents from `/specs/001-iphone-backup-mvp/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required (constitution IV): success/failure, interruption and last-valid-backup
preservation tests per story, written first and failing before implementation. Real-device and SMB
validation is manual in `quickstart.md`, results recorded in `validation-log.md`.

**Organization**: Tasks grouped by user story. All paths are relative to the repository root
(single SwiftPM package, see plan.md). Logic lives in `Sources/PhoneVaultCore`, UI in
`Sources/PhoneVault`, tests in `Tests/PhoneVaultCoreTests`. Run tests with `swift test`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1–US5 from spec.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Package skeleton that builds and runs an empty test suite

- [X] T001 Create `Package.swift` (swift-tools-version 6.0, `platforms: [.macOS(.v13)]`) with targets: library `PhoneVaultCore` (resources `Resources/TestedIOSVersions.plist` and `Resources/Localizable.strings (en.lproj e pt-BR.lproj)`, `linkerSettings: [.linkedLibrary("sqlite3")]`), executable `PhoneVault` depending on `PhoneVaultCore` (resource `Resources/Localizable.strings (en.lproj e pt-BR.lproj)`), test target `PhoneVaultCoreTests` (resources `Fixtures/` and `fake-engine.sh` via `.copy`); add empty `Sources/PhoneVaultCore/PhoneVaultCore.swift` and `Sources/PhoneVault/PhoneVaultApp.swift` (`@main` SwiftUI `App` with one `WindowGroup` showing `Text("PhoneVault")`) so `swift build` passes
- [X] T002 [P] Create `scripts/make-app.sh` (bash, `set -euo pipefail`): `swift build -c release`, assemble `.build/PhoneVault.app/Contents/{MacOS,Resources,Helpers}`, copy the `PhoneVault` binary and SwiftPM resource bundles, write `Info.plist` (`CFBundleIdentifier` `com.phonevault.app`, `LSMinimumSystemVersion` `13.0`, `CFBundleDevelopmentRegion` `en` so unsupported system languages fall back to English, `CFBundleLocalizations` `[en, pt-BR]`; FR-018); `Helpers` stays empty in the MVP (tools come from Homebrew, see research R1)
- [X] T003 [P] Create `Sources/PhoneVaultCore/Resources/TestedIOSVersions.plist`: array of tested major iOS versions as strings (`16`, `17`, `18`) per research R12
- [X] T004 [P] Create string catalogs `Sources/PhoneVaultCore/Resources/Localizable.strings (en.lproj e pt-BR.lproj)` and `Sources/PhoneVault/Resources/Localizable.strings (en.lproj e pt-BR.lproj)` with source language `en` (serves en-US and is the fallback) and `pt-BR` localization (empty entries; filled by later tasks); set `defaultLocalization: "en"` in `Package.swift` (FR-018)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Models, persistence, process execution and the fake engine every story uses

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 Create Codable models exactly as in `data-model.md` (`Device`, `Destination`, `DestinationKind`, `EncryptionSetting` with `enabled` defaulting to `true`, `BackupRun`, `RunKind`, `RunState`, `FailureReason` with associated values, `ValidBackup`, root `AppState` holding `[Device]` and `[BackupRun]`) in `Sources/PhoneVaultCore/Store/Models.swift`; all types `Sendable`
- [X] T006 [P] Add `FailureReason.message: (cause: String, action: String)` using `String(localized:bundle: .module)` and add pt-BR and en entries for every case to `Sources/PhoneVaultCore/Resources/Localizable.strings (en.lproj e pt-BR.lproj)`, in `Sources/PhoneVaultCore/Backup/FailureReason+Message.swift` (FR-016)
- [X] T007 [P] Write `Tests/PhoneVaultCoreTests/StateStoreTests.swift`: save/load round trip in a temp dir; missing file loads empty `AppState`; written JSON never contains a string passed as a password elsewhere in the test
- [X] T008 Implement `StateStore` (actor) in `Sources/PhoneVaultCore/Store/StateStore.swift`: file URL injectable, default `~/Library/Application Support/PhoneVault/state.json`; `load()`, `save(_:)` via `JSONEncoder` + `Data.write(options: .atomic)`; creates the directory (research R11)
- [X] T009 [P] Implement `Log` in `Sources/PhoneVaultCore/System/Log.swift`: `os.Logger(subsystem: "PhoneVault", category:)` instances for `engine`, `backup`, `destination`; document in a one-line comment that paths, device names and UDIDs MUST be interpolated with `privacy: .private` (research R10)
- [X] T010 [P] Write `Tests/PhoneVaultCoreTests/ProcessRunnerTests.swift` using `/bin/sh -c`: streams stdout and stderr segments in order, splitting on both `\r` and `\n` (e.g. `printf 'a\rb\nc'` yields `a`, `b`, `c`); returns exit code; passes `environment` only to the child (the test process env is unchanged); cancel sends SIGINT then SIGTERM after a configurable grace (use 0.2 s in tests) for a process that traps SIGINT
- [X] T011 Implement `ProcessRunner` in `Sources/PhoneVaultCore/Engine/ProcessRunner.swift` on `Foundation.Process` + `Pipe`: `run(executable:arguments:environment:) -> AsyncThrowingStream<String, Error>` of stdout+stderr segments split on `\r` or `\n` (empty segments dropped), `environment` merged into the child's inherited environment only, final exit code check (non-zero → `ProcessError.exit(code)`), cancellation on stream termination with SIGINT, grace (default 10 s), SIGTERM (contract backup-engine.md)
- [X] T012 Create `Sources/PhoneVaultCore/Engine/DeviceEngine.swift` with the `DeviceEngine` protocol, `PairingState`, `DeviceInfo` (name, model, iosVersion, capacityBytes, usedBytes) and `EngineEvent` exactly as in `contracts/backup-engine.md`, plus `LibimobiledeviceEngine` struct with `toolsDirectory: URL` (default: `Bundle.main` `Contents/Helpers` if it contains `idevicebackup2`, else `/opt/homebrew/bin`; overridable by env `PHONEVAULT_TOOLS_DIR`) and method stubs that `fatalError("unimplemented")`
- [X] T013 Create fake engine `Tests/PhoneVaultCoreTests/fake-engine.sh` (bash): dispatches on `basename "$0"` (`idevice_id`, `idevicepair`, `ideviceinfo`, `idevicebackup2`); behaviour from env `FAKE_MODE` (`success`, `crash`, `disconnect`, `slow`, `locked`, `denied`, `needsTrust`, `verifyMissingFile`, `passcode`, `cancelOnDevice`, `exitZeroButFailed`, `wrongPassword`), `FAKE_UDID` (default `00008110-FAKE`) and `FAKE_STATE_DIR` (per-test dir for marker files); appends its argv and whether `BACKUP_PASSWORD` is `set`/`unset` (never its value) to `$FAKE_LOG`; `ideviceinfo -x` prints a plist XML; `idevicebackup2 ... backup [--full] <dir>` mimics the real 1.4.0 output of `Fixtures/idevicebackup2-progress.txt` (progress bar redrawn with `\r` and no `\n`, then ` Finished\n`, then `Backup Successful.\n`), writing the minimal backup into `<dir>/$FAKE_UDID` gradually while progressing (Info.plist, Manifest.plist, Status.plist with `SnapshotState=finished`, `Manifest.db` built with `/usr/bin/sqlite3` with table `Files(fileID, domain, relativePath, flags, file)` and 3 files in `<xx>/<fileID>`); `crash` exits 1 after half the progress; `disconnect` makes later `idevice_id -l` print nothing (marker in `$FAKE_STATE_DIR`); `verifyMissingFile` omits one listed file; `passcode` prints `*** Waiting for passcode to be entered on the device ***` at 10% then continues; `cancelOnDevice` prints `User has cancelled the backup process on the device.` and exits 1; `exitZeroButFailed` prints `Backup Failed (Error Code 1).` and exits 0; `wrongPassword` prints an `ERROR` line containing `password` and exits 1
- [X] T014 Create `Tests/PhoneVaultCoreTests/Support/TestSupport.swift`: `makeTempDir()`, `makeFakeToolsDir(mode:)` (temp dir with its own `FAKE_STATE_DIR` and symlinks `idevice_id`, `idevicepair`, `ideviceinfo`, `idevicebackup2` → bundled `fake-engine.sh`, `chmod +x`), `treeHash(_ url:)` (SHA-256 over sorted relative paths + file contents via CryptoKit) used to prove a backup was untouched

**Checkpoint**: `swift test` runs StateStore and ProcessRunner tests green

---

## Phase 3: User Story 1 - Primeiro backup completo em pasta escolhida (Priority: P1) 🎯 MVP

**Goal**: Pair a cabled iPhone, choose a folder, run a full backup with progress and see "verificado"

**Independent Test**: With the fake engine (`FAKE_MODE=success`) and an empty temp folder, run the coordinator: `<dest>/<udid>` exists, staging is gone, run state is `verified`; manually, quickstart step 1 on a real iPhone

### Tests for User Story 1 (required for backup flows)

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [X] T015 [P] [US1] Add `Tests/PhoneVaultCoreTests/Fixtures/idevicebackup2-progress.txt` with sample `idevicebackup2` 1.4.0 output (until captured from a real device in T065: `Full backup mode.`, `Receiving files`, bar segments like `[=====          ]  35%` separated by `\r`, ` Finished`, `Received N files from device.`, `Backup Successful.`) and write `Tests/PhoneVaultCoreTests/ProgressParserTests.swift`: classifies segments per the "Saída do backup" table of `contracts/backup-engine.md` (percent from `] NN%`, ` Finished` → 100, `Waiting for passcode` → waiting, `User has cancelled…` → `cancelledOnDevice`, `Backup Failed (Error Code N).` → `engineCrashed(N)`, `ERROR` with `password` → `wrongPassword`, `Backup Successful.` → success flag), ignores other segments; `TransferRate` fed with injected `(Date, bytes)` folder-size samples gives a 10 s moving average, ETA = (estimated base − bytes) / speed, nil ETA when speed is 0
- [X] T016 [P] [US1] Write `Tests/PhoneVaultCoreTests/BackupVerifierTests.swift` against backups produced by `fake-engine.sh`: valid backup passes; missing `Status.plist`, `SnapshotState != "finished"`, UDID mismatch in `Info.plist`, and a `Files` row with `flags == 1` whose `<xx>/<fileID>` is missing each fail with `verificationFailed`
- [X] T017 [P] [US1] Write `Tests/PhoneVaultCoreTests/LibimobiledeviceEngineTests.swift` with `makeFakeToolsDir`: `listDevices` returns `FAKE_UDID`; `pairingState` maps `success`/`needsTrust`/`locked`/`denied`; `info` parses name, model, iOS version, capacity and used bytes from `ideviceinfo -x` plist output
- [X] T018 [P] [US1] Write `Tests/PhoneVaultCoreTests/TestedIOSVersionsTests.swift`: `18.1` is tested, `19.0` is not; coordinator with an untested version and `confirmUntested` returning `false` ends `failed(untestedIOSNotConfirmed)` and writes nothing to the destination (FR-017)
- [X] T019 [US1] Write `Tests/PhoneVaultCoreTests/FirstBackupTests.swift` for `BackupCoordinator` with the fake engine: `success` → states `validating, preparing, backingUp, verifying, promoting, verified` in order, `<dest>/<udid>` exists, `.phonevault/staging` is empty, run kind `full`, `Device.lastValidBackup` set and persisted; `verifyMissingFile` → `failed(verificationFailed)`, no `<dest>/<udid>`, no `lastValidBackup`; `exitZeroButFailed` → `failed(engineCrashed)`, nothing promoted; `passcode` → a `waitingForDevice` update appears, then the run reaches `verified`; `cancelOnDevice` → `failed(cancelledOnDevice)`, nothing promoted; `bytesTransferred` > 0 comes from staging growth

### Implementation for User Story 1

- [X] T020 [P] [US1] Implement `ProgressParser` (segment classification per `contracts/backup-engine.md`) and `TransferRate` (fed by `(Date, bytes)` folder-size samples; moving average, ETA) in `Sources/PhoneVaultCore/Engine/ProgressParser.swift` (research R8)
- [X] T021 [P] [US1] Implement `TestedIOSVersions.isTested(_ version:)` reading the bundled plist by major version in `Sources/PhoneVaultCore/Engine/TestedIOSVersions.swift`
- [X] T022 [US1] Implement `LibimobiledeviceEngine.listDevices`, `pairingState`, `pair`, `info` (`ideviceinfo -u <udid> -x` and `-x -q com.apple.disk_usage` parsed with `PropertyListSerialization`: `DeviceName`, `ProductType`, `ProductVersion`, `TotalDiskCapacity`, used = `TotalDataCapacity - TotalDataAvailable`; called once per connection because the disk query takes >10 s) and map `idevicepair` failures containing "passcode"/"locked" → `.locked`, "denied"/"user denied" → `.denied`, "trust"/"not paired" → `.needsTrust`, in `Sources/PhoneVaultCore/Engine/LibimobiledeviceEngine.swift` (research R7)
- [X] T023 [US1] Implement `LibimobiledeviceEngine.backup` (no password yet) as `idevicebackup2 -u <udid> backup [--full] <parentDir>` (no `-i`) through `ProcessRunner`, emitting `.progress` and `.waitingForDevicePasscode` via `ProgressParser`, throwing `cancelledOnDevice`/`engineCrashed(N)` for the matching segments, and emitting `.finished` only on exit 0 **and** a seen `Backup Successful.` (otherwise `engineCrashed(exitCode)`), in `Sources/PhoneVaultCore/Engine/LibimobiledeviceEngine.swift`
- [X] T024 [P] [US1] Implement `DeviceMonitor` polling only `listDevices()` (never `info`) every 2 s into an `AsyncStream<[String]>` in `Sources/PhoneVaultCore/Engine/DeviceMonitor.swift` with comment `// shortcut: polling every 2 s, switch to usbmuxd events if CPU cost shows in the prototype`
- [X] T025 [US1] Implement `BackupVerifier.verify(backupDir:udid:)` for unencrypted backups (plists via `PropertyListSerialization`, `Manifest.db` via `SQLite3` C API, read-only) returning `.verified` or `FailureReason.verificationFailed(missingFiles:)`, in `Sources/PhoneVaultCore/Verification/BackupVerifier.swift` (research R5)
- [X] T026 [US1] Implement `StagingArea(destination:udid:)` in `Sources/PhoneVaultCore/Destination/StagingArea.swift` with the paths of `contracts/destination-layout.md`: `validURL`, `stagingParent`, `stagingURL`, `previousURL`; `createEmpty()`, `discard()`, `promote()` (`rename(valid → previous)` if valid exists, `rename(staging → valid)`, delete previous)
- [X] T027 [US1] Implement `BackupCoordinator` (actor) in `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift`: `start(device:confirmUntested:) -> AsyncStream<RunUpdate>` where `RunUpdate` carries `RunState`, percent, bytes/s, ETA; flow: validating (destination exists and is writable; full validation in US3) → untested iOS check via `confirmUntested` → preparing (`createEmpty` when no valid backup) → backingUp (`full: true` when no valid backup; `.waitingForDevicePasscode` → `waitingForDevice` until the next progress; sample the staging folder size every 2 s into `TransferRate` for bytes/s, ETA and `bytesTransferred`) → verifying → promoting → verified; saves `BackupRun` and `lastValidBackup` through `StateStore`; any error → `failed(reason)` and `StagingArea.discard()`; one run at a time (second `start` while running throws)
- [X] T028 [US1] Create `AppModel` (`@MainActor final class`, `ObservableObject`) in `Sources/PhoneVault/AppModel.swift`: loads `StateStore`, subscribes to `DeviceMonitor`, refreshes pairing state and `DeviceInfo`, exposes devices, current run updates, `startBackup(udid:)`, `chooseDestination(udid:url:)` (stores path + `url.bookmarkData()`), and asks untested-iOS confirmation through a published alert flag
- [X] T029 [P] [US1] Create `Sources/PhoneVault/Views/PairingView.swift`: guidance per `PairingState` (unlock iPhone, tap "Confiar", enter passcode; denied → how to retry) with a "Tentar novamente" button calling `pair`; FR-002
- [X] T030 [P] [US1] Create `Sources/PhoneVault/Views/DeviceListView.swift`: list of devices with name, model, iOS, capacity/used, last backup state (andamento/falhou/verificado + date + destination, FR-014) and "Fazer backup agora" button (disabled without destination or while a run is active)
- [X] T031 [P] [US1] Create `Sources/PhoneVault/Views/DeviceDetailView.swift`: shows device data and destination; "Escolher pasta…" via `.fileImporter(allowedContentTypes: [.folder])` calling `AppModel.chooseDestination` (FR-003)
- [X] T032 [P] [US1] Create `Sources/PhoneVault/Views/BackupProgressView.swift`: `ProgressView` with percent, speed, ETA, current state label, "Cancelar" button; in `waitingForDevice` shows "Digite o código no iPhone" (US1 scenario 5); final result shows "Verificado" or the `FailureReason.message` cause and action; never shows success before `verified` (FR-006, FR-013)
- [X] T033 [US1] (ajustada) `OnboardingView.swift` mostra o estado sem dispositivo (conexão e pareamento) como tela vazia de `MainView`; etapas de destino e primeiro backup ficam em `DeviceDetailView`, sem assistente separado. A confirmação de iOS não testado fica em `MainView`.
- [X] T034 [US1] Add pt-BR and en strings for every user-facing text of T029–T033 to `Sources/PhoneVault/Resources/Localizable.strings (en.lproj e pt-BR.lproj)`

**Checkpoint**: US1 tests green; app builds with `scripts/make-app.sh`; first backup works with the fake engine

---

## Phase 4: User Story 2 - Backup não destrói o último backup válido (Priority: P1)

**Goal**: Every failure or cancel leaves the last verified backup intact; new runs start from a clone/copy of it

**Independent Test**: With a verified backup at `<dest>/<udid>`, run the coordinator with `crash`, `disconnect`, cancel and destination removal: `treeHash` of `<dest>/<udid>` unchanged and `lastValidBackup` unchanged; manually, quickstart steps 3, 4 and 6

### Tests for User Story 2 (required for backup flows)

- [X] T035 [P] [US2] Write `Tests/PhoneVaultCoreTests/StagingAreaTests.swift`: `prepare(fromValid:)` produces a staging tree with the same `treeHash` as valid; `probeCloneSupport()` is `true` on the temp dir (APFS); with cloning forced off the fallback copy is used and produces the same tree; `reconcile()` with valid missing and previous present renames previous back; `reconcile()` deletes leftover staging
- [X] T036 [US2] Write `Tests/PhoneVaultCoreTests/InterruptionTests.swift`: starting from a verified backup, each of `crash`, `disconnect`, user cancel (cancel the stream at 50%), and deleting the destination folder mid-run ends in `failed(engineCrashed)`, `failed(deviceDisconnected)`, `cancelled`, `failed(destinationUnavailable)` respectively, and posting `NSWorkspace.willSleepNotification` on an injected `NotificationCenter` mid-run ends `failed(sleepOrPowerLoss)`; in all cases `treeHash(<dest>/<udid>)` is unchanged, staging is gone, `lastValidBackup` is unchanged, and nothing is written outside `<dest>`
- [X] T037 [P] [US2] Write `Tests/PhoneVaultCoreTests/PowerAssertionTests.swift`: `PowerAssertion` acquires an assertion id and releases it on `release()` and on deinit (check via `IOPMCopyAssertionsByProcess`)

### Implementation for User Story 2

- [X] T038 [US2] Add to `Sources/PhoneVaultCore/Destination/StagingArea.swift`: `probeCloneSupport()` (create a probe file in `.phonevault/`, try `copyfile(src, dst, nil, COPYFILE_CLONE_FORCE)`, delete both), `prepare(fromValid:)` using `copyfile(..., COPYFILE_CLONE | COPYFILE_RECURSIVE)` when supported else `FileManager.copyItem`, and `reconcile()` per `contracts/destination-layout.md` (research R3)
- [X] T039 [P] [US2] Implement `PowerAssertion` in `Sources/PhoneVaultCore/System/PowerAssertion.swift` with `IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep, ..., "PhoneVault backup")` and release (research R9, FR-009)
- [X] T040 [US2] Update `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift`: call `reconcile()` before validating; in preparing use `prepare(fromValid:)` when a valid backup exists; hold `PowerAssertion` from preparing to the end; watch `DeviceMonitor` and fail with `deviceDisconnected` when the UDID disappears; check destination reachability every 5 s and fail with `destinationUnavailable`; observe `willSleepNotification` on an injectable `NotificationCenter` (default `NSWorkspace.shared.notificationCenter`), cancel the engine and fail with `sleepOrPowerLoss`; map stream cancellation to `cancelled`, non-zero exit to `engineCrashed(exitCode)`; always `discard()` staging on non-verified end; never touch `validURL` except inside `promote()`; on failure after interruption, the message says a new backup is needed (research R4, FR-008)
- [X] T041 [US2] Call `StagingArea.reconcile()` for every configured destination at launch in `Sources/PhoneVault/AppModel.swift`
- [X] T042 [US2] Update `Sources/PhoneVault/Views/BackupProgressView.swift`: cancel asks for confirmation and, after cancel/failure, states that the previous backup (date) was kept; add strings to `Sources/PhoneVault/Resources/Localizable.strings (en.lproj e pt-BR.lproj)`

**Checkpoint**: US1 and US2 tests green; interruptions never alter the valid backup

---

## Phase 5: User Story 3 - Validação do destino antes de começar (Priority: P2)

**Goal**: Block before writing when the destination is missing, read-only, unsupported or too small, with cause and action

**Independent Test**: `DestinationValidator` against temp dirs and disk images rejects each invalid case and the coordinator writes nothing; manually, quickstart automated table rows for destinations

### Tests for User Story 3 (required for backup flows)

- [X] T043 [P] [US3] Write `Tests/PhoneVaultCoreTests/DestinationValidatorTests.swift`: missing folder → `destinationUnavailable`; folder with `chmod 0555` → `destinationReadOnly`; FAT32 image (`hdiutil create -size 64m -fs MS-DOS -volname PVFAT -attach`, detach in teardown; skip if `hdiutil` fails) → `unsupportedFileSystem("msdos")`; injected capacity below requirement → `insufficientSpace(missingBytes)` with exact missing bytes; required space = `1.1 × base` with clone and `1.1 × base + validSize` without clone, base = last valid size or device used bytes
- [X] T044 [P] [US3] Write `Tests/PhoneVaultCoreTests/PerDeviceDestinationTests.swift`: two fake devices (`FAKE_UDID` per run) with different destinations each get their backup only in their own destination

### Implementation for User Story 3

- [X] T045 [US3] Implement `DestinationValidator.validate(destination:device:lastValidSize:supportsClone:) -> Result<ValidatedDestination, FailureReason>` in `Sources/PhoneVaultCore/Destination/DestinationValidator.swift`: resolve bookmark (fallback to path), exists + is directory, write probe file in `.phonevault/`, `statfs` `f_fstypename` (accept `apfs`, `hfs`, `smbfs`, `nfs`, `exfat`; reject `msdos` and others), `volumeAvailableCapacity` through an injectable `capacityProvider`, required space formula from research R6, `DestinationKind` from `volumeIsLocal` / `volumeIsRemovable`
- [X] T046 [US3] Use `DestinationValidator` in the validating state of `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift` (store `supportsClone` and `fsType` in `Destination`), replacing the minimal US1 check
- [X] T047 [US3] Show in `Sources/PhoneVault/Views/DeviceDetailView.swift` the validation result for the chosen destination (type, required vs available space, extra copy needed when no clone) and block "Fazer backup agora" with the failure cause and action; add strings to `Sources/PhoneVault/Resources/Localizable.strings (en.lproj e pt-BR.lproj)`

**Checkpoint**: invalid destinations never receive data

---

## Phase 6: User Story 4 - Backup incremental rápido (Priority: P2)

**Goal**: Later runs transfer only changes and finish fast

**Independent Test**: Second coordinator run with the fake engine is `incremental` and the fake log shows no `--full`; manually, quickstart step 2 (< 2 min by cable)

### Tests for User Story 4 (required for backup flows)

- [X] T048 [US4] Write `Tests/PhoneVaultCoreTests/IncrementalBackupTests.swift`: after a verified first run, the second run has kind `incremental`, `$FAKE_LOG` shows `idevicebackup2` without `--full` and with the staging parent as target, `bytesTransferred` and duration are recorded in `BackupRun`, and the staging was prepared from the valid backup

### Implementation for User Story 4

- [X] T049 [US4] Ensure `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift` sets `kind = .incremental` and `full: false` when `lastValidBackup` exists, and records `bytesTransferred` from the last progress event and `endedAt`
- [X] T050 [US4] Show last run kind, duration and transferred volume in `Sources/PhoneVault/Views/DeviceDetailView.swift`; add strings to `Sources/PhoneVault/Resources/Localizable.strings (en.lproj e pt-BR.lproj)`

**Checkpoint**: incremental path proven by tests; timing goal validated manually

---

## Phase 7: User Story 5 - (removida do MVP)

Removida por decisão do usuário: criptografia fora do MVP. Nenhuma tarefa desta fase se aplica; as tarefas abaixo ficam como registro.

### Tests for User Story 5 (required for backup flows)

- [~] T051 (removida) [P] [US5] Write `Tests/PhoneVaultCoreTests/KeychainStoreTests.swift` using a test-only service name: save, read, delete for a UDID; reading a missing item returns `nil`; teardown deletes the item
- [~] T052 (removida) [P] [US5] Create `Tests/PhoneVaultCoreTests/Support/EncryptedBackupFixture.swift` that builds an encrypted backup from a fake backup and a password (keybag with `DPSL/DPIC/SALT/ITER`, class key wrapped with AES Key Wrap via `CCSymmetricKeyWrap`, `ManifestKey`, `Manifest.db` encrypted AES-256-CBC) and write `Tests/PhoneVaultCoreTests/EncryptedVerifierTests.swift`: right password verifies; wrong password → `wrongPassword`; missing file → `verificationFailed`; no decrypted temp file remains after verification
- [~] T053 (removida) [US5] Write `Tests/PhoneVaultCoreTests/PasswordSecrecyTests.swift`: with encryption on, `$FAKE_LOG` argv lines never contain the password and record `BACKUP_PASSWORD=set` for `backup` and `encryption on`; `ProcessInfo.processInfo.environment` of the test process has no `BACKUP_PASSWORD` afterwards; `state.json` never contains the password; `encryption on` runs when the device is not yet encrypted; `FAKE_MODE=wrongPassword` ends `failed(wrongPassword)` without retry and without saving the password to the Keychain

### Implementation for User Story 5

- [~] T054 (removida) [P] [US5] Implement `KeychainStore` (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`, `kSecClassGenericPassword`, service `PhoneVault.backup-password`, account = UDID, service injectable for tests) in `Sources/PhoneVaultCore/Store/KeychainStore.swift`
- [~] T055 (removida) [US5] Implement `Keybag` (parse `BackupKeyBag` TLV from `Manifest.plist`, derive key with PBKDF2-SHA256 `DPSL/DPIC` then PBKDF2-SHA1 `SALT/ITER` via `CCKeyDerivationPBKDF`, unwrap class keys via `CCSymmetricKeyUnwrap`; wrong password → `wrongPassword`) in `Sources/PhoneVaultCore/Verification/Keybag.swift`
- [~] T056 (removida) [US5] Extend `Sources/PhoneVaultCore/Verification/BackupVerifier.swift` with `password: String?`: when `Manifest.plist` has `IsEncrypted`, unwrap `ManifestKey` with the keybag, decrypt `Manifest.db` (AES-256-CBC, `CCCrypt`) into a temp file removed in `defer`, then run the same file-presence check
- [~] T057 (removida) [US5] Extend `LibimobiledeviceEngine.backup` in `Sources/PhoneVaultCore/Engine/LibimobiledeviceEngine.swift` to pass the password only as `BACKUP_PASSWORD` in the child environment (no `-i`, never in arguments), implement `enableEncryption(udid:password:)` running `idevicebackup2 -u <udid> encryption on` the same way, and map the engine's wrong-password `ERROR` segment to `wrongPassword` (research R2; exact text confirmed in T065)
- [~] T058 (removida) [US5] Update `Sources/PhoneVaultCore/Backup/BackupCoordinator.swift`: when `encryption.enabled`, get the password from `KeychainStore` or from an async `askPassword` callback, keep it only in memory for the run, enable encryption on the device if needed, pass it to engine and verifier, set `ValidBackup.encrypted`
- [~] T059 (removida) [US5] (ajustada) Criptografia: interruptor e aviso em `DeviceDetailView`; senha, confirmação e "Salvar no Keychain" são pedidas em `PasswordPromptView` no primeiro backup criptografado (FR-010–FR-012). Sem etapa de senha no detalhe nem no assistente.
- [~] T060 (removida) [US5] Create `Sources/PhoneVault/Views/PasswordPromptView.swift` (secure field sheet) used by `AppModel` for the `askPassword` callback; add all US5 strings to `Sources/PhoneVault/Resources/Localizable.strings (en.lproj e pt-BR.lproj)`

**Checkpoint**: the four remaining stories pass their tests independently

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Accessibility, localisation, privacy audit and real-hardware validation

- [ ] T061 (parcial: progresso anunciado; falta VoiceOver e teclado no hardware) [P] Accessibility pass on all views in `Sources/PhoneVault/Views/`: `accessibilityLabel`/`accessibilityValue` for progress, state badges and buttons; full flow usable with keyboard only (focus order, default and cancel actions)
- [X] T062 [P] Complete and review en (en-US) and pt-BR texts in both `Localizable.strings (en.lproj e pt-BR.lproj)` files, and add `Tests/PhoneVaultCoreTests/LocalizationTests.swift` that parses both catalogs as JSON (paths relative to `#filePath`) and fails if any key lacks a non-empty `en` or `pt-BR` value, and checks every `FailureReason` case has a message in both (FR-018, SC-009)
- [X] T063 [P] Privacy audit: grep `Sources/` for `Logger` calls and confirm every path, name, UDID and engine output interpolation uses `privacy: .private` and that raw engine stdout is never logged (research R10); fix any finding
- [X] T064 Run `swift test` and `scripts/make-app.sh`; fix failures
- [X] T065 Capture real `idevicebackup2` output from a device (full backup and a passcode prompt if shown) and replace `Tests/PhoneVaultCoreTests/Fixtures/idevicebackup2-progress.txt`; adjust `ProgressParser`, the wrong-password pattern and `fake-engine.sh` if needed (concluída: saída real de backup e o prompt `Waiting for passcode` no fixture, cobertos por `ProgressParserTests`; padrão de senha errada não se aplica sem criptografia)
- [ ] T066 (parcial: repouso, CPU e SMB medidos em `validation-log.md`; SMB completo inviável por latência por arquivo; faltam cabo, incremental em SMB, outros iPhones/iOS, VoiceOver e idiomas) Execute the manual scenarios of `quickstart.md` (US1–US4, SMB, sleep, 3 iOS versions × 2 iPhone models, VoiceOver, macOS in pt-BR / en-US / an unsupported language, CPU < 25%) and record results, timings and the SMB clone/copy measurements in `specs/001-iphone-backup-mvp/validation-log.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none
- **Foundational (Phase 2)**: after Setup; blocks all stories
- **US1 (Phase 3)**: after Foundational
- **US2 (Phase 4)**: after US1 (extends `StagingArea` and `BackupCoordinator`, needs a first verified backup)
- **US3 (Phase 5)**: after US1; independent of US2
- **US4 (Phase 6)**: after US2 (incremental runs start from the cloned/copied valid backup)
- **US5 (Phase 7)**: after US1; independent of US2–US4
- **Polish (Phase 8)**: after all stories

```text
Setup → Foundational → US1 ─┬─→ US2 → US4
                            ├─→ US3
                            └─→ US5
                                     all → Polish
```

### Within Each User Story

- Tests first and failing, then implementation
- Engine/verification/destination code before `BackupCoordinator` changes, coordinator before UI
- `BackupCoordinator.swift` and `DeviceDetailView.swift` are touched by several stories: never edit them in parallel

### Parallel Opportunities

- Setup: T002, T003, T004
- Foundational: T006, T007, T009, T010 in parallel; T013 alongside T011/T012
- US1: tests T015–T018 in parallel; T020, T021, T024 in parallel; views T029–T032 in parallel after T028
- After US1: US3 and US5 can proceed in parallel with US2

## Parallel Example: User Story 1

```bash
# Tests together:
Task: "ProgressParserTests in Tests/PhoneVaultCoreTests/ProgressParserTests.swift"
Task: "BackupVerifierTests in Tests/PhoneVaultCoreTests/BackupVerifierTests.swift"
Task: "LibimobiledeviceEngineTests in Tests/PhoneVaultCoreTests/LibimobiledeviceEngineTests.swift"
Task: "TestedIOSVersionsTests in Tests/PhoneVaultCoreTests/TestedIOSVersionsTests.swift"

# Independent implementation files together:
Task: "ProgressParser in Sources/PhoneVaultCore/Engine/ProgressParser.swift"
Task: "TestedIOSVersions in Sources/PhoneVaultCore/Engine/TestedIOSVersions.swift"
Task: "DeviceMonitor in Sources/PhoneVaultCore/Engine/DeviceMonitor.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + Phase 2
2. Phase 3 (US1)
3. **STOP and VALIDATE**: `swift test`, then quickstart step 1 on a real iPhone (first prototype measurement)

### Incremental Delivery

1. US1 → first verified backup
2. US2 → failure safety (required before any real user data is trusted to the app)
3. US3 and US4 in parallel → destination checks and incremental
4. US4 → incremental path and timing
5. Polish → manual validation log, which gates the MVP acceptance criteria

---

## Notes

- Do not modify `<dest>/<udid>` outside `StagingArea.promote()`; never pass a password as a process argument
- Commit after each task or logical group
- Signing, notarization, universal binaries and bundling libimobiledevice in `Contents/Helpers` are phase 3 (plan Complexity Tracking), not tasks here
