import Foundation
import IOKit.pwr_mgt

public final class PowerAssertion: @unchecked Sendable {
    private var id: IOPMAssertionID = 0

    public init() {
        _ = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                        "PhoneVault backup" as CFString, &id)
    }

    public var isHeld: Bool { id != 0 }

    public func release() {
        guard id != 0 else { return }
        IOPMAssertionRelease(id)
        id = 0
    }

    deinit { release() }
}
