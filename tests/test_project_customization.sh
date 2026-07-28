#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLE="$ROOT/examples/project-customization"
DOC="$ROOT/docs/project-customization.md"

for path in \
  "$DOC" \
  "$EXAMPLE/AGENTS.md" \
  "$EXAMPLE/.kiro/steering/conventions.md" \
  "$EXAMPLE/.kiro/skills/project-release-check/SKILL.md" \
  "$EXAMPLE/.kiro/agents/project-reviewer.json"; do
  [[ -f "$path" ]] || { echo "missing required customization artifact: $path" >&2; exit 1; }
done

python3 - "$EXAMPLE" "$DOC" "$ROOT/README.md" "$ROOT/agents/kodama.json" <<'PY'
import json
import pathlib
import sys

example, doc, readme, kodama = map(pathlib.Path, sys.argv[1:])
agent = json.loads((example / ".kiro/agents/project-reviewer.json").read_text(encoding="utf-8"))
assert agent["name"] == "project-reviewer"
assert {"write", "shell"}.isdisjoint(agent["tools"])
assert set(agent["allowedTools"]) <= set(agent["tools"])
assert "file://AGENTS.md" in agent["resources"]

skill = (example / ".kiro/skills/project-release-check/SKILL.md").read_text(encoding="utf-8")
assert skill.startswith("---\n")
assert "\nname: project-release-check\n" in skill
assert "\ndescription: " in skill

assert "examples/project-customization" in doc.read_text(encoding="utf-8")
assert "docs/project-customization.md" in readme.read_text(encoding="utf-8")
assert "file://AGENTS.md" in json.loads(kodama.read_text(encoding="utf-8"))["resources"]
print("project customization documentation and example: valid")
PY
