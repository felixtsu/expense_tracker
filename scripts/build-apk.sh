#!/usr/bin/env bash
# Build release APK with optional API_BASE_URL baked in.
#
# Usage:
#   ./scripts/build-apk.sh
#   API_BASE_URL=https://your-api.vercel.app ./scripts/build-apk.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://expensetracker-two-ashen.vercel.app}"

echo "Building APK with API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"

echo "APK: build/app/outputs/flutter-apk/app-release.apk"
