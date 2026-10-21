// DisplayTests.swift — holds the real display assertion and asks `pmset` whether it is there.
// Run with ./test.sh; it needs no root and no GUI session.

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
        check(!table().contains(DisplayAssertion.name), "nothing of ours in pmset while off")

        blocker.set(active: true)
        check(blocker.isHolding, "holds after set(true)")

        let held = table()
        check(held.contains(DisplayAssertion.name), "pmset names our assertion")
        let ours = held.split(separator: "\n").first { $0.contains(DisplayAssertion.name) } ?? ""
        check(ours.contains("PreventUserIdleDisplaySleep"), "and it is a display assertion")

        blocker.set(active: true)
        check(blocker.isHolding, "set(true) twice stays holding")
        check(occurrences(of: DisplayAssertion.name, in: table()) == 1, "and does not stack assertions")

        blocker.release()
        check(!blocker.isHolding, "released")
        check(!table().contains(DisplayAssertion.name), "gone from pmset after release")

        print("")
        if failures == 0 {
            print("all checks passed")
        } else {
            print("\(failures) check(s) FAILED")
        }
        exit(failures == 0 ? 0 : 1)
    }
}

private func occurrences(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
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
