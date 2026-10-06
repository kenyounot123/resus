#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-debug}"
version="${RESUS_VERSION:-0.1.0}"
build_dir="${RESUS_BUILD_DIR:-.build}"
dist_dir="${RESUS_DIST_DIR:-dist}"
mkdir -p "$dist_dir"
if [[ "$mode" == "release" ]]; then
    swift build --scratch-path "$build_dir" -c release --arch arm64 --arch x86_64
    binary="$(swift build --scratch-path "$build_dir" -c release --arch arm64 --arch x86_64 --show-bin-path)/Resus"
else
    swift build --scratch-path "$build_dir"
    binary="$(swift build --scratch-path "$build_dir" --show-bin-path)/Resus"
fi
app="$dist_dir/Resus.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Resus"
/usr/libexec/PlistBuddy -c 'Clear dict' "$app/Contents/Info.plist" 2>/dev/null || true
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Resus</string>
<key>CFBundleDisplayName</key><string>Resus</string>
<key>CFBundleIdentifier</key><string>com.kenyounot123.resus</string>
<key>CFBundleExecutable</key><string>Resus</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 Ken Lu. MIT License.</string>
</dict></plist>
PLIST
if [[ -f assets/Resus.icns ]]; then
    cp assets/Resus.icns "$app/Contents/Resources/Resus.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string Resus' "$app/Contents/Info.plist"
fi
codesign --force --sign "${RESUS_SIGN_IDENTITY:--}" --options runtime "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
