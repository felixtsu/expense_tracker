#!/usr/bin/env bash
# Source .env.local from repo root (if present). Used by run/build scripts.
# Usage: source "$(dirname "$0")/load-env.sh"
set -euo pipefail
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"
_ENV_FILE="$_ROOT/.env.local"
if [[ -f "$_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$_ENV_FILE"
  set +a
  echo "Loaded $_ENV_FILE"
fi
