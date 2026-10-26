#!/usr/bin/env bash
#
# Wraps the SwiftPM release binary into build/MenuBarKit.app and signs it with the
# local certificate from setup-signing.sh (ad-hoc if it's missing).
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

APP=build/MenuBarKit.app
VERSION=0.1.0
IDENTITY="MenuBarKit Local Signing"

bin_dir=$(swift build -c release --show-bin-path)
commit=$(git rev-parse --verify -q HEAD || echo unknown)
build=$(git rev-list --count HEAD 2>/dev/null || echo 0)
branch=$(git branch --show-current 2>/dev/null); branch=${branch:-main}
repo=$(git remote get-url origin 2>/dev/null | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##' || true)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$bin_dir/MenuBarKit" "$APP/Contents/MacOS/MenuBarKit"
sed -e "s|__VERSION__|$VERSION|" \
    -e "s|__BUILD__|$build|" \
    -e "s|__COMMIT__|$commit|" \
    -e "s|__BRANCH__|$branch|" \
    -e "s|__REPO__|$repo|" \
    -e "s|__SOURCE_DIR__|$PWD|" \
    Support/Info.plist > "$APP/Contents/Info.plist"

if security find-certificate -c "$IDENTITY" >/dev/null 2>&1; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  echo "warning: '$IDENTITY' not found (run 'make signing'); signing ad-hoc." >&2
  echo "         macOS will ask for Spotify access again after every build." >&2
  codesign --force --sign - "$APP"
fi

echo "Built $APP ($(git rev-parse --short HEAD 2>/dev/null || echo dev))"
