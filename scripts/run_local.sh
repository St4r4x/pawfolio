#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
eval "$(supabase status -o env | sed -E 's/^([A-Z_]+)=/export \1=/')"
flutter run -d "${1:-emulator-5554}" \
  --dart-define=SUPABASE_URL="http://10.0.2.2:54321" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"
