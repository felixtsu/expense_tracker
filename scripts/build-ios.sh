#!/usr/bin/env bash
# Build iOS release with optional API_BASE_URL baked in.
#
# Usage:
#   ./scripts/build-ios.sh
#   API_BASE_URL=https://your-api.vercel.app ./scripts/build-ios.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=load-env.sh
source "$ROOT/scripts/load-env.sh"

API_BASE_URL="${API_BASE_URL:-https://expensetracker-two-ashen.vercel.app}"

DART_DEFINES=(--dart-define="API_BASE_URL=$API_BASE_URL")
if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
  DART_DEFINES+=(--dart-define="SUPABASE_URL=$SUPABASE_URL")
  DART_DEFINES+=(--dart-define="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY")
fi
if [[ -n "${DEV_PRO_SECRET:-}" ]]; then
  DART_DEFINES+=(--dart-define="DEV_PRO_SECRET=$DEV_PRO_SECRET")
fi

echo "Building iOS with API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build ios --release --no-codesign "${DART_DEFINES[@]}"

echo "Done. Open ios/Runner.xcworkspace in Xcode to archive/sign."
