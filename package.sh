#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh --universal
mkdir -p dist
ARCHIVE="NEF-Converter-v1.0.0-macOS-universal.zip"
ditto -c -k --keepParent --norsrc --noextattr "build/NEF Converter.app" "dist/$ARCHIVE"
(cd dist && shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256")
printf 'Release archive: %s/dist/%s\n' "$PWD" "$ARCHIVE"
