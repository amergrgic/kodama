#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() {
  printf '\n==> %s\n' "$1"
  shift
  "$@"
}

run "Installer lifecycle tests" bash "$ROOT/tests/test_install.sh"
run "Project-local customization tests" bash "$ROOT/tests/test_project_customization.sh"
run "Telemetry tests" bash "$ROOT/tests/test_telemetry.sh"
run "Shell syntax" bash -n \
  "$ROOT/setup.sh" \
  "$ROOT/scripts/check-update.sh" \
  "$ROOT/scripts/update.sh" \
  "$ROOT/scripts/kodama.sh" \
  "$ROOT/scripts/kodama-telemetry-emit.sh" \
  "$ROOT/scripts/kodama-stats.sh" \
  "$ROOT/tests/test_install.sh" \
  "$ROOT/tests/test_project_customization.sh" \
  "$ROOT/tests/test_telemetry.sh" \
  "$ROOT/scripts/validate.sh"

printf '\n==> Agent JSON and skill metadata\n'
python3 - "$ROOT" <<'PY'
import json
from pathlib import Path
import sys

root = Path(sys.argv[1])
agent_paths = sorted((root / "agents").glob("*.json"))
agent_paths += sorted((root / "examples").glob("**/.kiro/agents/*.json"))
skill_paths = sorted((root / "skills").glob("*/SKILL.md"))
skill_paths += sorted((root / "examples").glob("**/.kiro/skills/*/SKILL.md"))

if not agent_paths:
    raise SystemExit("no agent JSON configurations found")
if not skill_paths:
    raise SystemExit("no skill definitions found")
if "./scripts/validate.sh" not in (root / "README.md").read_text(encoding="utf-8"):
    raise SystemExit("README.md must document ./scripts/validate.sh")

for path in agent_paths:
    config = json.loads(path.read_text(encoding="utf-8"))
    if config.get("name") != path.stem:
        raise SystemExit(f"{path}: name must match filename")
    if not isinstance(config.get("prompt"), str) or not config["prompt"].strip():
        raise SystemExit(f"{path}: prompt must be a non-empty string")
    tools = config.get("tools", [])
    allowed = config.get("allowedTools", [])
    if not isinstance(tools, list) or not isinstance(allowed, list):
        raise SystemExit(f"{path}: tools and allowedTools must be lists")
    if not set(allowed) <= set(tools):
        raise SystemExit(f"{path}: allowedTools must be a subset of tools")

for path in skill_paths:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0] != "---":
        raise SystemExit(f"{path}: missing YAML frontmatter")
    try:
        end = lines.index("---", 1)
    except ValueError as error:
        raise SystemExit(f"{path}: unterminated YAML frontmatter") from error
    metadata = {}
    for line in lines[1:end]:
        if ":" in line:
            key, value = line.split(":", 1)
            metadata[key.strip()] = value.strip()
    if metadata.get("name") != path.parent.name:
        raise SystemExit(f"{path}: frontmatter name must match skill directory")
    if not metadata.get("description"):
        raise SystemExit(f"{path}: frontmatter requires a description")

print(f"validated {len(agent_paths)} agent configurations and {len(skill_paths)} skill definitions")

# Drift check: AGENT_NAMES in setup.sh must match agents/ directory
import re
setup_text = (root / "setup.sh").read_text(encoding="utf-8")
match = re.search(r"AGENT_NAMES=\(\s*(.*?)\s*\)", setup_text, re.DOTALL)
if not match:
    raise SystemExit("setup.sh: cannot find AGENT_NAMES array")
setup_agents = set(match.group(1).split())
file_agents = {p.stem for p in (root / "agents").glob("*.json")}
if setup_agents != file_agents:
    missing_in_setup = file_agents - setup_agents
    missing_in_dir = setup_agents - file_agents
    msg = "AGENT_NAMES drift detected:"
    if missing_in_setup:
        msg += f" in agents/ but not setup.sh: {sorted(missing_in_setup)}"
    if missing_in_dir:
        msg += f" in setup.sh but not agents/: {sorted(missing_in_dir)}"
    raise SystemExit(msg)
print("AGENT_NAMES matches agents/ directory")
PY

printf '\nValidation complete.\n'
