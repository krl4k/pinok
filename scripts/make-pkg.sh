#!/bin/bash
# Собирает установщик build/Pinok-<version>.pkg.
# Он ставит Pinok.app в /Applications и сразу запускает приложение.
set -euo pipefail
cd "$(dirname "$0")/.."

./build.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
PKG="build/Pinok-$VERSION.pkg"
ROOT=$(mktemp -d)
COMPONENTS=$(mktemp -d)/components.plist

cp -R build/Pinok.app "$ROOT/"

# Не даём установщику «переносить» приложение туда, где лежит старая копия.
pkgbuild --analyze --root "$ROOT" "$COMPONENTS" >/dev/null
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$COMPONENTS"

rm -f "$PKG"
pkgbuild --quiet \
    --root "$ROOT" \
    --component-plist "$COMPONENTS" \
    --install-location /Applications \
    --identifier dev.local.pinok \
    --version "$VERSION" \
    --scripts scripts/pkg \
    "$PKG"
rm -rf "$ROOT"

echo "✅ $PKG ($(du -h "$PKG" | cut -f1))"
