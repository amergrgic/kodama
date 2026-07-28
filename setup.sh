#!/usr/bin/env bash
set -euo pipefail

# Installs only the files owned by this public pack. It intentionally does not
# modify other agent packs, merge global MCP settings, or change the default agent
# unless --set-default is explicitly supplied.

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

banner() {
  printf '%b' "$CYAN"
  cat <<'ART'

     ██████╗ ██╗  ██╗    ███╗   ███╗██╗   ██╗    ██╗  ██╗██╗██████╗  ██████╗
    ██╔═══██╗██║  ██║    ████╗ ████║╚██╗ ██╔╝    ██║ ██╔╝██║██╔══██╗██╔═══██╗
    ██║   ██║███████║    ██╔████╔██║ ╚████╔╝     █████╔╝ ██║██████╔╝██║   ██║
    ██║   ██║██╔══██║    ██║╚██╔╝██║  ╚██╔╝      ██╔═██╗ ██║██╔══██╗██║   ██║
    ╚██████╔╝██║  ██║    ██║ ╚═╝ ██║   ██║       ██║  ██╗██║██║  ██║╚██████╔╝
     ╚═════╝ ╚═╝  ╚═╝    ╚═╝     ╚═╝   ╚═╝       ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝ ╚═════╝

ART
  printf '%b' "$RESET"
  printf '    %bA portable, provider-neutral Kiro CLI agent pack%b\n\n' "$DIM" "$RESET"
}

info()    { printf '  %b▸%b %s\n' "$CYAN" "$RESET" "$1"; }
success() { printf '  %b✓%b %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '  %b⚠%b %s\n' "$YELLOW" "$RESET" "$1"; }
step()    { printf '\n%b━━ %s%b\n' "$BOLD" "$1" "$RESET"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIRO_DIR="${KIRO_DIR:-$HOME/.kiro}"
AGENTS_DIR="$KIRO_DIR/agents"
SKILLS_DIR="$KIRO_DIR/skills"
STATE_DIR="$KIRO_DIR/oh-my-kiro"
MANIFEST="$STATE_DIR/manifest.json"
OMK_VERSION="0.1.0"

AGENT_NAMES=(
  orpheus
  omk-explorer
  omk-librarian
  omk-oracle
  omk-designer
  omk-fixer
  omk-reviewer
)
SKILL_NAMES=(
  omk-behavior
  omk-verification
  omk-constraints
)

DRY_RUN=false
UNINSTALL=false
SET_DEFAULT=false

usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--set-default] [--uninstall] [--version]

  --dry-run      Show what would change without writing files.
  --set-default  Set Kiro CLI's default agent to Orpheus after a successful install.
  --uninstall    Remove only unmodified agent and skill files owned by this pack.
  --version      Print the pack version and exit.

The setup script never modifies other agent packs or global MCP settings.
EOF
}

fail() {
  printf '  %b✗ %s%b\n' "$RED" "$*" "$RESET" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --set-default) SET_DEFAULT=true ;;
    --uninstall) UNINSTALL=true ;;
    --version) echo "oh-my-kiro $OMK_VERSION"; exit 0 ;;
    --help|-h) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

$UNINSTALL && $SET_DEFAULT && fail "--set-default cannot be used with --uninstall"

banner

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

step "Checking prerequisites"
require_command python3
if ! $DRY_RUN; then
  require_command kiro-cli
fi
success "All prerequisites found"

manifest_value() {
  local key="$1"
  python3 - "$MANIFEST" "$key" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    value = json.load(handle).get(sys.argv[2], "")
print(value if isinstance(value, str) else "")
PY
}

manifest_hash() {
  local collection="$1" name="$2"
  python3 - "$MANIFEST" "$collection" "$name" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    print(json.load(handle).get(sys.argv[2], {}).get(sys.argv[3], ""))
PY
}

file_hash() {
  python3 - "$1" <<'PY'
import hashlib
import pathlib
import sys

print(hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest())
PY
}

validate_staged_agents() {
  local staging_dir="$1" name output
  for name in "${AGENT_NAMES[@]}"; do
    if ! output="$(kiro-cli agent validate --path "$staging_dir/$name.json" 2>&1)"; then
      printf '%s\n' "$output" >&2
      fail "Kiro rejected staged agent '$name'"
    fi
    # Some Kiro CLI versions report validation errors without a non-zero status.
    if grep -qiE '(^|[[:space:]])error:' <<<"$output"; then
      printf '%s\n' "$output" >&2
      fail "Kiro reported an error for staged agent '$name'"
    fi
  done
}

