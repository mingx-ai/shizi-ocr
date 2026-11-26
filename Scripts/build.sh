#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

output="$PWD/build"
bundle="$output/拾字.app"
cache="$output/module-cache"
mkdir -p "$cache" "$output/objects"

for architecture in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -whole-module-optimization \
        -module-cache-path "$cache" -target "$architecture-apple-macos13.0" \
        Sources/*.swift -o "$output/objects/Shizi-$architecture"
done

mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
xcrun lipo -create "$output/objects/Shizi-arm64" "$output/objects/Shizi-x86_64" \
    -output "$output/objects/Shizi"
mv -f "$output/objects/Shizi" "$bundle/Contents/MacOS/Shizi"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
cp Resources/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
/usr/bin/plutil -lint "$bundle/Contents/Info.plist"
/usr/bin/codesign --force --sign - --identifier studio.shizi.ScreenText "$bundle"
/usr/bin/codesign --verify --strict --all-architectures "$bundle"
printf '%s\n' "$bundle"
