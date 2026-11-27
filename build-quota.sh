#!/bin/sh
#
# Build the "Data Quota" edition of TrollSpeed and package it as a .tipa
#
# Usage: ./build-quota.sh [version]
# Requires macOS + Xcode (Command Line Tools). Cannot be built on Windows/Linux.
#
set -e

VERSION=${1:-1.11.17}

echo "==> Applying source patches"
if [ -d patches ]; then
    for p in patches/*.patch; do
        [ -e "$p" ] || continue
        echo "    applying $(basename "$p")"
        # Patches are applied in filename order, so each one sees the tree the
        # previous one left behind (hud-glass-background first, then
        # hud-shrink-width). A failure aborts the build instead of silently
        # shipping an unpatched app.
        git apply --whitespace=nowarn "$p"
    done
fi

echo "==> Building TrollSpeed with Xcode"

xcodebuild clean build archive \
    -scheme TrollSpeed \
    -project TrollSpeed.xcodeproj \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -archivePath TrollSpeed \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO

APP="TrollSpeed.xcarchive/Products/Applications/TrollSpeed.app"

if [ ! -d "$APP" ]; then
    echo "error: archive did not produce $APP"
    exit 1
fi

chmod 0644 Resources/Info.plist 2>/dev/null || true
chmod 0644 supports/Sandbox-Info.plist 2>/dev/null || true

echo "==> Packaging"

rm -rf build packages
mkdir -p build/Payload packages
cp -R "$APP" build/Payload/TrollSpeed.app
chmod 0644 build/Payload/TrollSpeed.app/Info.plist

# Ad-hoc signature carrying the TrollStore entitlements
codesign --force --sign - \
    --entitlements supports/entitlements.plist \
    --timestamp=none \
    build/Payload/TrollSpeed.app

OUT_NAME="TrollSpeed_DataQuota_${VERSION}.tipa"
( cd build && zip -qr "../packages/$OUT_NAME" Payload )

echo "==> Done: packages/$OUT_NAME"
