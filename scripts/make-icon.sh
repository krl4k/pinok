#!/bin/bash
# Рисует иконку и собирает Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
swift scripts/make-icon.swift
SET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s docs/icon-1024.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  d=$((s*2)); sips -z $d $d docs/icon-1024.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "✅ Resources/AppIcon.icns"
