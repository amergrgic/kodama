#!/usr/bin/env bash
# kodama update checker — designed to run as an agentSpawn hook.
# Outputs a notice ONLY if a newer version is available.
# Silent on success (up to date), silent on failure (network issues).
# Caches results for 24 hours to avoid slowing down every session.
set -euo pipefail

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/oh-my-kiro"
MANIFEST="$STATE_DIR/manifest.json"
CACHE_FILE="$STATE_DIR/.update-cache"
REPO="amergrgic/oh-my-kiro"
CACHE_MAX_AGE=86400  # 24 hours in seconds

# Bail silently if not installed
[[ -f "$MANIFEST" ]] || exit 0

# Read installed version from manifest
installed_version="$(python3 -c "
import json, sys
with open('$MANIFEST') as f:
    print(json.load(f).get('version', ''))
" 2>/dev/null)" || exit 0

[[ -n "$installed_version" ]] || exit 0

# Check cache freshness
if [[ -f "$CACHE_FILE" ]]; then
  cache_age=$(( $(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
  if [[ $cache_age -lt $CACHE_MAX_AGE ]]; then
    # Use cached result
    cached_version="$(cat "$CACHE_FILE")"
    if [[ -n "$cached_version" && "$cached_version" != "$installed_version" ]]; then
      echo "kodama update available: $installed_version → $cached_version. Run: ~/.kiro/oh-my-kiro/update.sh"
    fi
    exit 0
  fi
fi

# Fetch latest version from GitHub (timeout 3s to stay fast)
latest_version="$(curl -fsSL --max-time 3 \
  "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name','').lstrip('v'))" 2>/dev/null)" || exit 0

[[ -n "$latest_version" ]] || exit 0

# Cache the result
mkdir -p "$STATE_DIR"
printf '%s' "$latest_version" > "$CACHE_FILE"

# Only notify if versions differ
if [[ "$latest_version" != "$installed_version" ]]; then
  echo "kodama update available: $installed_version → $latest_version. Run: ~/.kiro/oh-my-kiro/update.sh"
fi
