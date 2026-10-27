#!/usr/bin/env bash
# afterFileEdit: format Swift files with xcrun swift-format when available.
set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.file_path // .path // empty')

if [[ -z "$file_path" || "$file_path" != *.swift ]]; then
  echo '{}'
  exit 0
fi

if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

if [[ -f "$file_path" ]]; then
  xcrun swift-format format -i "$file_path" 2>/dev/null || true
fi

echo '{}'
exit 0
