#!/usr/bin/env bash
# stop: if providers.json or ProviderStore.swift changed, run verify_provider_logic.py.
set -euo pipefail

input=$(cat)
status=$(printf '%s' "$input" | jq -r '.status // "completed"')
loop_count=$(printf '%s' "$input" | jq -r '.loop_count // 0')

if [[ "$status" != "completed" ]]; then
  echo '{}'
  exit 0
fi

# Avoid infinite follow-up loops
if [[ "$loop_count" -gt 0 ]]; then
  # Still re-check once on loop 1; stop nagging after that if still failing
  if [[ "$loop_count" -ge 2 ]]; then
    echo '{}'
    exit 0
  fi
fi

changed=$(
  {
    git diff --name-only HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard 2>/dev/null || true
  } | sort -u
)

relevant=$(printf '%s\n' "$changed" | grep -E '(DogtorMyEyes/Data/providers\.json|DogtorMyEyes/Data/ProviderStore\.swift)$' || true)

if [[ -z "$relevant" ]]; then
  echo '{}'
  exit 0
fi

if ! python3 scripts/verify_provider_logic.py >/tmp/dogtor-verify-fixtures.out 2>&1; then
  detail=$(head -c 1200 /tmp/dogtor-verify-fixtures.out | tr '\n' ' ')
  msg=$(jq -n --arg d "$detail" --arg f "$relevant" \
    '{followup_message: ("providers.json or ProviderStore.swift changed but scripts/verify_provider_logic.py failed. Fix the fixture/filter parity, then re-run python3 scripts/verify_provider_logic.py.\n\nChanged:\n" + $f + "\n\nOutput:\n" + $d)}')
  printf '%s\n' "$msg"
  exit 0
fi

echo '{}'
exit 0
