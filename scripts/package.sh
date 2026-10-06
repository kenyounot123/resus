#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="${RESUS_VERSION:-0.1.0}"
dist_dir="${RESUS_DIST_DIR:-dist}"
scripts/build-app.sh release
ditto -c -k --sequesterRsrc --keepParent "$dist_dir/Resus.app" "$dist_dir/Resus-$version-mac.zip"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
ditto "$dist_dir/Resus.app" "$staging/Resus.app"
ln -s /Applications "$staging/Applications"
cp LICENSE "$staging/LICENSE.txt"
hdiutil create -volname Resus -srcfolder "$staging" -ov -format UDZO "$dist_dir/Resus-$version-mac.dmg"
shasum -a 256 "$dist_dir/Resus-$version-mac.zip" "$dist_dir/Resus-$version-mac.dmg" > "$dist_dir/SHA256SUMS.txt"
