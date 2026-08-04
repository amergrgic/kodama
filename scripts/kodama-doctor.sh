#!/usr/bin/env bash
# kodama doctor — diagnostic health-check for the kodama agent pack.
# Purely read-only: no writes, no network calls, no side effects.
set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

KIRO_DIR="${KIRO_DIR:-$HOME/.kiro}"
STATE_DIR="$KIRO_DIR/kodama"
MANIFEST="$STATE_DIR/manifest.json"

ISSUES=0

pass()    { printf '  %b✓%b %b\n' "$GREEN" "$RESET" "$1"; }
fail_check() { printf '  %b✗%b %b\n' "$RED" "$RESET" "$1"; ISSUES=$((ISSUES + 1)); }
warn_check() { printf '  %b⚠%b %b\n' "$YELLOW" "$RESET" "$1"; }
section() { printf '\n%b━━ %s%b\n' "$BOLD" "$1" "$RESET"; }

printf '\n%b━━ Kodama Doctor ━━%b\n' "$BOLD" "$RESET"

# ---------------------------------------------------------------------------
# 1. kiro-cli exists
# ---------------------------------------------------------------------------
section "Prerequisites"

if command -v kiro-cli >/dev/null 2>&1; then
  kiro_version="$(kiro-cli --version 2>/dev/null || echo "unknown")"
  pass "kiro-cli found ($kiro_version)"
else
  fail_check "kiro-cli not found in PATH"
fi

# ---------------------------------------------------------------------------
# 2. python3 exists
# ---------------------------------------------------------------------------
if command -v python3 >/dev/null 2>&1; then
  py_version="$(python3 --version 2>/dev/null | awk '{print $2}')"
  pass "python3 found ($py_version)"
else
  fail_check "python3 not found in PATH"
fi

# ---------------------------------------------------------------------------
# 3. Manifest exists and is valid JSON
# ---------------------------------------------------------------------------
section "Manifest"

if [[ ! -f "$MANIFEST" ]]; then
  fail_check "Manifest not found at $MANIFEST"
  printf '\n  Cannot continue without manifest. Run: kodama update\n\n'
  exit 1
fi

manifest_valid="$(python3 -c "
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
    print(data.get('version', 'unknown'))
except Exception as e:
    print('INVALID: ' + str(e))
    sys.exit(1)
" "$MANIFEST" 2>&1)" || true

if [[ "$manifest_valid" == INVALID* ]]; then
  fail_check "Manifest is not valid JSON: $manifest_valid"
  printf '\n  Cannot continue with invalid manifest. Run: kodama update\n\n'
  exit 1
else
  pass "Manifest valid (version $manifest_valid)"
fi

# ---------------------------------------------------------------------------
# 4. Agent hashes match
# ---------------------------------------------------------------------------
section "Agent integrity"

while IFS='|' read -r status name detail; do
  case "$status" in
    OK)       pass "$name" ;;
    MISSING)  fail_check "$name — file missing: $detail" ;;
    MISMATCH) warn_check "$name — modified ($detail)" ;;
  esac
done < <(python3 - "$MANIFEST" "$KIRO_DIR" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
kiro_dir = pathlib.Path(sys.argv[2])

with manifest_path.open(encoding="utf-8") as f:
    manifest = json.load(f)

agents = manifest.get("agents", [])
hashes = manifest.get("agentHashes", {})

for name in agents:
    expected = hashes.get(name, "")
    agent_file = kiro_dir / "agents" / f"{name}.json"
    if not agent_file.exists():
        print(f"MISSING|{name}|{agent_file}")
        continue
    actual = hashlib.sha256(agent_file.read_bytes()).hexdigest()
    if actual == expected:
        print(f"OK|{name}|")
    else:
        print(f"MISMATCH|{name}|expected {expected[:12]}… got {actual[:12]}…")
PY
)

# ---------------------------------------------------------------------------
# 5. Skill hashes match
# ---------------------------------------------------------------------------
section "Skill integrity"

while IFS='|' read -r status name detail; do
  case "$status" in
    OK)       pass "$name" ;;
    MISSING)  fail_check "$name — file missing: $detail" ;;
    MISMATCH) warn_check "$name — modified ($detail)" ;;
  esac
done < <(python3 - "$MANIFEST" "$KIRO_DIR" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
kiro_dir = pathlib.Path(sys.argv[2])

with manifest_path.open(encoding="utf-8") as f:
    manifest = json.load(f)

skills = manifest.get("skills", [])
hashes = manifest.get("skillHashes", {})

for name in skills:
    expected = hashes.get(name, "")
    skill_file = kiro_dir / "skills" / name / "SKILL.md"
    if not skill_file.exists():
        print(f"MISSING|{name}|{skill_file}")
        continue
    actual = hashlib.sha256(skill_file.read_bytes()).hexdigest()
    if actual == expected:
        print(f"OK|{name}|")
    else:
        print(f"MISMATCH|{name}|expected {expected[:12]}… got {actual[:12]}…")
PY
)

