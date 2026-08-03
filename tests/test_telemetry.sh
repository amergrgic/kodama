#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

assert_no_file() {
  local description="$1" path="$2"
  if [[ ! -f "$path" ]]; then
    echo "  PASS: $description"
    pass=$((pass + 1))
  else
    echo "  FAIL: $description ($path should not exist)" >&2
    fail=$((fail + 1))
  fi
}

# Set up isolated KIRO_DIR so nothing touches real ~/.kiro
KIRO_DIR="$BASE/kiro"
export KIRO_DIR
STATE_DIR="$KIRO_DIR/kodama"
TELEMETRY_DIR="$STATE_DIR/telemetry"
EVENTS_LOG="$TELEMETRY_DIR/events.jsonl"
SENTINEL="$TELEMETRY_DIR/enabled"

mkdir -p "$STATE_DIR"

# Copy telemetry scripts to STATE_DIR (as install would place them)
cp "$ROOT/scripts/kodama-telemetry.py" "$STATE_DIR/kodama-telemetry.py"
cp "$ROOT/scripts/kodama-telemetry-emit.sh" "$STATE_DIR/kodama-telemetry-emit.sh"
cp "$ROOT/scripts/kodama-stats.sh" "$STATE_DIR/kodama-stats.sh"
chmod +x "$STATE_DIR/kodama-telemetry-emit.sh" "$STATE_DIR/kodama-stats.sh"

# Helper: run the telemetry Python script
telemetry() {
  python3 "$STATE_DIR/kodama-telemetry.py" "$@"
}

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: emit when disabled — no sentinel file'
# ──────────────────────────────────────────────────────────────────────────────
rm -f "$SENTINEL"
rm -f "$EVENTS_LOG"
# The emit script should exit 0 and write nothing
"$STATE_DIR/kodama-telemetry-emit.sh" agent_spawn kodama-scout || true
assert_no_file "no events.jsonl when disabled" "$EVENTS_LOG"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: emit when enabled — events.jsonl created with valid JSONL'
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$TELEMETRY_DIR"
touch "$SENTINEL"
rm -f "$EVENTS_LOG"
rm -f "$TELEMETRY_DIR/current-session.json"
telemetry emit agent_spawn kodama-scout
assert_file "events.jsonl created after emit" "$EVENTS_LOG"
# Every line should be valid JSON
valid_jsonl="$(python3 -c "
import json, sys
lines = open(sys.argv[1], encoding='utf-8').read().splitlines()
assert len(lines) > 0, 'empty file'
for line in lines:
    json.loads(line)
print('true')
" "$EVENTS_LOG" 2>/dev/null || echo false)"
assert_eq "events.jsonl contains valid JSONL" "true" "$valid_jsonl"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: session management — multiple emits share session ID'
# ──────────────────────────────────────────────────────────────────────────────
rm -f "$EVENTS_LOG" "$TELEMETRY_DIR/current-session.json"
telemetry emit agent_spawn kodama
telemetry emit delegation kodama-smith
telemetry emit agent_spawn kodama-critic
session_ids="$(python3 -c "
import json, sys
sids = set()
for line in open(sys.argv[1], encoding='utf-8'):
    ev = json.loads(line.strip())
    sids.add(ev.get('sid', ''))
print(len(sids))
" "$EVENTS_LOG")"
assert_eq "all emits within session share one session ID" "1" "$session_ids"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: stats query — returns valid JSON with expected structure'
# ──────────────────────────────────────────────────────────────────────────────
query_output="$(telemetry query --json)"
valid_structure="$(python3 -c "
import json, sys
stats = json.loads(sys.argv[1])
assert 'sessions' in stats, 'missing sessions key'
assert 'agents' in stats, 'missing agents key'
assert 'delegations' in stats, 'missing delegations key'
assert 'errors' in stats, 'missing errors key'
assert 'period_days' in stats, 'missing period_days key'
s = stats['sessions']
assert 'total' in s, 'missing sessions.total'
assert 'completed' in s, 'missing sessions.completed'
assert 'abandoned' in s, 'missing sessions.abandoned'
print('true')
" "$query_output" 2>/dev/null || echo false)"
assert_eq "query returns valid JSON with expected structure" "true" "$valid_structure"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: stats query empty — returns null when no events'
# ──────────────────────────────────────────────────────────────────────────────
rm -f "$EVENTS_LOG" "$TELEMETRY_DIR"/events.jsonl.* "$TELEMETRY_DIR/current-session.json"
empty_output="$(telemetry query --json)"
assert_eq "query returns null with no events" "null" "$empty_output"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: enable/disable — kodama-stats.sh manages sentinel'
# ──────────────────────────────────────────────────────────────────────────────
rm -f "$SENTINEL"
"$STATE_DIR/kodama-stats.sh" --enable > /dev/null
assert_file "--enable creates sentinel" "$SENTINEL"
"$STATE_DIR/kodama-stats.sh" --disable > /dev/null
assert_no_file "--disable removes sentinel" "$SENTINEL"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: rotation — oversized events.jsonl is rotated on emit'
# ──────────────────────────────────────────────────────────────────────────────
mkdir -p "$TELEMETRY_DIR"
touch "$SENTINEL"
rm -f "$EVENTS_LOG" "$TELEMETRY_DIR"/events.jsonl.* "$TELEMETRY_DIR/current-session.json"
# Create an oversized events.jsonl (> 1 MB)
python3 -c "
import json
line = json.dumps({'ts':'2026-01-01T00:00:00+00:00','event':'agent_spawn','sid':'deadbeef','agent':'kodama'})
# Write ~1.1 MB worth of lines
count = (1_100_000 // (len(line) + 1)) + 1
with open('$EVENTS_LOG', 'w') as f:
    for _ in range(count):
        f.write(line + '\n')
"
size_before="$(wc -c < "$EVENTS_LOG" | tr -d ' ')"
telemetry emit agent_spawn kodama
# After rotation, the primary log should be much smaller (just the new events)
size_after="$(wc -c < "$EVENTS_LOG" | tr -d ' ')"
rotated_exists="$([[ -f "$TELEMETRY_DIR/events.jsonl.1" ]] && echo true || echo false)"
assert_eq "rotation creates events.jsonl.1" "true" "$rotated_exists"
assert_eq "primary log is smaller after rotation" "true" "$( [[ "$size_after" -lt "$size_before" ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: emit script — kodama-telemetry-emit.sh works directly'
# ──────────────────────────────────────────────────────────────────────────────
rm -f "$EVENTS_LOG" "$TELEMETRY_DIR"/events.jsonl.* "$TELEMETRY_DIR/current-session.json"
touch "$SENTINEL"
"$STATE_DIR/kodama-telemetry-emit.sh" agent_spawn kodama-forge
assert_file "emit script creates events.jsonl" "$EVENTS_LOG"
has_forge="$(grep -c 'kodama-forge' "$EVENTS_LOG" || true)"
assert_eq "emit script records the correct agent" "true" "$( [[ "$has_forge" -gt 0 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '\nResults: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
