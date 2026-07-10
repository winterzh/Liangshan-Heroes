#!/bin/bash
# 一键打包：Windows x86_64 exe + macOS arm64 app/dmg + Android arm64 debug APK。
#   bash tools/build_packages.sh
set -e
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
ROOT="/Users/dztdash/Antigravity/ra-aa"
cd "$ROOT"
mkdir -p build

echo "== Windows x86_64 =="
"$GODOT" --headless --path . --export-release "Windows Desktop" build/LiangshanHeroes.exe > /tmp/win_export.log 2>&1
echo "  -> build/LiangshanHeroes.exe"

echo "== Android arm64 (debug signed) =="
"$GODOT" --headless --path . --export-debug "Android" build/LiangshanHeroes.apk > /tmp/android_export.log 2>&1
echo "  -> build/LiangshanHeroes.apk"

echo "== macOS: export universal -> thin to arm64 -> ad-hoc sign =="
rm -rf build/LiangshanHeroes.app
"$GODOT" --headless --path . --export-release "macOS" build/LiangshanHeroes.app > /tmp/mac_export.log 2>&1
APP="build/LiangshanHeroes.app"
BIN=$(ls "$APP/Contents/MacOS/"* | head -1)
/usr/bin/lipo "$BIN" -thin arm64 -output /tmp/_arm64bin
mv /tmp/_arm64bin "$BIN"; chmod +x "$BIN"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP" 2>/dev/null
echo "  -> build/LiangshanHeroes.app (arm64, ad-hoc signed)"

echo "== dmg (drag-to-Applications) =="
STAGE=/tmp/dmgstage_build
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/LiangshanHeroes.app"
ln -s /Applications "$STAGE/Applications"
rm -f build/LiangshanHeroes.dmg
hdiutil create -volname "水浒英雄传" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov build/LiangshanHeroes.dmg > /dev/null
rm -rf "$STAGE"
echo "  -> build/LiangshanHeroes.dmg"

echo "== summary =="
echo -n "  app arch: "; /usr/bin/lipo -archs "$BIN"
/usr/bin/codesign -dvv "$APP" 2>&1 | grep -iE "Signature=" | sed 's/^/  /'
ls -lh build/ | grep -vE "^total" | awk '{printf "  %-26s %s\n",$9,$5}'
