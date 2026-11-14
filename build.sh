#!/bin/bash
# Собирает Pinok.app в ./build
set -euo pipefail
cd "$(dirname "$0")"

# Используем Xcode, даже если в xcode-select выбраны Command Line Tools
if [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi

swift build -c release

APP=build/Pinok.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Pinok "$APP/Contents/MacOS/Pinok"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/onboarding.mp3 "$APP/Contents/Resources/onboarding.mp3"
xattr -cr "$APP"   # без лишних атрибутов (иначе в пакет попадают файлы ._*)
codesign --force --sign - "$APP" >/dev/null

echo "✅ $APP"
