#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_DIR="$ROOT_DIR/dist/ScreenSketch.app"
MACOS_TARGET="$(uname -m)-apple-macos13"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$ROOT_DIR/.build/module-cache"

xcrun swiftc \
    -O \
    -whole-module-optimization \
    -module-cache-path "$ROOT_DIR/.build/module-cache" \
    -target "$MACOS_TARGET" \
    -o "$APP_DIR/Contents/MacOS/ScreenSketch" \
    "$ROOT_DIR"/Sources/ScreenSketch/*.swift

cp "$ROOT_DIR/packaging/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

print "Built $APP_DIR"
