#!/bin/zsh
# Builds build/dev/Rydd.app from the RyddApp SwiftPM product (menu bar only, ad-hoc signed).
#
#   scripts/dev-app.sh              # then: open build/dev/Rydd.app
#   open build/dev/Rydd.app --args --home /path/to/fixture   # point it at a test folder instead of ~
set -e
cd "${0:A:h}/.."
# Development build from the Swift package: unsandboxed and ad-hoc signed, with the `--home <dir>`
# test flags. For the shipping builds see scripts/build.sh, scripts/release.sh and scripts/appstore.sh.

swift build -c release --product RyddApp
app=build/dev/Rydd.app
rm -rf $app
mkdir -p build/dev $app/Contents/MacOS $app/Contents/Resources
cp .build/release/RyddApp $app/Contents/MacOS/Rydd
cp Design/AppIcon.icns $app/Contents/Resources/AppIcon.icns
cp -R Resources/*.lproj $app/Contents/Resources/

cat > $app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>Rydd</string>
    <key>CFBundleDevelopmentRegion</key>    <string>en</string>
    <key>CFBundleLocalizations</key>        <array><string>en</string><string>en-GB</string><string>zh-Hans</string><string>zh-Hant</string></array>
    <key>CFBundleDisplayName</key>          <string>Rydd</string>
    <key>CFBundleIdentifier</key>           <string>com.feiyangtang.Rydd.dev</string>
    <key>CFBundleExecutable</key>           <string>Rydd</string>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleShortVersionString</key>   <string>1.0</string>
    <key>CFBundleVersion</key>              <string>1</string>
    <key>LSMinimumSystemVersion</key>       <string>26.0</string>
    <key>LSUIElement</key>                  <true/>
    <key>LSApplicationCategoryType</key>    <string>public.app-category.productivity</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>Rydd reads file names to suggest where they belong. Everything stays on your Mac.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>Rydd reads the names of your folders to know where files belong. Everything stays on your Mac.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>Rydd reads file names to suggest where they belong. Everything stays on your Mac.</string>
</dict>
</plist>
PLIST

codesign --force --sign - $app
echo "built $app"
