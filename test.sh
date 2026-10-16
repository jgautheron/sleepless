#!/usr/bin/env bash
# test.sh — compiles the pure helpers with their runnable checks and runs them.
# No GUI session, no battery, no root: this covers the sudoers rule text and the pmset parsers.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v swiftc >/dev/null || { echo "error: swiftc not found (xcode-select --install)" >&2; exit 1; }

BIN="$(mktemp -d)/pmset-tests"
swiftc -O -parse-as-library -o "$BIN" "$REPO/Pmset.swift" "$REPO/tests/PmsetTests.swift"
"$BIN"
