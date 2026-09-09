#!/bin/bash
# Claude Lights — gera um .dmg de distribuição: ícone do app + atalho pra
# Applications, layout clássico de "arraste para instalar".
# Uso: ./make-dmg.sh (empacota release automaticamente se precisar)

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE="$APP_DIR/.build/ClaudeLights.app"
VOLUME_NAME="Claude Lights"
DMG_FINAL="$APP_DIR/.build/ClaudeLights.dmg"
STAGING="$APP_DIR/.build/dmg-staging"

if [ ! -d "$BUNDLE" ]; then
  echo "app não encontrado, empacotando primeiro..."
  "$APP_DIR/package.sh" release
fi

echo "preparando staging..."
rm -rf "$STAGING" "$DMG_FINAL"
mkdir -p "$STAGING"
cp -R "$BUNDLE" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

TMP_DMG="$APP_DIR/.build/tmp.dmg"
rm -f "$TMP_DMG"

echo "criando imagem temporária..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING" -ov -format UDRW "$TMP_DMG" -fs HFS+ >/dev/null

MOUNT_DIR="/Volumes/$VOLUME_NAME"
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_DIR" -nobrowse -quiet

echo "ajustando layout no Finder..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, 700, 480}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "ClaudeLights.app" of container window to {110, 160}
        set position of item "Applications" of container window to {390, 160}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet

echo "comprimindo imagem final..."
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" -ov >/dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGING"

echo "pronto: $DMG_FINAL"
ls -lh "$DMG_FINAL"
