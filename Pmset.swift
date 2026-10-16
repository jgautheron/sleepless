// Pmset.swift — the pure parts: the sudoers rule, the pmset output parsers, and the
// AppleScript literal escaper. Kept out of App.swift so they run under tests/ without a
// GUI session or a battery (see test.sh).

import Foundation

enum SudoersRule {
    static let path = "/etc/sudoers.d/sleepless-disablesleep"

    // Absolute tool paths: the one root command this app runs must not depend on PATH.
    static let visudo = "/usr/sbin/visudo"
    static let installTool = "/usr/bin/install"
    static let remove = "/bin/rm"

    /// macOS account short names are `[A-Za-z0-9._-]`. Anything else must never reach a
    /// sudoers line or a root shell command.
    static func isValidUserName(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= 32 else { return false }
        return name.allSatisfy { character in
            character.isASCII && (character.isLetter || character.isNumber || character == "." || character == "_" || character == "-")
        }
    }

    /// The only line this app is allowed to install: two fully specified commands, no wildcards.
    static func line(for user: String) -> String {
        "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"
    }

    /// A grant for root is useless and never intended: the account-name charset allows it, so refuse it here.
    static func isAllowedUser(_ name: String) -> Bool {
        isValidUserName(name) && name != "root"
    }

    /// Validate a rule file, install it, confirm sudoers still parses, then drop the temp copy.
    /// Every binary here is Apple's; the only input is a file we wrote ourselves.
    static func installCommand(tempPath: String) -> String {
        "\(visudo) -cf '\(tempPath)' && \(installTool) -m 0440 -o root -g wheel '\(tempPath)' \(path) && \(visudo) -c && \(remove) -f '\(tempPath)'"
    }
}

struct BatteryStatus: Equatable {
    let onBattery: Bool
    let discharging: Bool
    /// nil when the level could not be read. Callers must treat that as unsafe, not as 100%.
    let percent: Int?
}

enum PmsetOutput {
    /// `pmset -g` -> the SleepDisabled flag. An absent line means sleep is normal.
    static func sleepDisabled(_ output: String) -> Bool {
        for line in output.split(separator: "\n") where line.range(of: "SleepDisabled", options: .caseInsensitive) != nil {
            guard let value = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last else { continue }
            return value == "1"
        }
        return false
    }

    /// `pmset -g batt` -> power source, discharging state, and level.
    static func battery(_ output: String) -> BatteryStatus {
        let onBattery = output.contains("Battery Power")
        let discharging = output.range(of: "discharging", options: .caseInsensitive) != nil
        // The level lives in the first field of the battery line, before the first semicolon,
        // so an unrelated percentage later in the output can never be mistaken for it.
        var percent: Int?
        for line in output.split(separator: "\n") {
            let head = line.split(separator: ";").first.map(String.init) ?? String(line)
            for token in head.split(whereSeparator: { " \t".contains($0) }) where token.hasSuffix("%") {
                if let value = Int(token.dropLast()) {
                    percent = value
                    break
                }
            }
            if percent != nil { break }
        }
        return BatteryStatus(onBattery: onBattery, discharging: discharging, percent: percent)
    }
}

enum AppleScriptLiteral {
    /// Escapes a Swift string for use inside a double-quoted AppleScript literal.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
