#!/usr/bin/env bash
# Build release APK with optional API_BASE_URL baked in.
#
# Usage:
#   ./scripts/build-apk.sh
#   API_BASE_URL=https://your-api.vercel.app ./scripts/build-apk.sh
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

echo "Building APK with API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build apk --release "${DART_DEFINES[@]}"

echo "APK: build/app/outputs/flutter-apk/app-release.apk"
