#!/usr/bin/env bash
# test.sh — compiles the helpers with their runnable checks and runs them.
# pmset-tests covers the sudoers rule text and the pmset parsers (pure).
# display-tests covers the real display assertion, which needs IOKit but no root and no GUI.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v swiftc >/dev/null || { echo "error: swiftc not found (xcode-select --install)" >&2; exit 1; }

BIN_DIR="$(mktemp -d)"
swiftc -O -parse-as-library -o "$BIN_DIR/pmset-tests" "$REPO/Pmset.swift" "$REPO/tests/PmsetTests.swift"
"$BIN_DIR/pmset-tests"

swiftc -O -parse-as-library -o "$BIN_DIR/display-tests" "$REPO/DisplayAssertion.swift" "$REPO/tests/DisplayTests.swift"
"$BIN_DIR/display-tests"
