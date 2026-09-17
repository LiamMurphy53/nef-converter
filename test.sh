#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
TEST_DIRECTORY=$(mktemp -d /tmp/nef-converter-tests.XXXXXX)
trap 'rm -rf "$TEST_DIRECTORY"' EXIT
xcrun swiftc -swift-version 5 -O -module-cache-path "$TEST_DIRECTORY/module-cache" \
    Sources/Converter.swift Tests/ConversionTests.swift -o "$TEST_DIRECTORY/ConversionTests"
"$TEST_DIRECTORY/ConversionTests" "$@"
