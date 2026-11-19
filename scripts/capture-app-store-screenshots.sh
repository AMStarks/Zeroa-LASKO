#!/usr/bin/env bash
# Capture App Store screenshots for Zeroa (demo mode).
# Outputs under app-store-screenshots/{iphone-6.3,ipad-13}/
# Target sizes: iPhone 1206x2622, iPad 2064x2752.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="${ROOT}/Zeroa.xcworkspace"
SCHEME="Zeroa"
DERIVED="${ROOT}/build/screenshot-derived"
OUT="${ROOT}/app-store-screenshots"

mkdir -p "$OUT/iphone-6.3" "$OUT/ipad-13" "$DERIVED"

udid_for() {
  local pattern="$1"
  xcrun simctl list devices available | grep -E "$pattern" | head -1 \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1
}

ensure_iphone_pro() {
  local udid
  udid=$(udid_for 'Zeroa iPhone 16 Pro \(')
  if [[ -n "${udid:-}" ]]; then
    echo "$udid"
    return 0
  fi
  # Prefer native 6.3" Pro; fall back to Pro Max (then resize PNGs to 1206x2622).
  udid=$(udid_for 'Zeroa iPhone 16 Pro Max')
  if [[ -n "${udid:-}" ]]; then
    echo "$udid"
    return 0
  fi
  local created
  created=$(xcrun simctl create "Zeroa iPhone 16 Pro" \
    "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro" \
    "com.apple.CoreSimulator.SimRuntime.iOS-18-5" 2>/dev/null || true)
  if [[ "$created" =~ ^[0-9A-F-]{36}$ ]]; then
    echo "$created"
    return 0
  fi
  udid_for 'Zeroa iPhone 16 Pro'
}

resize_pngs() {
  local folder="$1"
  local w="$2"
  local h="$3"
  local dir="$OUT/$folder"
  [[ -d "$dir" ]] || return 0
  for f in "$dir"/*.png; do
    [[ -f "$f" ]] || continue
    sips -z "$h" "$w" "$f" --out "$f" >/dev/null
    echo "Resized $(basename "$f") → ${w}x${h}"
  done
}

run_on_device() {
  local name="$1"
  local udid="$2"
  local folder="$3"
  local width="$4"
  local height="$5"

  if [[ -z "$udid" ]]; then
    echo "Skipping $name — no simulator UDID"
    return 0
  fi

  echo "==> Booting $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b || true

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
  resize_pngs "$folder" "$width" "$height"
  find "$OUT/$folder" -name '*.png' -print 2>/dev/null || true
  for f in "$OUT/$folder"/*.png; do
    [[ -f "$f" ]] || continue
    sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | paste - -
  done
}

IPHONE63=$(ensure_iphone_pro)
IPAD13=$(udid_for 'Zeroa iPad Pro 13')

echo "Devices: 6.3=$IPHONE63 iPad=$IPAD13"
export ZEROA_SCREENSHOT_DIR="$OUT"

[[ -n "${IPHONE63:-}" ]] && run_on_device "iPhone 6.3" "$IPHONE63" "iphone-6.3" 1206 2622
[[ -n "${IPAD13:-}" ]] && run_on_device "iPad 13" "$IPAD13" "ipad-13" 2064 2752

echo "Done. Review PNGs in $OUT"
ls -laR "$OUT/iphone-6.3" "$OUT/ipad-13" 2>/dev/null | head -80
