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

# Set up fake project with git repo so project detection works
PROJECT="$BASE/my-project"
mkdir -p "$PROJECT"
git -C "$PROJECT" init --quiet
MEMORY_DIR="$PROJECT/.kiro/kodama/memory"

# Work inside the fake project
cd "$PROJECT"

# Helper to invoke the memory script
memory() {
  python3 "$ROOT/scripts/kodama-memory.py" "$@"
}

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: write basic entry'
# ──────────────────────────────────────────────────────────────────────────────
memory write --category facts --entry "Uses pytest for testing"
assert_file "facts.md exists after write" "$MEMORY_DIR/facts.md"
has_entry="$(grep -c 'Uses pytest for testing' "$MEMORY_DIR/facts.md" || true)"
assert_eq "facts.md contains the entry" "true" "$( [[ "$has_entry" -gt 0 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: privacy filter rejects secrets'
# ──────────────────────────────────────────────────────────────────────────────
before_size="$(wc -c < "$MEMORY_DIR/facts.md" | tr -d ' ')"
rc=0
memory write --category facts --entry "token ghp_abc123456789012345678901234567890123456" || rc=$?
assert_eq "secret write exits with code 1" "1" "$rc"
after_size="$(wc -c < "$MEMORY_DIR/facts.md" | tr -d ' ')"
assert_eq "file unchanged after rejected secret" "$before_size" "$after_size"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: privacy filter rejects .env paths'
# ──────────────────────────────────────────────────────────────────────────────
rc=0
memory write --category facts --entry "Config is in .env.production file" || rc=$?
assert_eq "entry with .env path rejected" "1" "$rc"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: context generation'
# ──────────────────────────────────────────────────────────────────────────────
memory write --category conventions --entry "Use camelCase for JS variables"
memory context
assert_file "context.md exists" "$MEMORY_DIR/context.md"
has_facts="$(grep -c 'pytest' "$MEMORY_DIR/context.md" || true)"
has_conventions="$(grep -c 'camelCase' "$MEMORY_DIR/context.md" || true)"
assert_eq "context.md includes facts and conventions" "true" \
  "$( [[ "$has_facts" -gt 0 && "$has_conventions" -gt 0 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: context budget'
# ──────────────────────────────────────────────────────────────────────────────
# Write a lot of entries exceeding 4KB
for i in $(seq 1 100); do
  memory write --category decisions --entry "Decision number $i: we chose option alpha because of reason beta gamma delta epsilon zeta eta theta"
done
memory context
context_size="$(wc -c < "$MEMORY_DIR/context.md" | tr -d ' ')"
assert_eq "context.md is within 4096 byte budget" "true" \
  "$( [[ "$context_size" -le 4096 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: show'
# ──────────────────────────────────────────────────────────────────────────────
show_output="$(memory show)"
has_show_content="$(echo "$show_output" | grep -c 'pytest' || true)"
assert_eq "show output contains written entries" "true" \
  "$( [[ "$has_show_content" -gt 0 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: reset'
# ──────────────────────────────────────────────────────────────────────────────
memory reset
assert_eq "memory dir removed after reset" "false" \
  "$( [[ -d "$MEMORY_DIR" ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: audit clean'
# ──────────────────────────────────────────────────────────────────────────────
memory write --category facts --entry "Build tool is Make"
memory write --category conventions --entry "Indent with 2 spaces"
rc=0
memory audit || rc=$?
assert_eq "audit passes on clean entries" "0" "$rc"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: audit catches secrets'
# ──────────────────────────────────────────────────────────────────────────────
# Manually inject a secret-looking string into a memory file
echo "- Token: ghp_abcdef1234567890abcdef1234567890abcdef12" >> "$MEMORY_DIR/facts.md"
rc=0
memory audit || rc=$?
assert_eq "audit catches injected secret" "1" "$rc"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: compact'
# ──────────────────────────────────────────────────────────────────────────────
# Reset and write >50 entries to facts
memory reset
for i in $(seq 1 55); do
  memory write --category facts --entry "Fact number $i about the project"
done
memory compact
remaining="$(grep -c '^- ' "$MEMORY_DIR/facts.md" || true)"
assert_eq "compact trims facts.md to <=50 entries" "true" \
  "$( [[ "$remaining" -le 50 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '\nResults: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