remove_owned_file() {
  local path="$1" expected_hash="$2" label="$3"
  local actual_hash=""
  [[ -f "$path" ]] && actual_hash="$(file_hash "$path")"
  if [[ -n "$expected_hash" && "$actual_hash" == "$expected_hash" ]]; then
    rm -f "$path"
    success "Removed $label"
    return 0
  fi
  if [[ -e "$path" ]]; then
    warn "Preserved $label (modified since install)"
  fi
  return 1
}

uninstall() {
  if [[ ! -f "$MANIFEST" ]]; then
    warn "oh-my-kiro is not installed at $STATE_DIR"
    return
  fi

  if $DRY_RUN; then
    info "Would remove unmodified oh-my-kiro agents from $AGENTS_DIR and skills from $SKILLS_DIR"
    return
  fi

  step "Uninstalling"
  local name removed_agents=0 removed_skills=0
  for name in "${AGENT_NAMES[@]}"; do
    if remove_owned_file "$AGENTS_DIR/$name.json" "$(manifest_hash agentHashes "$name")" "$AGENTS_DIR/$name.json"; then
      removed_agents=$((removed_agents + 1))
    fi
  done
  for name in "${SKILL_NAMES[@]}"; do
    if remove_owned_file "$SKILLS_DIR/$name/SKILL.md" "$(manifest_hash skillHashes "$name")" "$SKILLS_DIR/$name/SKILL.md"; then
      removed_skills=$((removed_skills + 1))
      rmdir "$SKILLS_DIR/$name" 2>/dev/null || true
    fi
  done

  local previous_default current_default
  previous_default="$(manifest_value previousDefaultAgent)"
  current_default="$(kiro-cli settings chat.defaultAgent 2>/dev/null || true)"
  if [[ "$current_default" == "orpheus" ]]; then
    if [[ -n "$previous_default" ]]; then
      kiro-cli settings chat.defaultAgent "$previous_default"
      info "Restored default agent to $previous_default"
    else
      kiro-cli settings --delete chat.defaultAgent
      info "Cleared the default-agent setting"
    fi
  fi

  rm -f "$MANIFEST"
  success "Uninstalled $removed_agents agent(s) and $removed_skills skill(s)"
}

if $UNINSTALL; then
  uninstall
  exit 0
fi

if [[ ! -f "$MANIFEST" ]]; then
  for name in "${AGENT_NAMES[@]}"; do
    [[ -e "$AGENTS_DIR/$name.json" ]] && fail "refusing to overwrite existing agent '$name' at $AGENTS_DIR/$name.json"
  done
  for name in "${SKILL_NAMES[@]}"; do
    [[ -e "$SKILLS_DIR/$name/SKILL.md" ]] && fail "refusing to overwrite existing skill '$name' at $SKILLS_DIR/$name/SKILL.md"
  done
fi

if $DRY_RUN; then
  step "Dry run"
  info "Would install agents: ${AGENT_NAMES[*]}"
  info "Would install skills: ${SKILL_NAMES[*]}"
  info "Target: $KIRO_DIR"
  $SET_DEFAULT && info "Would set default agent to: orpheus"
  printf '\n'
  success "No files modified"
  exit 0
fi

mkdir -p "$AGENTS_DIR" "$SKILLS_DIR" "$STATE_DIR"
STAGING_DIR="$(mktemp -d "$STATE_DIR/.staging.XXXXXX")"
BACKUP_DIR="$STATE_DIR/backups/$(date +%Y%m%d-%H%M%S)"
cleanup() { rm -rf "$STAGING_DIR"; }
trap cleanup EXIT
mkdir -p "$STAGING_DIR/agents" "$STAGING_DIR/skills"

step "Preparing agents and skills"

for name in "${SKILL_NAMES[@]}"; do
  mkdir -p "$STAGING_DIR/skills/$name"
  cp "$SCRIPT_DIR/skills/$name/SKILL.md" "$STAGING_DIR/skills/$name/SKILL.md"
done

python3 - "$SCRIPT_DIR/agents" "$STAGING_DIR/agents" "$SKILLS_DIR" "$STATE_DIR" "${AGENT_NAMES[@]}" <<'PY'
import json
import pathlib
import sys

