#!/usr/bin/env bash
#
# One-shot install from this checkout: signing certificate (once), release build,
# copy to /Applications, launch. Called from the dotfiles bootstrap.
#
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Command Line Tools are missing — run 'xcode-select --install' and try again." >&2
  exit 1
fi

scripts/setup-signing.sh
make install