# ---------------------------------------------------------------------------
# 6. Scripts present and executable
# ---------------------------------------------------------------------------
section "Scripts"

EXPECTED_SCRIPTS=(kodama.sh kodama-telemetry-emit.sh kodama-stats.sh check-update.sh update.sh)
for script in "${EXPECTED_SCRIPTS[@]}"; do
  script_path="$STATE_DIR/$script"
  if [[ ! -f "$script_path" ]]; then
    fail_check "$script — missing"
  elif [[ ! -x "$script_path" ]]; then
    fail_check "$script — not executable"
  else
    pass "$script"
  fi
done

# ---------------------------------------------------------------------------
# 7. Shell alias check
# ---------------------------------------------------------------------------
section "Shell alias"

ALIAS_LINE='alias kodama="$HOME/.kiro/kodama/kodama.sh"'
OLD_ALIAS='alias kodama="kiro-cli chat --agent kodama"'
SHELL_PROFILE=""

case "${SHELL:-}" in
  */zsh)  SHELL_PROFILE="$HOME/.zshrc" ;;
  */bash)
    if [[ -f "$HOME/.bash_profile" ]]; then
      SHELL_PROFILE="$HOME/.bash_profile"
    else
      SHELL_PROFILE="$HOME/.bashrc"
    fi
    ;;
  */fish) SHELL_PROFILE="$HOME/.config/fish/config.fish" ;;
esac

if [[ -z "$SHELL_PROFILE" ]]; then
  warn_check "Could not detect shell profile"
elif [[ ! -f "$SHELL_PROFILE" ]]; then
  warn_check "Shell profile not found: $SHELL_PROFILE"
elif grep -qF "$ALIAS_LINE" "$SHELL_PROFILE" 2>/dev/null; then
  pass "Alias points to wrapper in $SHELL_PROFILE"
elif grep -qF "$OLD_ALIAS" "$SHELL_PROFILE" 2>/dev/null; then
  warn_check "Alias uses old format in $SHELL_PROFILE — run: ~/.kiro/kodama/setup.sh --alias"
elif grep -qF 'alias kodama=' "$SHELL_PROFILE" 2>/dev/null; then
  warn_check "Alias exists but uses a custom target in $SHELL_PROFILE"
else
  warn_check "No 'kodama' alias found in $SHELL_PROFILE"
fi

# ---------------------------------------------------------------------------
# 8. Telemetry status
# ---------------------------------------------------------------------------
section "Telemetry"

TELEMETRY_DIR="$STATE_DIR/telemetry"
if [[ -f "$TELEMETRY_DIR/enabled" ]]; then
  pass "Collection: enabled"
else
  pass "Collection: disabled"
fi

if [[ -d "$TELEMETRY_DIR" ]]; then
  tele_size="$(du -sh "$TELEMETRY_DIR" 2>/dev/null | cut -f1 | xargs)"
  pass "Data size: ${tele_size:-0B}"
else
  pass "Data size: (no data directory)"
fi

# ---------------------------------------------------------------------------
# 9. Update check
# ---------------------------------------------------------------------------
section "Update check"
pass "Updates checked on every session start"

# ---------------------------------------------------------------------------
# 10. Stale session
# ---------------------------------------------------------------------------
section "Sessions"

CURRENT_SESSION="$TELEMETRY_DIR/current-session.json"
if [[ -f "$CURRENT_SESSION" ]]; then
  stale_result="$(python3 -c "
import json, sys, time
from datetime import datetime, timezone
try:
    with open(sys.argv[1], encoding='utf-8') as f:
        session = json.load(f)
    last_activity = session.get('last_activity', '')
    if not last_activity:
        print('NO_TIMESTAMP')
    else:
        if isinstance(last_activity, (int, float)):
            ts = last_activity
        else:
            dt = datetime.fromisoformat(last_activity)
            ts = dt.timestamp()
        age_min = (time.time() - ts) / 60
        if age_min > 30:
            print(f'STALE|{int(age_min)}m')
        else:
            print(f'ACTIVE|{int(age_min)}m')
except Exception:
    print('ERROR')
" "$CURRENT_SESSION")"
  case "$stale_result" in
    STALE*)
      age="${stale_result#STALE|}"
      warn_check "Stale session detected (inactive for $age)"
      ;;
    ACTIVE*)
      age="${stale_result#ACTIVE|}"
      pass "Active session (last activity ${age} ago)"
      ;;
    NO_TIMESTAMP)
      pass "Session file exists (no timestamp)"
      ;;
    *)
      warn_check "Could not parse current session file"
      ;;
  esac
else
  pass "No active session"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf '\n%b━━ Summary%b\n' "$BOLD" "$RESET"

if [[ $ISSUES -eq 0 ]]; then
  pass "All checks passed."
else
  fail_check "$ISSUES issue(s) found. Run 'kodama update' to repair."
fi
printf '\n'

exit "$ISSUES"
