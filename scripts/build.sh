#!/bin/zsh
# Development build: regenerates the Xcode project from project.yml and builds a locally signed
# (sandboxed) copy into build/Rydd.app. For releases see scripts/release.sh (website) and
# scripts/appstore.sh (Mac App Store).
set -e
cd "$(dirname "$0")/.."

xcodegen generate --quiet
xcodebuild -project Rydd.xcodeproj -scheme Rydd -configuration Release \
    -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
    -quiet build

rm -rf build/Rydd.app
cp -R build/DerivedData/Build/Products/Release/Rydd.app build/
echo "Built build/Rydd.app"
