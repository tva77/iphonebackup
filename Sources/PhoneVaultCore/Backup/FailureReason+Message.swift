import Foundation

extension FailureReason {
    public var message: (cause: String, action: String) {
        let key: String
        switch self {
        case .deviceLocked: key = "deviceLocked"
        case .trustDenied: key = "trustDenied"
        case .deviceDisconnected: key = "deviceDisconnected"
        case .cancelledOnDevice: key = "cancelledOnDevice"
        case .destinationUnavailable: key = "destinationUnavailable"
        case .destinationReadOnly: key = "destinationReadOnly"
        case .insufficientSpace: key = "insufficientSpace"
        case .unsupportedFileSystem: key = "unsupportedFileSystem"
        case .untestedIOSNotConfirmed: key = "untestedIOSNotConfirmed"
        case .sleepOrPowerLoss: key = "sleepOrPowerLoss"
        case .engineCrashed: key = "engineCrashed"
        case .verificationFailed: key = "verificationFailed"
        case .restoreIncomplete: key = "restoreIncomplete"
        case .restoreRefused: key = "restoreRefused"
        case .protocolMismatch: key = "protocolMismatch"
        case .originChanged: key = "originChanged"
        }
        return (String(localized: "failure.\(key).cause", bundle: .module), String(localized: "failure.\(key).action", bundle: .module))
    }
}
