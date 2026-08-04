#!/usr/bin/env bash
# kodama update checker — designed to run as an agentSpawn hook.
# Outputs a notice ONLY if a newer version is available.
# Silent on success (up to date), silent on failure (network issues).
set -euo pipefail

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/kodama"
MANIFEST="$STATE_DIR/manifest.json"
REPO="amergrgic/kodama"

# Bail silently if not installed
[[ -f "$MANIFEST" ]] || exit 0

# Read installed version from manifest
installed_version="$(python3 -c "
import json, sys
with open('$MANIFEST') as f:
    print(json.load(f).get('version', ''))
" 2>/dev/null)" || exit 0

[[ -n "$installed_version" ]] || exit 0

# Fetch latest version from GitHub (timeout 3s to stay fast)
latest_version="$(curl -fsSL --max-time 3 \
  "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name','').lstrip('v'))" 2>/dev/null)" || exit 0

[[ -n "$latest_version" ]] || exit 0

# Only notify if versions differ
if [[ "$latest_version" != "$installed_version" ]]; then
  echo "kodama update available: $installed_version → $latest_version. Run: kodama update"
fi
