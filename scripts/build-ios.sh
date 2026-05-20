#!/usr/bin/env bash
# Build iOS release with optional API_BASE_URL baked in.
#
# Usage:
#   ./scripts/build-ios.sh
#   API_BASE_URL=https://your-api.vercel.app ./scripts/build-ios.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://expensetracker-two-ashen.vercel.app}"

echo "Building iOS with API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build ios --release --no-codesign --dart-define="API_BASE_URL=$API_BASE_URL"

echo "Done. Open ios/Runner.xcworkspace in Xcode to archive/sign."
