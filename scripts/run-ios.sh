#!/usr/bin/env bash
# Run Expense Tracker on iOS Simulator (macOS + Xcode required).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null; then
  echo "Flutter not found. Install: brew install --cask flutter"
  exit 1
fi

API_BASE_URL="${API_BASE_URL:-https://expensetracker-two-ashen.vercel.app}"

flutter pub get
open -a Simulator 2>/dev/null || true
echo "Running with API_BASE_URL=$API_BASE_URL"
flutter run -d ios --dart-define="API_BASE_URL=$API_BASE_URL"
