#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT/setup.sh"
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

make_fake_kiro() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/kiro-cli" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

state="${FAKE_KIRO_STATE:?FAKE_KIRO_STATE must be set}"
case "${1:-}" in
  agent)
    [[ "${2:-}" == "validate" && "${3:-}" == "--path" ]] || exit 64
    python3 - "${4:?missing config path}" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
config = json.loads(path.read_text(encoding="utf-8"))
assert config["name"] == path.stem
assert config["prompt"]
assert "__OMK_PROMPT_DIR__" not in config["prompt"]
assert set(config.get("allowedTools", [])) <= set(config.get("tools", []))
assert all("__OMK_SKILLS_DIR__" not in resource for resource in config.get("resources", []))
PY
    ;;
  settings)
    if [[ "${2:-}" == "--delete" ]]; then
      rm -f "$state"
    elif [[ $# -eq 2 ]]; then
      [[ -f "$state" ]] && cat "$state"
    elif [[ $# -eq 3 ]]; then
      printf '%s' "$3" > "$state"
    else
      exit 64
    fi
    ;;
  *) exit 64 ;;
esac
SH
  chmod +x "$bin_dir/kiro-cli"
}

run_installer() {
  local home="$1"
  shift
  HOME="$home" KIRO_DIR="$home/.kiro" FAKE_KIRO_STATE="$home/default-agent" \
    PATH="$BASE/bin:$PATH" bash "$INSTALLER" "$@"
}

mkdir -p "$BASE/bin"
make_fake_kiro "$BASE/bin"

HOME_DIR="$BASE/home"
mkdir -p "$HOME_DIR/.kiro/agents"
printf '%s\n' '{"name":"sisyphus","prompt":"foreign"}' > "$HOME_DIR/.kiro/agents/sisyphus.json"
printf '%s' 'legacy-agent' > "$HOME_DIR/default-agent"

printf '%s\n' 'Test: dry run does not write files'
run_installer "$HOME_DIR" --dry-run > "$BASE/dry-run.log"
assert_eq "dry run creates no Orpheus config" "false" "$([[ -e "$HOME_DIR/.kiro/agents/orpheus.json" ]] && echo true || echo false)"
assert_eq "dry run creates no managed skill" "false" "$([[ -e "$HOME_DIR/.kiro/skills/omk-behavior/SKILL.md" ]] && echo true || echo false)"
assert_file "foreign agent survives dry run" "$HOME_DIR/.kiro/agents/sisyphus.json"

printf '%s\n' 'Test: install owns only public-pack files'
run_installer "$HOME_DIR" > "$BASE/install.log"
for name in orpheus omk-explorer omk-librarian omk-oracle omk-designer omk-fixer omk-reviewer; do
  assert_file "installs $name" "$HOME_DIR/.kiro/agents/$name.json"
done
for name in omk-behavior omk-verification omk-constraints; do
  assert_file "installs $name skill" "$HOME_DIR/.kiro/skills/$name/SKILL.md"
done
assert_file "preserves foreign internal agent" "$HOME_DIR/.kiro/agents/sisyphus.json"
assert_file "writes ownership manifest" "$HOME_DIR/.kiro/oh-my-kiro/manifest.json"
assert_eq "does not create global MCP config" "false" "$([[ -e "$HOME_DIR/.kiro/settings/mcp.json" ]] && echo true || echo false)"
assert_eq "installs a self-contained Orpheus prompt" "true" "$(python3 - "$HOME_DIR/.kiro/agents/orpheus.json" <<'PY'
import json
import sys
config = json.load(open(sys.argv[1], encoding="utf-8"))
print(str("Orpheus" in config["prompt"] and "__OMK_PROMPT_DIR__" not in config["prompt"]).lower())
PY
)"
assert_eq "renders Orpheus skill paths" "true" "$(python3 - "$HOME_DIR/.kiro/agents/orpheus.json" "$HOME_DIR/.kiro/skills" <<'PY'
import json
import sys
config = json.load(open(sys.argv[1], encoding="utf-8"))
expected = {
    f"skill://{sys.argv[2]}/omk-behavior/SKILL.md",
    f"skill://{sys.argv[2]}/omk-verification/SKILL.md",
    f"skill://{sys.argv[2]}/omk-constraints/SKILL.md",
}
print(str(expected.issubset(set(config["resources"]))).lower())
PY
)"

printf '%s\n' 'Test: install updates owned files and only changes default when requested'
run_installer "$HOME_DIR" --set-default > "$BASE/update.log"
assert_eq "sets Orpheus only with opt-in" "orpheus" "$(cat "$HOME_DIR/default-agent")"
assert_eq "backs up agent on update" "true" "$(find "$HOME_DIR/.kiro/oh-my-kiro/backups" -name orpheus.json -print -quit | grep -q . && echo true || echo false)"
assert_eq "backs up skill on update" "true" "$(find "$HOME_DIR/.kiro/oh-my-kiro/backups" -path '*/skills/omk-behavior/SKILL.md' -print -quit | grep -q . && echo true || echo false)"

printf '%s\n' 'Test: uninstall preserves modified skills and removes unmodified owned files'
printf '\nLocal customization\n' >> "$HOME_DIR/.kiro/skills/omk-constraints/SKILL.md"
run_installer "$HOME_DIR" --uninstall > "$BASE/uninstall.log"
assert_eq "removes Orpheus config" "false" "$([[ -e "$HOME_DIR/.kiro/agents/orpheus.json" ]] && echo true || echo false)"
assert_eq "removes unmodified behavior skill" "false" "$([[ -e "$HOME_DIR/.kiro/skills/omk-behavior/SKILL.md" ]] && echo true || echo false)"
assert_file "preserves modified constraints skill" "$HOME_DIR/.kiro/skills/omk-constraints/SKILL.md"
assert_file "preserves foreign agent on uninstall" "$HOME_DIR/.kiro/agents/sisyphus.json"
assert_eq "restores previous default" "legacy-agent" "$(cat "$HOME_DIR/default-agent")"

printf '%s\n' 'Test: foreign-name collision is rejected without overwrite'
COLLISION_HOME="$BASE/collision"
mkdir -p "$COLLISION_HOME/.kiro/agents"
printf '%s\n' '{"name":"orpheus","prompt":"foreign"}' > "$COLLISION_HOME/.kiro/agents/orpheus.json"
if run_installer "$COLLISION_HOME" > "$BASE/collision.log" 2>&1; then
  assert_eq "collision install exits non-zero" "false" "true"
else
  assert_eq "collision install exits non-zero" "true" "true"
fi
assert_eq "collision file is not overwritten" "foreign" "$(python3 - "$COLLISION_HOME/.kiro/agents/orpheus.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["prompt"])
PY
)"

printf '\nResults: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
