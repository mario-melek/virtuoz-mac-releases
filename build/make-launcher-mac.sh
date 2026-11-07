#!/bin/bash
# Builds "Virtuoz Launcher.app" for one Mac chip from the launcher's resources (the same app.asar as on Windows).
#   bash build/make-launcher-mac.sh <arm64|x64> <version> <resources.zip>
# Out (in the current folder): Virtuoz-Launcher-Mac-<chip>.zip (what Virtuoz and install.sh install into Applications).
set -euo pipefail
ARCH="$1"; V="$2"; RZIP="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
EV="44.4.5"   # the launcher's Electron
ROOT="$PWD"; ICON="$ROOT/build/icon-1024.png"
W="$ROOT/work-launcher-$ARCH"; rm -rf "$W"; mkdir -p "$W"; cd "$W"
PB=/usr/libexec/PlistBuddy
setp() { "$PB" -c "Set :$2 $3" "$1" 2>/dev/null || "$PB" -c "Add :$2 string $3" "$1"; }
setb() { "$PB" -c "Set :$2 $3" "$1" 2>/dev/null || "$PB" -c "Add :$2 bool $3" "$1"; }

curl -fsSL -o electron.zip "https://github.com/electron/electron/releases/download/v$EV/electron-v$EV-darwin-$ARCH.zip"
mkdir el res out
ditto -x -k electron.zip el
ditto -x -k "$RZIP" res

APP="$W/out/Virtuoz Launcher.app"; mv el/Electron.app "$APP"
R="$APP/Contents/Resources"
rm -f "$R/default_app.asar" "$R/electron.icns"
cp -R res/app.asar res/app.asar.unpacked res/installer "$R/"

mkdir icon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON" --out "icon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$ICON" --out "icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns icon.iconset -o "$R/icon.icns"

mv "$APP/Contents/MacOS/Electron" "$APP/Contents/MacOS/Virtuoz Launcher"
P="$APP/Contents/Info.plist"
setp "$P" CFBundleExecutable "Virtuoz Launcher"
setp "$P" CFBundleName "Virtuoz Launcher"
setp "$P" CFBundleDisplayName "Virtuoz Launcher"
setp "$P" CFBundleIdentifier com.virtuoz.launcher
setp "$P" CFBundleShortVersionString "$V"
setp "$P" CFBundleVersion "$V"
setp "$P" CFBundleIconFile icon.icns
setp "$P" NSHumanReadableCopyright "Virtuoz"
setp "$P" LSMinimumSystemVersion 13.0
setb "$P" LSUIElement true          # a menu bar app: no Dock icon

for H in "$APP/Contents/Frameworks/Electron Helper"*.app; do
  N=$(basename "$H" .app); NN="${N/Electron/Virtuoz Launcher}"; HP="$H/Contents/Info.plist"
  mv "$H/Contents/MacOS/$N" "$H/Contents/MacOS/$NN"
  ID=$("$PB" -c "Print :CFBundleIdentifier" "$HP"); ID="${ID/com.github.Electron/com.virtuoz.launcher}"
  setp "$HP" CFBundleExecutable "$NN"; setp "$HP" CFBundleName "$NN"; setp "$HP" CFBundleDisplayName "$NN"; setp "$HP" CFBundleIdentifier "$ID"
  mv "$H" "$APP/Contents/Frameworks/$NN.app"
done

xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"

cd "$W/out"
ditto -c -k --keepParent "Virtuoz Launcher.app" "$ROOT/Virtuoz-Launcher-Mac-$ARCH.zip"
ls -la "$ROOT/Virtuoz-Launcher-Mac-$ARCH.zip"
