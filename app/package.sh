#!/bin/bash
# Claude Lights — empacota o binário compilado como .app de verdade.
# Uso: ./package.sh [debug|release] (default: release)

set -euo pipefail

CONFIG="${1:-release}"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$APP_DIR/.build/$CONFIG"
BUNDLE="$APP_DIR/.build/ClaudeLights.app"

echo "compilando ($CONFIG)..."
swift build -c "$CONFIG" --package-path "$APP_DIR"

echo "empacotando em $BUNDLE ..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BUILD_DIR/ClaudeLights" "$BUNDLE/Contents/MacOS/ClaudeLights"
cp "$APP_DIR/../assets/spark.svg" "$BUNDLE/Contents/Resources/spark.svg" 2>/dev/null || true

cat > "$BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeLights</string>
    <key>CFBundleIdentifier</key>
    <string>dev.henriquekaraim.claudelights</string>
    <key>CFBundleName</key>
    <string>Claude Lights</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "assinando (ad-hoc)..."
codesign --force --deep --sign - "$BUNDLE" 2>&1 | grep -v "replacing existing signature" || true

echo "pronto: $BUNDLE"
echo
echo "Para rodar:      open \"$BUNDLE\""
echo "Para levar pra /Applications: cp -R \"$BUNDLE\" /Applications/"
