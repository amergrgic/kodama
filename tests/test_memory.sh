#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$(mktemp -d)"
trap 'rm -rf "$BASE"' EXIT

# Isolate KIRO_DIR so tests never touch real ~/.kiro
export KIRO_DIR="$BASE/kiro"
mkdir -p "$KIRO_DIR/kodama"

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

# Set up fake project with git repo
PROJECT="$BASE/my-project"
mkdir -p "$PROJECT"
git -C "$PROJECT" init --quiet
MEMORY_DIR="$PROJECT/.kiro/kodama/memory"

# Export project root (as the wrapper would)
export KODAMA_PROJECT_ROOT="$PROJECT"

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
echo "- Token: ghp_abcdef1234567890abcdef1234567890abcdef12" >> "$MEMORY_DIR/facts.md"
rc=0
memory audit || rc=$?
assert_eq "audit catches injected secret" "1" "$rc"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: compact'
# ──────────────────────────────────────────────────────────────────────────────
memory reset
for i in $(seq 1 55); do
  memory write --category facts --entry "Fact number $i about the project"
done
memory compact
remaining="$(grep -c '^- ' "$MEMORY_DIR/facts.md" || true)"
assert_eq "compact trims facts.md to <=50 entries" "true" \
  "$( [[ "$remaining" -le 50 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: multi-project isolation — writes go to correct project'
# ──────────────────────────────────────────────────────────────────────────────
PROJECT_B="$BASE/project-b"
mkdir -p "$PROJECT_B"
git -C "$PROJECT_B" init --quiet
MEMORY_DIR_B="$PROJECT_B/.kiro/kodama/memory"

# Write to project A
export KODAMA_PROJECT_ROOT="$PROJECT"
memory reset 2>/dev/null || true
memory write --category facts --entry "Project A uses React"

# Write to project B
export KODAMA_PROJECT_ROOT="$PROJECT_B"
memory write --category facts --entry "Project B uses Vue"

# Verify isolation
has_react_in_a="$(grep -q 'React' "$MEMORY_DIR/facts.md" 2>/dev/null && echo yes || echo no)"
has_vue_in_b="$(grep -q 'Vue' "$MEMORY_DIR_B/facts.md" 2>/dev/null && echo yes || echo no)"
has_vue_in_a="$(grep -q 'Vue' "$MEMORY_DIR/facts.md" 2>/dev/null && echo yes || echo no)"
assert_eq "project A has React, not Vue" "true" \
  "$( [[ "$has_react_in_a" == "yes" && "$has_vue_in_a" == "no" ]] && echo true || echo false )"
assert_eq "project B has Vue" "true" \
  "$( [[ "$has_vue_in_b" == "yes" ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '%s\n' 'Test: --project overrides without side effects'
# ──────────────────────────────────────────────────────────────────────────────
# Reset env to project A
export KODAMA_PROJECT_ROOT="$PROJECT"

# Write to project B via --project (should NOT affect subsequent commands)
memory write --project "$PROJECT_B" --category facts --entry "Written via --project flag"

# Next command without --project should target project A, not B
memory write --category facts --entry "This goes to project A"

has_flag_in_b="$(grep -c 'Written via --project flag' "$MEMORY_DIR_B/facts.md" 2>/dev/null || echo 0)"
has_a_entry="$(grep -c 'This goes to project A' "$MEMORY_DIR/facts.md" 2>/dev/null || echo 0)"
assert_eq "--project writes to specified project" "true" \
  "$( [[ "$has_flag_in_b" -gt 0 ]] && echo true || echo false )"
assert_eq "subsequent write targets env project (no side effect)" "true" \
  "$( [[ "$has_a_entry" -gt 0 ]] && echo true || echo false )"

# ──────────────────────────────────────────────────────────────────────────────
printf '\nResults: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
