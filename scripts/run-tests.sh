#!/usr/bin/env bash
# Runs the real OpenKeeper test suite via the Gradle wrapper.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/OpenKeeper"
./gradlew test --no-daemon
echo "Test results: OpenKeeper/build/reports/tests/test/index.html"
