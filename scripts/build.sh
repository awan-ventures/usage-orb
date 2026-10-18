#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# The checked-in project builds without XcodeGen. Regenerate after file changes.
if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi
xcodebuild -project UsageOrb.xcodeproj -scheme UsageOrb \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
printf '\nBuilt: %s/build/Build/Products/Release/UsageOrb.app\n' "$PWD"
