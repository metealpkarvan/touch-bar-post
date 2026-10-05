#!/bin/bash
set -euo pipefail
POST_PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
POST_VERSION="${1:-1.0.0}"
if [[ ! "$POST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Version must use MAJOR.MINOR.PATCH.' >&2
  exit 1
fi
cd "$POST_PROJECT"
mkdir -p dist
POST_STAGING="$(mktemp -d "$POST_PROJECT/dist/staging.XXXXXX")"
trap 'rm -rf "$POST_STAGING"' EXIT
for POST_ARCH in x86_64 arm64; do
  swift build --disable-sandbox -c release -j 2 --triple "$POST_ARCH-apple-macosx11.0" --scratch-path ".build/$POST_ARCH"
done
POST_INTEL="$(swift build --disable-sandbox -c release --triple x86_64-apple-macosx11.0 --scratch-path .build/x86_64 --show-bin-path)"
POST_ARM="$(swift build --disable-sandbox -c release --triple arm64-apple-macosx11.0 --scratch-path .build/arm64 --show-bin-path)"
POST_APP="$POST_STAGING/Şerit.app"
mkdir -p "$POST_APP/Contents/MacOS" "$POST_APP/Contents/Resources"
lipo -create "$POST_INTEL/TouchBarPost" "$POST_ARM/TouchBarPost" -output "$POST_APP/Contents/MacOS/TouchBarPost"
cp Resources/Info.plist "$POST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $POST_VERSION" "$POST_APP/Contents/Info.plist"
cp LICENSE "$POST_APP/Contents/Resources/LICENSE.txt"
swift scripts/make-icon.swift "$POST_STAGING/AppIcon.iconset"
iconutil -c icns "$POST_STAGING/AppIcon.iconset" -o "$POST_APP/Contents/Resources/AppIcon.icns"
rm -rf "$POST_STAGING/AppIcon.iconset"
codesign --force --sign - --timestamp=none "$POST_APP"
codesign --verify --strict "$POST_APP"
lipo "$POST_APP/Contents/MacOS/TouchBarPost" -verify_arch x86_64 arm64
"$POST_APP/Contents/MacOS/TouchBarPost" --smoke-test
cp README.md README.tr.md LICENSE CHANGELOG.md "$POST_STAGING/"
cp -R docs "$POST_STAGING/docs"
POST_ZIP="TouchBarPost-v$POST_VERSION-universal.zip"
rm -f "dist/$POST_ZIP"
python3 scripts/archive.py "$POST_STAGING" "dist/$POST_ZIP"
(cd dist && shasum -a 256 "$POST_ZIP" > SHA256SUMS.txt)
echo "Packaged: $POST_PROJECT/dist/$POST_ZIP"
lipo -archs "$POST_APP/Contents/MacOS/TouchBarPost"
