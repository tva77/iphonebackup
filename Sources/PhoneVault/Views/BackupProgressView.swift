import PhoneVaultCore
import SwiftUI

struct BackupProgressView: View {
    @ObservedObject var model: AppModel
    @State private var confirmingCancel = false

    private var scope: String { model.restoring ? "restore" : "progress" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.activeUdid != nil {
                if let update = model.update {
                    Text(LocalizedStringKey("state.\(update.state.rawValue)"), bundle: .module)
                    ProgressView(value: update.progress.percent, total: 100)
                        .accessibilityLabel(Text(LocalizedStringKey("state.\(update.state.rawValue)"), bundle: .module))
                        .accessibilityValue(Text(verbatim: "\(Int(update.progress.percent)) %"))
                    if update.progress.bytesPerSecond > 0 {
                        Text(verbatim: "\(ByteCountFormatter.string(fromByteCount: Int64(update.progress.bytesPerSecond), countStyle: .file))/s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if update.state == .waitingForDevice {
                        Text("state.waitingForDevice", bundle: .module).font(.headline)
                    }
                }
                Button { confirmingCancel = true } label: { Text("progress.cancel", bundle: .module) }
                    .confirmationDialog(Text(LocalizedStringKey("\(scope).cancelConfirm.title"), bundle: .module), isPresented: $confirmingCancel, titleVisibility: .visible) {
                        Button(role: .destructive) { model.cancelBackup() } label: { Text(LocalizedStringKey("\(scope).cancelConfirm.confirm"), bundle: .module) }
                        Button(role: .cancel) {} label: { Text(LocalizedStringKey("\(scope).keepGoing"), bundle: .module) }
                    } message: {
                        Text(LocalizedStringKey("\(scope).cancelConfirm.message"), bundle: .module)
                    }
            } else if let result = model.result {
                if result.state == .verified {
                    Text(LocalizedStringKey(result.kind == .restore ? "restore.done" : "state.verified"), bundle: .module).font(.headline)
                } else {
                    Text(LocalizedStringKey("state.\(result.state.rawValue)"), bundle: .module).font(.headline)
                    if let failure = result.failure {
                        Text(verbatim: failure.message.cause)
                        Text(verbatim: failure.message.action).font(.caption)
                    }
                    Text("progress.keptPrevious", bundle: .module).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
