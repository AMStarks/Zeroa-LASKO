#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIM_ID="${SIM_ID:-E364B514-5715-442B-BD71-6C50AA95ED8C}"
OUT_DIR="$ROOT/app-store-screenshots/ipad-13"

mkdir -p "$OUT_DIR"

xcrun simctl shutdown "$SIM_ID" 2>/dev/null || true
xcrun simctl erase "$SIM_ID"
xcrun simctl boot "$SIM_ID"

cd "$ROOT"
xcodebuild test \
  -workspace Zeroa.xcworkspace \
  -scheme Zeroa \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -only-testing:ZeroaUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots

echo
echo "Captured screenshots:"
ls -la "$OUT_DIR"
