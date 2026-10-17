#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build_temp"
DMG_STAGING="$PROJECT_DIR/dmg_staging"
OUTPUT_DMG="$PROJECT_DIR/Lookt.dmg"

echo "==> Building Lookt (Release configuration)..."
xcodebuild -project "$PROJECT_DIR/Lookt.xcodeproj" \
           -scheme "Lookt" \
           -configuration "Release" \
           -derivedDataPath "$BUILD_DIR" \
           build -quiet

APP_PATH="$BUILD_DIR/Build/Products/Release/Lookt.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Lookt.app not found at $APP_PATH"
    exit 1
fi

echo "==> Preparing DMG staging folder..."
rm -rf "$DMG_STAGING" "$OUTPUT_DMG"
mkdir -p "$DMG_STAGING"

cp -R "$APP_PATH" "$DMG_STAGING/Lookt.app"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating Lookt.dmg..."
hdiutil create -volname "Lookt Installer" \
               -srcfolder "$DMG_STAGING" \
               -ov \
               -format UDZO \
               "$OUTPUT_DMG"

echo "==> Cleaning up temporary artifacts..."
rm -rf "$BUILD_DIR" "$DMG_STAGING"

echo "==> Lookt.dmg successfully created at: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
