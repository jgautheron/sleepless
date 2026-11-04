# What this fork changes, and why

This is a public fork of [Aboudjem/Sleepless](https://github.com/Aboudjem/Sleepless)
(MIT, © Adam Boudjemaa). Upstream is kept as the `upstream` remote; `git log upstream/main` is the
unmodified lineage. Nothing here removes the original licence or copyright.

Work lands through pull requests against `main`, which starts as upstream's unmodified `v1.2.7`.

The app does what upstream does: one menu-bar switch that flips `pmset disablesleep` so a MacBook
keeps running with the lid shut, with an auto-off timer, a battery floor, and a battery/Low-Power-Mode
safety net. The fork is a security pass over the privilege path.

## Upstream stays untouched

Upstream is a remote here, so a fix made in this fork can be sent upstream unchanged.

## Fixed

| # | Problem | Fix |
|---|---------|-----|
| 1 | **Root executed a script the user could rewrite.** `App.swift` ran the bundle's `grant.sh` as root through `osascript … with administrator privileges`, and `/Applications` is admin-group writable, so anything running as the user could swap that file and collect root on the next approval. | The app no longer runs any file from the bundle. It writes the rule itself, then runs Apple's `visudo` and `install` on it: validate, install `0440 root:wheel`, re-validate, clean up. `build.sh` no longer copies `grant.sh` into the bundle at all. |
| 2 | **Two login mechanisms disagreed.** `install.sh` wrote a `LaunchAgent`, while the app's switch used `SMAppService.mainApp` and reported only that — so after install the app launched at login while its own switch showed off. | `install.sh` now removes a legacy `LaunchAgent` instead of writing one. `SMAppService` is the single mechanism. |
| 3 | **The battery floor failed open.** The parser defaulted the level to `100`, so an unreadable `pmset -g batt` meant the floor never fired. | The level is now optional. Unreadable is treated as unsafe: the app turns itself off and says so. The level is also read only from the battery field, before the first semicolon. |
| 4 | **Latent AppleScript injection in notifications.** The message was interpolated into the script unescaped. | `AppleScriptLiteral.escape` is applied, and is shared with the grant command. |
| 5 | **Username went into a sudoers line unvalidated.** | `SudoersRule.isValidUserName` refuses anything outside the account-name charset, in both the app and `grant.sh`. |
| 6 | **Declared minimum OS disagreed with the build target**, and signing used deprecated `--deep`. | Both are now macOS 26 (what this is tested on); `--deep` is gone. |

## Unchanged, on purpose

- `disablesleep` is undocumented in `pmset(1)` (`man pmset` mentions it zero times). Apple could
  change it. The app reads the live value back after every toggle, so the UI never assumes.
- There is still **no watchdog**: kill the app with the flag on and the Mac stays unable to sleep
  until a reboot or the battery floor. That is upstream's accepted design, and it is the one real
  gap against a helper-based design.
- The auto-off timer and the "user forced this on" flag remain in memory only.

## Added on top of upstream: the display stays awake too

Upstream only blocks *system* sleep, so the screen still went dark on the display-sleep timer — and on a
managed Mac that locks it immediately (MDM sets `askForPassword` with no delay). KeepingYouAwake held
`caffeinate -di`, whose `-d` kept the display awake, so replacing it with this app quietly changed that.

While the toggle is ON the app now holds an in-process `PreventUserIdleDisplaySleep` assertion named
`Sleepless: keeping the display awake`. In-process, so the kernel drops it with the app and a crash
cannot leave the screen unable to sleep. Every state path funnels through `applyUI(on:)`, so the auto-off
timer, the battery floor and Low Power Mode release it too. `tests/DisplayTests.swift` asks `pmset` for it.

This does **not** defeat the screensaver: its idle timer is a separate clock (20 minutes here, set by
MDM), and an IOKit display assertion does not reset it. `IOPMAssertionDeclareUserActivity` — what
`caffeinate -u` does — is the lever if that ever matters.

## Checks

```sh
./test.sh              # pure helpers: the sudoers rule text, the parsers, the escaper
./build.sh             # compile and assemble build/Sleepless.app (ad-hoc signed)
./install.sh           # build into /Applications + install the passwordless grant (asks first)
./uninstall.sh         # restore sleep, remove app, remove the grant, prove revocation
```

`test.sh` covers the rule text and the parsers without a GUI session, a battery, or root.
