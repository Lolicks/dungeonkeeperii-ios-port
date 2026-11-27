#!/usr/bin/env bash
# Honest iOS build entry point. Fails clearly unless a real macOS/Xcode toolchain exists.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: iOS builds require macOS + Xcode. Current host: $(uname -s)" >&2
  echo "No IPA will be produced. See IOS_PORT_TECHNICAL_AUDIT.md section 6." >&2
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERROR: xcodebuild not found. Install Xcode." >&2
  exit 2
fi
if [ ! -d "$ROOT/ios/DungeonKeeperII.xcodeproj" ]; then
  echo "ERROR: Native iOS project has not been created yet." >&2
  exit 2
fi
xcodebuild -project "$ROOT/ios/DungeonKeeperII.xcodeproj" \
  -scheme DungeonKeeperII -configuration Debug \
  -sdk iphoneos -arch arm64 CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath "$ROOT/output/DerivedData" build
