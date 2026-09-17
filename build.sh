#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
DESTINATION="$PWD/build/NEF Converter.app"
STAGING=$(mktemp -d /tmp/nef-converter-build.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/NEF Converter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp LICENSE "$APP/Contents/Resources/LICENSE.txt"
if [[ "${1:-}" == "--universal" ]]; then
    ARCHITECTURES=(arm64 x86_64)
elif [[ $# -eq 0 ]]; then
    ARCHITECTURES=("$(uname -m)")
else
    printf 'Usage: bash build.sh [--universal]\n' >&2
    exit 2
fi
BINARIES=()
for ARCH in "${ARCHITECTURES[@]}"; do
    BINARY="$STAGING/NEFConverter-$ARCH"
    xcrun swiftc -swift-version 5 -O -target "$ARCH-apple-macos12.0" \
        -module-cache-path "$STAGING/module-cache" \
        Sources/Converter.swift Sources/App.swift -o "$BINARY"
    BINARIES+=("$BINARY")
done
if [[ ${#BINARIES[@]} -gt 1 ]]; then
    xcrun lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/NEFConverter"
else
    cp "${BINARIES[0]}" "$APP/Contents/MacOS/NEFConverter"
fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>NEFConverter</string>
<key>CFBundleIdentifier</key><string>local.nefconverter.app</string>
<key>CFBundleName</key><string>NEF Converter</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Nikon RAW Photo</string>
<key>CFBundleTypeRole</key><string>Viewer</string>
<key>LSHandlerRank</key><string>Alternate</string>
<key>CFBundleTypeExtensions</key><array><string>nef</string><string>NEF</string></array>
</dict></array>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
mkdir -p "$PWD/build"
ditto --norsrc --noextattr "$APP" "$DESTINATION"
printf 'Built %s\n' "$DESTINATION"
