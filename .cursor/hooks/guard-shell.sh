#!/usr/bin/env bash
# beforeShellExecution: deny force-push to main, broad rm -rf; ask before simctl erase.
set -euo pipefail

input=$(cat)
command=$(printf '%s' "$input" | jq -r '.command // empty')

deny() {
  local user_msg="$1"
  local agent_msg="$2"
  jq -n --arg u "$user_msg" --arg a "$agent_msg" \
    '{permission:"deny", user_message:$u, agent_message:$a}'
  exit 0
}

ask() {
  local user_msg="$1"
  local agent_msg="$2"
  jq -n --arg u "$user_msg" --arg a "$agent_msg" \
    '{permission:"ask", user_message:$u, agent_message:$a}'
  exit 0
}

# Force push to main/master
if echo "$command" | grep -Eq 'git[[:space:]]+push[[:space:]]+.*--force|--force[[:space:]].*git[[:space:]]+push'; then
  if echo "$command" | grep -Eq '(^|[[:space:]])(main|master)([[:space:]]|$)|\s+HEAD:.*(main|master)'; then
    deny \
      "Blocked: force-push to main/master is not allowed in this repo." \
      "A hook denied force-pushing to main/master. Push a feature branch or ask the user to force-push explicitly with a safer flow."
  fi
fi

# Broad recursive deletes outside build/ and artifacts/
if echo "$command" | grep -Eq '\brm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*|--recursive)'; then
  # Allow only if every path argument is under build/ or artifacts/
  # Heuristic: deny if command mentions paths outside those dirs or uses . / ~
  if echo "$command" | grep -Eq '(^|[[:space:]])(/|~|\.\.)|rm[[:space:]].*[[:space:]]\.([[:space:]]|$)'; then
    deny \
      "Blocked: recursive delete outside build/ or artifacts/." \
      "A hook denied a broad rm -rf. Limit deletes to build/ or artifacts/, or ask the user to run it manually."
  fi
  # Paths that are not clearly build/ or artifacts/
  if ! echo "$command" | grep -Eq 'rm[[:space:]].*(build/|artifacts/)'; then
    deny \
      "Blocked: recursive delete must target build/ or artifacts/ only." \
      "A hook denied rm -rf because the path is not under build/ or artifacts/."
  fi
fi

# Simulator erase is destructive — ask first
if echo "$command" | grep -Eq 'xcrun[[:space:]]+simctl[[:space:]]+erase|\bsimctl[[:space:]]+erase\b'; then
  ask \
    "This will erase an iOS Simulator. Confirm before continuing." \
    "A hook flagged simctl erase. Explain why a wipe is needed or use a fresh simulator device instead."
fi

echo '{"permission":"allow"}'
exit 0
