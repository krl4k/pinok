#!/bin/bash
# Собирает build/Pinok-<version>.dmg: внутри Pinok.app и ярлык на /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG="build/Pinok-$VERSION.dmg"
STAGING=$(mktemp -d)

cp -R build/Pinok.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -quiet -volname "Pinok" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "✅ $DMG ($(du -h "$DMG" | cut -f1))"
