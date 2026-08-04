#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="$ROOT/scripts/kodama-doctor.sh"
BASE="$(mktemp -d)"
trap 'rm -rf "$BASE"' EXIT

pass=0
fail=0

assert_eq() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $description"
    pass=$((pass + 1))
  else
    echo "  FAIL: $description" >&2
    echo "    expected: $expected" >&2
    echo "    actual:   $actual" >&2
    fail=$((fail + 1))
  fi
}

assert_file() {
  local description="$1" path="$2"
  if [[ -f "$path" ]]; then
    echo "  PASS: $description"
    pass=$((pass + 1))
  else
    echo "  FAIL: $description ($path missing)" >&2
    fail=$((fail + 1))
  fi
}

# Agent and skill names matching the pack
AGENT_NAMES=(kodama kodama-scout kodama-scholar kodama-sage kodama-artist kodama-smith kodama-critic kodama-forge kodama-scribe)
SKILL_NAMES=(kodama-behavior kodama-verification kodama-constraints)

# Helper: set up a minimal healthy installation in KIRO_DIR
setup_healthy() {
  local kiro_dir="$1"
  local state_dir="$kiro_dir/kodama"
  local agents_dir="$kiro_dir/agents"
  local skills_dir="$kiro_dir/skills"

  mkdir -p "$agents_dir" "$skills_dir" "$state_dir"

  # Create minimal agent JSON files
  for name in "${AGENT_NAMES[@]}"; do
    printf '{"name":"%s","prompt":"x","model":"auto","tools":[],"allowedTools":[]}' "$name" \
      > "$agents_dir/$name.json"
  done

  # Create minimal skill SKILL.md files
  for name in "${SKILL_NAMES[@]}"; do
    mkdir -p "$skills_dir/$name"
    printf '%s\n' "---" "name: $name" "description: test" "---" "# $name" \
      > "$skills_dir/$name/SKILL.md"
  done

  # Copy scripts from repo to state dir and make executable
  for script in kodama.sh kodama-telemetry-emit.sh kodama-stats.sh check-update.sh update.sh; do
    cp "$ROOT/scripts/$script" "$state_dir/$script"
    chmod +x "$state_dir/$script"
  done

  # Generate manifest.json with correct SHA-256 hashes using python3
  python3 - "$kiro_dir" "$state_dir" <<'PY'
import hashlib
import json
import pathlib
import sys

kiro_dir = pathlib.Path(sys.argv[1])
state_dir = pathlib.Path(sys.argv[2])

agents = []
agent_hashes = {}
agents_dir = kiro_dir / "agents"
for f in sorted(agents_dir.glob("kodama*.json")):
    name = f.stem
    agents.append(name)
    agent_hashes[name] = hashlib.sha256(f.read_bytes()).hexdigest()

skills = []
skill_hashes = {}
skills_dir = kiro_dir / "skills"
for d in sorted(skills_dir.iterdir()):
    skill_file = d / "SKILL.md"
    if skill_file.exists():
        name = d.name
        skills.append(name)
        skill_hashes[name] = hashlib.sha256(skill_file.read_bytes()).hexdigest()

manifest = {
    "version": "0.0.0-test",
    "agents": agents,
    "agentHashes": agent_hashes,
    "skills": skills,
    "skillHashes": skill_hashes,
}

(state_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY
}

# Helper: run doctor with an isolated KIRO_DIR, suppress color codes
run_doctor() {
  local kiro_dir="$1"
  KIRO_DIR="$kiro_dir" bash "$DOCTOR" 2>&1 || true
}

run_doctor_exit() {
  local kiro_dir="$1"
  KIRO_DIR="$kiro_dir" bash "$DOCTOR" > /dev/null 2>&1
  echo $?
}

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: healthy installation — all checks pass'
# ──────────────────────────────────────────────────────────────────────────────
HEALTHY_DIR="$BASE/healthy"
mkdir -p "$HEALTHY_DIR"
setup_healthy "$HEALTHY_DIR"

output="$(run_doctor "$HEALTHY_DIR")"
exit_code="$(KIRO_DIR="$HEALTHY_DIR" bash "$DOCTOR" > /dev/null 2>&1; echo $?)"
assert_eq "healthy install exits 0" "0" "$exit_code"

has_all_passed="$([[ "$output" == *"All checks passed"* ]] && echo true || echo false)"
assert_eq "healthy install reports 'All checks passed'" "true" "$has_all_passed"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: missing manifest — doctor reports failure and exits non-zero'
# ──────────────────────────────────────────────────────────────────────────────
NOMANIFEST_DIR="$BASE/nomanifest"
mkdir -p "$NOMANIFEST_DIR"
setup_healthy "$NOMANIFEST_DIR"
rm -f "$NOMANIFEST_DIR/kodama/manifest.json"

output="$(run_doctor "$NOMANIFEST_DIR")"
exit_code="$(KIRO_DIR="$NOMANIFEST_DIR" bash "$DOCTOR" > /dev/null 2>&1; echo $?)"
assert_eq "missing manifest exits non-zero" "true" "$([[ "$exit_code" -ne 0 ]] && echo true || echo false)"

has_manifest_error="$([[ "$output" == *"Manifest not found"* ]] && echo true || echo false)"
assert_eq "missing manifest reports 'Manifest not found'" "true" "$has_manifest_error"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: hash mismatch — doctor reports modified agent'
# ──────────────────────────────────────────────────────────────────────────────
MISMATCH_DIR="$BASE/mismatch"
mkdir -p "$MISMATCH_DIR"
setup_healthy "$MISMATCH_DIR"

# Modify an agent file after manifest was created
printf '{"name":"kodama-scout","prompt":"tampered","model":"auto","tools":[],"allowedTools":[]}' \
  > "$MISMATCH_DIR/agents/kodama-scout.json"

output="$(run_doctor "$MISMATCH_DIR")"
has_mismatch="$([[ "$output" == *"kodama-scout"*"modified"* ]] && echo true || echo false)"
assert_eq "hash mismatch reports 'modified' for kodama-scout" "true" "$has_mismatch"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: missing script — doctor reports it missing'
# ──────────────────────────────────────────────────────────────────────────────
MISSINGSCRIPT_DIR="$BASE/missingscript"
mkdir -p "$MISSINGSCRIPT_DIR"
setup_healthy "$MISSINGSCRIPT_DIR"

# Remove one expected script
rm -f "$MISSINGSCRIPT_DIR/kodama/check-update.sh"

output="$(run_doctor "$MISSINGSCRIPT_DIR")"
has_missing_script="$([[ "$output" == *"check-update.sh"*"missing"* ]] && echo true || echo false)"
assert_eq "missing script reports 'check-update.sh — missing'" "true" "$has_missing_script"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: stale session — doctor warns about inactive session'
# ──────────────────────────────────────────────────────────────────────────────
STALE_DIR="$BASE/stale"
mkdir -p "$STALE_DIR"
setup_healthy "$STALE_DIR"

# Create a telemetry directory and a session file with old last_activity
mkdir -p "$STALE_DIR/kodama/telemetry"
python3 -c "
import json, time
from datetime import datetime, timezone, timedelta
old_time = datetime.now(timezone.utc) - timedelta(hours=2)
session = {
    'sid': 'test-stale-session',
    'started': old_time.isoformat(),
    'last_activity': old_time.isoformat()
}
with open('$STALE_DIR/kodama/telemetry/current-session.json', 'w') as f:
    json.dump(session, f)
"

output="$(run_doctor "$STALE_DIR")"
has_stale="$([[ "$output" == *"Stale session"* ]] && echo true || echo false)"
assert_eq "stale session warns 'Stale session detected'" "true" "$has_stale"

# ──────────────────────────────────────────────────────────────────────────────
printf '\nResults: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
