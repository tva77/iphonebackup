import PhoneVaultCore
import SwiftUI

struct MainView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(model.devices, selection: $model.selection) { device in
                VStack(alignment: .leading) {
                    Text(verbatim: device.name)
                    Text(verbatim: device.model).font(.caption).foregroundStyle(.secondary)
                    if model.activeUdid == device.udid {
                        Text("state.backingUp", bundle: .module).font(.caption).foregroundStyle(.secondary)
                    } else if let last = device.lastValidBackup {
                        Text(verbatim: last.completedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("device.none", bundle: .module).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(device.udid)
            }
        } detail: {
            if let device = model.devices.first(where: { $0.udid == model.selection }) {
                DeviceDetailView(model: model, device: device)
            } else {
                OnboardingView(model: model)
            }
        }
        .sheet(isPresented: $model.untestedPending) {
            VStack(spacing: 16) {
                Text("untested.title", bundle: .module).font(.headline)
                Text("untested.message", bundle: .module).multilineTextAlignment(.center)
                HStack {
                    Button { model.answerUntested(false) } label: { Text("progress.cancel", bundle: .module) }
                    Button { model.answerUntested(true) } label: { Text("untested.continue", bundle: .module) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 380)
        }
    }
}

struct DeviceDetailView: View {
    @ObservedObject var model: AppModel
    let device: Device
    @State private var choosingFolder = false
    @State private var confirmingRestore = false

    var body: some View {
        Form {
            Section {
                LabeledContent { Text(verbatim: device.iosVersion) } label: { Text(verbatim: device.name) }
                LabeledContent { Text(verbatim: ByteCountFormatter.string(fromByteCount: device.usedBytes, countStyle: .file)) } label: {
                    Text("device.used", bundle: .module)
                }
            }
            Section {
                LabeledContent {
                    Text(verbatim: device.destination?.path ?? "")
                } label: {
                    Button { choosingFolder = true } label: { Text("device.chooseFolder", bundle: .module) }
                }
                .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
                    if case .success(let url) = result { model.chooseDestination(device.udid, url: url) }
                }
            }
            Section {
                if let last = device.lastValidBackup {
                    Text(verbatim: last.completedAt.formatted(date: .abbreviated, time: .shortened))
                } else {
                    Text("device.none", bundle: .module)
                }
                Button { model.startBackup(device.udid) } label: { Text("device.backupNow", bundle: .module) }
                    .disabled(device.destination == nil || model.activeUdid != nil)
                if device.destination == nil {
                    Text("device.noDestination", bundle: .module).font(.caption).foregroundStyle(.secondary)
                }
                Button { confirmingRestore = true } label: { Text("device.restoreNow", bundle: .module) }
                    .disabled(device.lastValidBackup == nil || device.destination == nil || model.activeUdid != nil)
                    .confirmationDialog(Text("restore.confirm.title", bundle: .module), isPresented: $confirmingRestore, titleVisibility: .visible) {
                        Button(role: .destructive) { model.startRestore(device.udid) } label: { Text("restore.confirm.action", bundle: .module) }
                        Button(role: .cancel) {} label: { Text("progress.cancel", bundle: .module) }
                    } message: {
                        Text("restore.confirm.message", bundle: .module)
                    }
                if device.lastValidBackup == nil {
                    Text("device.restoreNeedsBackup", bundle: .module).font(.caption).foregroundStyle(.secondary)
                }
                if model.activeUdid == device.udid || model.result != nil {
                    BackupProgressView(model: model)
                }
            } header: {
                Text("device.lastBackup", bundle: .module)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Text("onboarding.title", bundle: .module).font(.title2)
            Text("onboarding.connect", bundle: .module).multilineTextAlignment(.center)
            ForEach(model.connected, id: \.self) { udid in
                if let state = model.pairing[udid], state != .paired {
                    Text(LocalizedStringKey(pairingKey(state)), bundle: .module).multilineTextAlignment(.center)
                    Button { model.retryPairing(udid) } label: { Text("pairing.retry", bundle: .module) }
                }
            }
        }
        .padding(32)
        .frame(maxWidth: 420)
    }

    private func pairingKey(_ state: PairingState) -> String {
        switch state {
        case .locked: "pairing.locked"
        case .denied: "pairing.denied"
        default: "pairing.needsTrust"
        }
    }
}
