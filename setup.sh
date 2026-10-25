#!/usr/bin/env bash
# One-time setup: generates android/ and ios/, adds photo permissions, installs packages.
set -euo pipefail
cd "$(dirname "$0")"

FLUTTER="${FLUTTER:-flutter}"
if ! command -v "$FLUTTER" >/dev/null 2>&1; then
  FLUTTER="$HOME/development/flutter/bin/flutter"
fi
"$FLUTTER" --version

# `flutter create .` must not overwrite our code, so keep a backup.
BK=".setup_backup"
rm -rf "$BK" && mkdir -p "$BK"
cp -R lib "$BK/lib"
cp pubspec.yaml "$BK/pubspec.yaml"
cp -R test "$BK/test"

"$FLUTTER" create --org com.example --project-name photo_cleaner --platforms=android,ios .

rm -rf lib test
cp -R "$BK/lib" lib
cp -R "$BK/test" test
cp "$BK/pubspec.yaml" pubspec.yaml
rm -rf "$BK"

python3 patch_platforms.py
"$FLUTTER" pub get
"$FLUTTER" analyze || true
"$FLUTTER" test || true

echo
echo "Done. Connect a phone (or start a simulator) and run:  $FLUTTER run"
