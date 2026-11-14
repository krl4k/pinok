#!/bin/bash
# Записывает демо-гифки для README в docs/.
# Приложение показывает своё окно-«сцену» по центру экрана, записывается только оно.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/Pinok.app/Contents/MacOS/Pinok
TMP=$(mktemp -d)

record() {
    local kind=$1 seconds=$2
    "$APP" --stage "$kind" > "$TMP/$kind.log" &
    local pid=$!
    for _ in $(seq 50); do grep -q STAGE "$TMP/$kind.log" 2>/dev/null && break; sleep 0.1; done
    local rect; rect=$(grep STAGE "$TMP/$kind.log" | cut -d' ' -f2)
    screencapture -v -x -V "$seconds" -R "$rect" "$TMP/$kind.mov"
    wait $pid || true
    ffmpeg -loglevel error -y -i "$TMP/$kind.mov" \
        -vf "fps=24,scale=800:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192[p];[b][p]paletteuse=dither=sierra2_4a" \
        "docs/$kind.gif"
    echo "✅ docs/$kind.gif"
}

record onboarding 7
record posture 5
record tongue 5
record set 5
record break 7
rm -rf "$TMP"
