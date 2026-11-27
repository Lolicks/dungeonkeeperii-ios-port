#!/usr/bin/env bash
# Produces an IPA only from a real .app produced by build-ios.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/output/DerivedData/Build/Products/Debug-iphoneos/DungeonKeeperII.app"
OUT="$ROOT/output/DungeonKeeperII.ipa"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: IPA packaging requires macOS. Nothing was built." >&2
  exit 2
fi
if [ ! -d "$APP" ]; then
  echo "ERROR: $APP not found. Run scripts/build-ios.sh first." >&2
  exit 2
fi
mkdir -p "$OUT/../Payload"
rm -rf "$OUT/../Payload" "$OUT"
cp -R "$APP" "$OUT/../Payload/DungeonKeeperII.app"
(cd "$OUT/.." && zip -qry "$OUT" Payload)
echo "Created $OUT"
