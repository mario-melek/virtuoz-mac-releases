#!/bin/bash
# Builds Virtuoz.app for one Mac chip from the published Windows version (same code, same templates).
#   bash build/make-mac.sh <arm64|x64> <version>
# Out (in the current folder): Virtuoz-<v>-Mac-<chip>.dmg (install) and Virtuoz-<v>-mac-<chip>.zip (the update gate's copy).
set -euo pipefail
ARCH="$1"; V="$2"
EV="44.4.5"   # the Electron of Virtuoz.exe
ROOT="$PWD"; ICON="$ROOT/build/icon-1024.png"
W="$ROOT/work-$ARCH"; rm -rf "$W"; mkdir -p "$W"; cd "$W"
PB=/usr/libexec/PlistBuddy
setp() { "$PB" -c "Set :$2 $3" "$1" 2>/dev/null || "$PB" -c "Add :$2 string $3" "$1"; }

echo "== downloads"
# github.com's release links can answer 504 (2026-11-08) while the API answers: then gh (the API)
curl -fsSL -o win.zip "https://github.com/mario-melek/virtuoz-releases/releases/download/v$V/Virtuoz-$V-win-x64.zip" ||
  gh release download "v$V" -R mario-melek/virtuoz-releases -p "Virtuoz-$V-win-x64.zip" -O win.zip --clobber
curl -fsSL -o electron.zip "https://github.com/electron/electron/releases/download/v$EV/electron-v$EV-darwin-$ARCH.zip"
mkdir win el out
ditto -x -k win.zip win
ditto -x -k electron.zip el

echo "== app bundle"
APP="$W/out/Virtuoz.app"; mv el/Electron.app "$APP"
R="$APP/Contents/Resources"
rm -f "$R/default_app.asar" "$R/electron.icns"
cp -R win/resources/. "$R/"
# Windows only: the bundled ffmpeg.exe (on a Mac the app downloads its own) and the UAC helper
rm -rf "$R/runtime" "$R/elevate.exe" "$R/files.json"
# Chromium's languages: like Creatorize (en only), plus French, which the app asks Chromium for (--lang=fr)
for D in "$R" "$APP/Contents/Frameworks/Electron Framework.framework/Versions/A/Resources"; do
  find "$D" -maxdepth 1 -name '*.lproj' ! -name 'en.lproj' ! -name 'fr.lproj' ! -name 'fr_*.lproj' -exec rm -rf {} +
done
printf 'owner: mario-melek\nrepo: virtuoz-mac-releases\nprovider: github\nreleaseType: release\nupdaterCacheDirName: virtuoz-updater\n' > "$R/app-update.yml"

mkdir icon.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON" --out "icon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$ICON" --out "icon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns icon.iconset -o "$R/icon.icns"

mv "$APP/Contents/MacOS/Electron" "$APP/Contents/MacOS/Virtuoz"
P="$APP/Contents/Info.plist"
setp "$P" CFBundleExecutable Virtuoz
setp "$P" CFBundleName Virtuoz
setp "$P" CFBundleDisplayName Virtuoz
setp "$P" CFBundleIdentifier com.virtuoz.app
setp "$P" CFBundleShortVersionString "$V"
setp "$P" CFBundleVersion "$V"
setp "$P" CFBundleIconFile icon.icns
setp "$P" NSHumanReadableCopyright "Virtuoz"

# Electron finds its helpers as "<app name> Helper (...).app": rename them and their executables
for H in "$APP/Contents/Frameworks/Electron Helper"*.app; do
  N=$(basename "$H" .app); NN="${N/Electron/Virtuoz}"; HP="$H/Contents/Info.plist"
  mv "$H/Contents/MacOS/$N" "$H/Contents/MacOS/$NN"
  ID=$("$PB" -c "Print :CFBundleIdentifier" "$HP"); ID="${ID/com.github.Electron/com.virtuoz.app}"
  setp "$HP" CFBundleExecutable "$NN"; setp "$HP" CFBundleName "$NN"; setp "$HP" CFBundleDisplayName "$NN"; setp "$HP" CFBundleIdentifier "$ID"
  mv "$H" "$APP/Contents/Frameworks/$NN.app"
done

# files.json: every file under Resources with its size and SHA-256 (the installer's and the launcher's repair check)
python3 - "$R" "$V" "$ARCH" <<'PY'
import hashlib, json, os, sys
res, v, arch = sys.argv[1:4]
out = []
for d, _, fs in os.walk(res):
    for f in fs:
        p = os.path.join(d, f); rel = os.path.relpath(p, res).replace(os.sep, "/")
        if rel == "files.json": continue
        h = hashlib.sha256()
        with open(p, "rb") as fh:
            for b in iter(lambda: fh.read(1 << 20), b""): h.update(b)
        out.append({"path": rel, "size": os.path.getsize(p), "sha256": h.hexdigest()})
json.dump({"version": v, "platform": "darwin", "arch": arch, "files": out}, open(os.path.join(res, "files.json"), "w"))
print("files.json:", len(out), "files")
PY

echo "== signing (ad hoc: no Apple certificate yet)"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=1 "$APP"

echo "== packages"
cd "$W/out"
ditto -c -k --keepParent Virtuoz.app "$ROOT/Virtuoz-$V-mac-$ARCH.zip"
mkdir dmg; ditto Virtuoz.app dmg/Virtuoz.app; ln -s /Applications dmg/Applications
hdiutil create -volname "Virtuoz" -srcfolder dmg -ov -fs HFS+ -format UDBZ "$ROOT/Virtuoz-$V-Mac-$ARCH.dmg" >/dev/null
rm -rf dmg
ls -la "$ROOT"/Virtuoz-"$V"-*
