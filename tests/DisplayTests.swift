// DisplayTests.swift — holds the real display assertion and asks `pmset` whether it is there.
// Run with ./test.sh; it needs no root and no GUI session.
//
// Checks are scoped to this process's pid, not to the assertion's name: the app legitimately holds
// an assertion with the same name, so a name-only test fails whenever Sleepless is running.

import Foundation

private var failures = 0

private func check(_ condition: Bool, _ what: String) {
    if condition {
        print("  ok   \(what)")
    } else {
        failures += 1
        print("  FAIL \(what)")
    }
}

@main
enum DisplayTests {
    static func main() {
        print("DisplaySleepBlocker")
        let blocker = DisplaySleepBlocker()

        blocker.set(active: false)
        check(!blocker.isHolding, "off by default")
        check(ourLines().isEmpty, "nothing of ours in pmset while off")

        blocker.set(active: true)
        check(blocker.isHolding, "holds after set(true)")
        check(ourLines().count == 1, "pmset lists exactly one assertion of ours")
        check(ourLines().first?.contains(DisplayAssertion.name) == true, "and pmset names it")
        check(ourLines().first?.contains("PreventUserIdleDisplaySleep") == true, "and it is a display assertion")

        blocker.set(active: true)
        check(blocker.isHolding, "set(true) twice stays holding")
        check(ourLines().count == 1, "and does not stack a second assertion")

        blocker.release()
        check(!blocker.isHolding, "released")
        check(ourLines().isEmpty, "gone from pmset after release")

        print("")
        if failures == 0 {
            print("all checks passed")
        } else {
            print("\(failures) check(s) FAILED")
        }
        exit(failures == 0 ? 0 : 1)
    }
}

/// Assertion lines owned by this process — not merely lines mentioning our name.
private func ourLines() -> [String] {
    table()
        .split(separator: "\n")
        .map(String.init)
        .filter { $0.contains("pid \(getpid())(") && $0.contains(DisplayAssertion.name) }
}

private func table() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
    process.arguments = ["-g", "assertions"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = Pipe()
    do { try process.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}
