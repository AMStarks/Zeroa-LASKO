#!/usr/bin/env bash
# Capture App Store screenshots for Zeroa (demo mode).
# Outputs under app-store-screenshots/{iphone-6.9,iphone-6.5,ipad-13}/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="${ROOT}/Zeroa.xcworkspace"
SCHEME="Zeroa"
DERIVED="${ROOT}/build/screenshot-derived"
OUT="${ROOT}/app-store-screenshots"

mkdir -p "$OUT/iphone-6.9" "$OUT/iphone-6.5" "$OUT/ipad-13" "$DERIVED"

udid_for() {
  local pattern="$1"
  xcrun simctl list devices available | grep -E "$pattern" | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1
}

run_on_device() {
  local name="$1"
  local udid="$2"
  local folder="$3"

  if [[ -z "$udid" ]]; then
    echo "Skipping $name — no simulator UDID"
    return 0
  fi

  echo "==> Booting $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b || true

  # Marker file is the reliable way to select the output folder from XCTest.
  printf '%s\n' "$folder" > "$OUT/.target-folder"
  mkdir -p "$OUT/$folder"
  find "$OUT/$folder" -name '*.png' -delete 2>/dev/null || true

  echo "==> UI tests on $name → $OUT/$folder"
  set +e
  xcodebuild test \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,id=$udid" \
    -only-testing:"ZeroaUITests/AppStoreScreenshotTests/testCaptureAppStoreScreenshots" \
    -derivedDataPath "$DERIVED" \
    -parallel-testing-enabled NO
  local status=$?
  set -e

  echo "xcodebuild exit=$status for $folder"
  find "$OUT/$folder" -name '*.png' -print 2>/dev/null || true
}

IPHONE69=$(udid_for 'Zeroa iPhone 16 Pro Max')
# Prefer Plus (6.7") for the App Store 6.5" slot; fall back to Wedge if missing.
IPHONE65=$(udid_for 'Zeroa iPhone 16 Plus')
[[ -z "${IPHONE65:-}" ]] && IPHONE65=$(udid_for 'Wedge iPhone')
IPAD13=$(udid_for 'Zeroa iPad Pro 13')

echo "Devices: 6.9=$IPHONE69 6.5=$IPHONE65 iPad=$IPAD13"
export ZEROA_SCREENSHOT_DIR="$OUT"

[[ -n "${IPHONE69:-}" ]] && run_on_device "iPhone 6.9" "$IPHONE69" "iphone-6.9"
[[ -n "${IPHONE65:-}" ]] && run_on_device "iPhone 6.5" "$IPHONE65" "iphone-6.5"
[[ -n "${IPAD13:-}" ]] && run_on_device "iPad 13" "$IPAD13" "ipad-13"

echo "Done. Review PNGs in $OUT"
ls -laR "$OUT" | head -100
