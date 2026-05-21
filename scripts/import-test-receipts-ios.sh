#!/usr/bin/env bash
# Import workshop OCR test images into the booted iOS Simulator Photos app.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="$ROOT/test_resources"

for f in IMG_0060.HEIC IMG_0064.PNG; do
  if [[ ! -f "$RES/$f" ]]; then
    echo "Missing $RES/$f"
    exit 1
  fi
done

if ! xcrun simctl list devices booted 2>/dev/null | grep -q Booted; then
  echo "No booted iOS simulator. Run: open -a Simulator"
  exit 1
fi

xcrun simctl addmedia booted "$RES/IMG_0060.HEIC" "$RES/IMG_0064.PNG"
echo "Added to Photos (booted simulator):"
echo "  • IMG_0060 — 的士小票"
echo "  • IMG_0064 — 支付截图"
echo "App → 记一笔 → 相机 → 从相册选择"
