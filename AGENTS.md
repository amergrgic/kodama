# Agents

This is the kodama agent pack repository. Kodama is the entrypoint; the `kodama-` prefixed agents are specialists it delegates to.

## Architecture

- `agents/` — self-contained Kiro JSON configs with inline prompts. Each file's `name` field must match its filename stem.
- `skills/` — reusable workflow playbooks (Markdown with YAML frontmatter). Referenced by agents via `skill://` resource URIs.
- `setup.sh` — lifecycle manager: validates, stages, backs up, installs, and uninstalls. All installed files are tracked in a manifest with SHA-256 hashes.
- `examples/project-customization/` — shows end users how to extend the pack per-repo.

## Agent roster

| Agent | Delegates to | Purpose |
|---|---|---|
| kodama | all specialists | Plans, delegates, reconciles, verifies |
| kodama-scout | — | Read-only codebase reconnaissance |
| kodama-scholar | — | External docs and API research |
| kodama-sage | — | Architecture, debugging, tradeoffs |
| kodama-artist | — | UI, UX, accessibility implementation |
| kodama-smith | — | Bounded implementation and tests |
| kodama-critic | — | Independent diff review |

## Conventions

- Agents use `model: "auto"` — no provider lock-in.
- `allowedTools` must be a subset of `tools`. Tools outside `allowedTools` require user approval.
- Resource paths use `__KODAMA_SKILLS_DIR__` as a placeholder; the installer resolves it at install time.
- Skills use YAML frontmatter with `name` (must match directory) and `description`.
- The pack never modifies files outside its own manifest (no global MCP, no other agents).

## Validation

Run before committing:

```bash
./scripts/validate.sh
```

Checks: installer lifecycle, project-customization tests, shell syntax, agent JSON schema, and skill metadata.

## Adding an agent

1. Create `agents/<name>.json` with `name`, `description`, `prompt`, `model`, `tools`, `allowedTools`, and `resources`.
2. Add the name to `AGENT_NAMES` in `setup.sh`.
3. Reference any skills via `skill://__KODAMA_SKILLS_DIR__/<skill>/SKILL.md`.
4. Run `./scripts/validate.sh`.
