// PmsetTests.swift — runnable checks for the pure helpers. Compile and run with ./test.sh.

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
enum PmsetTests {
    static func main() {
        print("SudoersRule")
        check(SudoersRule.isValidUserName("jonathangautheron"), "accepts a normal short name")
        check(SudoersRule.isValidUserName("a.b_c-d"), "accepts dots, underscores and dashes")
        check(!SudoersRule.isValidUserName("root'), (ALL) NOPASSWD"), "rejects a rule-shaped injection")
        check(!SudoersRule.isValidUserName("has space"), "rejects whitespace")
        check(!SudoersRule.isValidUserName(""), "rejects an empty name")
        check(!SudoersRule.isValidUserName(String(repeating: "a", count: 33)), "rejects an over-long name")
        check(SudoersRule.isValidUserName("root"), "root is inside the account-name charset")
        check(!SudoersRule.isAllowedUser("root"), "and is refused anyway")
        check(SudoersRule.isAllowedUser("jonathangautheron"), "a normal account is allowed")

        let rule = SudoersRule.line(for: "someone")
        check(rule.hasPrefix("someone ALL=(root) NOPASSWD: "), "the rule names the user")
        check(!rule.contains("*"), "the rule has no wildcard")
        check(
            rule.hasSuffix("/usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"),
            "the rule pins both pmset commands exactly"
        )
        check(SudoersRule.path == "/etc/sudoers.d/sleepless-disablesleep", "the rule path is unchanged")

        let command = SudoersRule.installCommand(tempPath: "/tmp/x")
        check(command.hasPrefix("/usr/sbin/visudo -cf '/tmp/x' &&"), "validates the rule before installing it")
        check(command.contains("/usr/bin/install -m 0440 -o root -g wheel '/tmp/x'"), "installs root:wheel 0440")
        check(command.hasSuffix("/usr/sbin/visudo -c && /bin/rm -f '/tmp/x'"), "re-checks sudoers and cleans up")
        check(!command.contains("sh -c") && !command.contains("bash"), "runs no shell and no script")

        print("PmsetOutput.sleepDisabled")
        check(PmsetOutput.sleepDisabled(" SleepDisabled\t\t1\n"), "reads SleepDisabled 1 as on")
        check(!PmsetOutput.sleepDisabled(" SleepDisabled\t\t0\n"), "reads SleepDisabled 0 as off")
        check(!PmsetOutput.sleepDisabled(" sleep\t\t1\n"), "an absent SleepDisabled line means off")

        print("PmsetOutput.battery")
        let onAC = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=123)\t80%; AC attached; not charging present: true\n"
        let discharging = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=123)\t42%; discharging; 3:12 remaining present: true\n"
        let unreadable = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=123)\tunknown; discharging present: true\n"
        let noisy = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=99)\t17%; discharging; 99% somewhere else\n"

        let ac = PmsetOutput.battery(onAC)
        check(!ac.onBattery && !ac.discharging && ac.percent == 80, "AC: not on battery, level 80")
        let battery = PmsetOutput.battery(discharging)
        check(battery.onBattery && battery.discharging && battery.percent == 42, "battery: discharging at 42%")
        check(PmsetOutput.battery(unreadable).percent == nil, "an unreadable level is nil, never a silent 100")
        check(PmsetOutput.battery(noisy).percent == 17, "the level is read before the first semicolon")

        print("AppleScriptLiteral")
        check(AppleScriptLiteral.escape("plain text") == "plain text", "leaves plain text alone")
        check(AppleScriptLiteral.escape("say \"hi\" \\ now") == "say \\\"hi\\\" \\\\ now", "escapes quotes and backslashes")
        check(AppleScriptLiteral.escape("Battery low (12%).") == "Battery low (12%).", "percentages need no escaping")

        print("")
        if failures == 0 {
            print("all checks passed")
        } else {
            print("\(failures) check(s) FAILED")
        }
        exit(failures == 0 ? 0 : 1)
    }
}
