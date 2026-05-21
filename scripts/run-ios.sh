#!/usr/bin/env bash
# Run Expense Tracker on iOS Simulator (macOS + Xcode required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=load-env.sh
source "$ROOT/scripts/load-env.sh"

if ! command -v flutter >/dev/null; then
  echo "Flutter not found. Install: brew install --cask flutter"
  exit 1
fi

API_BASE_URL="${API_BASE_URL:-https://expensetracker-two-ashen.vercel.app}"

DART_DEFINES=(--dart-define="API_BASE_URL=$API_BASE_URL")
if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define="SUPABASE_URL=$SUPABASE_URL")
  DART_DEFINES+=(--dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")
fi
if [[ -n "${DEV_PRO_SECRET:-}" ]]; then
  DART_DEFINES+=(--dart-define="DEV_PRO_SECRET=$DEV_PRO_SECRET")
fi

flutter pub get
open -a Simulator 2>/dev/null || true
sleep 3

# Prefer booted iOS simulator (flutter run -d ios is not a valid device id)
IOS_DEVICE="$(
  flutter devices 2>/dev/null | grep -i simulator | grep -i ios | head -1 \
    | sed -n 's/.*• \([0-9A-F-]\{36\}\) •.*/\1/p'
)"
if [[ -z "$IOS_DEVICE" ]]; then
  echo "No iOS simulator found. Run: flutter emulators --launch apple_ios_simulator"
  exit 1
fi

echo "Running on simulator $IOS_DEVICE with API_BASE_URL=$API_BASE_URL"
"$ROOT/scripts/import-test-receipts-ios.sh" 2>/dev/null || true
flutter run -d "$IOS_DEVICE" "${DART_DEFINES[@]}"
