#!/bin/bash
# Builds build/Kibble.app (universal, ad-hoc signed). Pass --dmg to also make build/Kibble.dmg.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
APP="build/Kibble.app"

# Regenerate sprites when Pillow is around; the generated files are committed.
if python3 -c "import PIL" 2>/dev/null; then python3 tools/sprites.py >/dev/null; fi
swift build -c release --arch arm64 --arch x86_64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Kibble" "$APP/Contents/MacOS/Kibble"
cp Resources/menubar.png Resources/menubar@2x.png "$APP/Contents/Resources/"
# Local-only HD artwork (git-ignored), if it has been built.
if [[ -d Resources/HD ]]; then cp -R Resources/HD "$APP/Contents/Resources/HD"; fi
iconutil -c icns Resources/AppIcon/Kibble.iconset -o "$APP/Contents/Resources/Kibble.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Kibble</string>
    <key>CFBundleDisplayName</key><string>Kibble</string>
    <key>CFBundleIdentifier</key><string>dev.kibble.app</string>
    <key>CFBundleExecutable</key><string>Kibble</string>
    <key>CFBundleIconFile</key><string>Kibble</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
    <key>NSAppleEventsUsageDescription</key><string>Kibble brings the Terminal or iTerm tab running a task to the front when you click it.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--dmg" ]]; then
    rm -f build/Kibble.dmg
    STAGE=$(mktemp -d)
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname Kibble -srcfolder "$STAGE" -ov -format UDZO build/Kibble.dmg >/dev/null
    rm -rf "$STAGE"
    echo "Built build/Kibble.dmg"
fi
