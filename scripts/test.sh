#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
xcodebuild -project UsageOrb.xcodeproj -scheme UsageOrb \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  test