source_dir = pathlib.Path(sys.argv[1])
staging_dir = pathlib.Path(sys.argv[2])
skills_dir = sys.argv[3]
state_dir = sys.argv[4]
for name in sys.argv[5:]:
    with (source_dir / f"{name}.json").open(encoding="utf-8") as handle:
        config = json.load(handle)
    config["resources"] = [
        resource.replace("__OMK_SKILLS_DIR__", skills_dir)
        for resource in config.get("resources", [])
    ]
    # Resolve hook command placeholders
    for trigger, commands in config.get("hooks", {}).items():
        for entry in commands:
            if "command" in entry:
                entry["command"] = entry["command"].replace("__OMK_STATE_DIR__", state_dir)
    with (staging_dir / f"{name}.json").open("w", encoding="utf-8") as handle:
        json.dump(config, handle, indent=2)
        handle.write("\n")
PY
validate_staged_agents "$STAGING_DIR/agents"
success "All agent configurations validated"

if [[ -f "$MANIFEST" ]]; then
  step "Backing up previous installation"
  mkdir -p "$BACKUP_DIR/skills"
  for name in "${AGENT_NAMES[@]}"; do
    [[ -f "$AGENTS_DIR/$name.json" ]] && cp "$AGENTS_DIR/$name.json" "$BACKUP_DIR/$name.json"
  done
  for name in "${SKILL_NAMES[@]}"; do
    if [[ -f "$SKILLS_DIR/$name/SKILL.md" ]]; then
      mkdir -p "$BACKUP_DIR/skills/$name"
      cp "$SKILLS_DIR/$name/SKILL.md" "$BACKUP_DIR/skills/$name/SKILL.md"
    fi
  done
  success "Backed up to $BACKUP_DIR"
fi

step "Installing"
for name in "${AGENT_NAMES[@]}"; do
  cp "$STAGING_DIR/agents/$name.json" "$AGENTS_DIR/$name.json"
  success "Agent: $name"
done
for name in "${SKILL_NAMES[@]}"; do
  mkdir -p "$SKILLS_DIR/$name"
  cp "$STAGING_DIR/skills/$name/SKILL.md" "$SKILLS_DIR/$name/SKILL.md"
  success "Skill: $name"
done

# Install lifecycle scripts
cp "$SCRIPT_DIR/scripts/check-update.sh" "$STATE_DIR/check-update.sh"
chmod +x "$STATE_DIR/check-update.sh"
cp "$SCRIPT_DIR/scripts/update.sh" "$STATE_DIR/update.sh"
chmod +x "$STATE_DIR/update.sh"
success "Scripts: check-update.sh, update.sh"

previous_default=""
if [[ -f "$MANIFEST" ]]; then
  previous_default="$(manifest_value previousDefaultAgent)"
fi
if $SET_DEFAULT; then
  current_default="$(kiro-cli settings chat.defaultAgent 2>/dev/null || true)"
  [[ "$current_default" != "orpheus" ]] && previous_default="$current_default"
  kiro-cli settings chat.defaultAgent orpheus
  success "Default agent set to orpheus"
fi

python3 - "$MANIFEST" "$previous_default" "$OMK_VERSION" "$AGENTS_DIR" "$SKILLS_DIR" "${AGENT_NAMES[@]}" -- "${SKILL_NAMES[@]}" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest = pathlib.Path(sys.argv[1])
version = sys.argv[3]
agent_dir = pathlib.Path(sys.argv[4])
skill_dir = pathlib.Path(sys.argv[5])
separator = sys.argv.index("--")
agents = sys.argv[6:separator]
skills = sys.argv[separator + 1:]
agent_hashes = {
    name: hashlib.sha256((agent_dir / f"{name}.json").read_bytes()).hexdigest()
    for name in agents
}
skill_hashes = {
    name: hashlib.sha256((skill_dir / name / "SKILL.md").read_bytes()).hexdigest()
    for name in skills
}
manifest.write_text(json.dumps({
    "schemaVersion": 1,
    "version": version,
    "agents": agents,
    "skills": skills,
    "agentHashes": agent_hashes,
    "skillHashes": skill_hashes,
    "previousDefaultAgent": sys.argv[2]
}, indent=2) + "\n", encoding="utf-8")
PY

printf '\n%b━━ Done%b\n' "$BOLD" "$RESET"
printf '\n'
printf '  Orpheus and %d specialists are ready (v%s).\n' "$(( ${#AGENT_NAMES[@]} - 1 ))" "$OMK_VERSION"
printf '  Installed independently of other Kiro packs.\n'
printf '\n'
printf '  %bStart:%b  kiro-cli chat --agent orpheus\n' "$GREEN" "$RESET"
printf '  %bUpdate:%b ~/.kiro/oh-my-kiro/update.sh\n' "$DIM" "$RESET"
printf '  %bRemove:%b ./setup.sh --uninstall\n' "$DIM" "$RESET"
printf '\n'
