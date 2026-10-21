// DisplayAssertion.swift — keeps the *display* awake for as long as Sleepless is on, which is what
// KeepingYouAwake's `caffeinate -d` did and this app never did on its own.
//
// In-process on purpose: the kernel drops the assertion when this app dies, so a crash cannot leave
// the screen unable to sleep, and `pmset -g assertions` names the app and the reason rather than a
// bare "caffeinate command-line tool".

import Foundation
import IOKit.pwr_mgt

enum DisplayAssertion {
    static let name = "Sleepless: keeping the display awake"
}

final class DisplaySleepBlocker {
    private var assertionID: IOPMAssertionID?
    private(set) var isHolding = false

    /// Idempotent: IOKit is touched only when the wanted state differs from the held one.
    /// A failure to create the assertion leaves the flag off and the app otherwise working.
    func set(active: Bool) {
        guard active != isHolding else { return }
        guard active else {
            release()
            return
        }
        var newID: IOPMAssertionID = 0
        let status = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            DisplayAssertion.name as CFString,
            &newID
        )
        guard status == kIOReturnSuccess else { return }
        assertionID = newID
        isHolding = true
    }

    func release() {
        if let assertionID {
            IOPMAssertionRelease(assertionID)
            self.assertionID = nil
        }
        isHolding = false
    }
}
