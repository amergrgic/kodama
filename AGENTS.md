# Agents

This is the oh-my-kiro agent pack repository. Orpheus is the entrypoint; the `omk-` prefixed agents are specialists it delegates to.

## Architecture

- `agents/` — self-contained Kiro JSON configs with inline prompts. Each file's `name` field must match its filename stem.
- `skills/` — reusable workflow playbooks (Markdown with YAML frontmatter). Referenced by agents via `skill://` resource URIs.
- `setup.sh` — lifecycle manager: validates, stages, backs up, installs, and uninstalls. All installed files are tracked in a manifest with SHA-256 hashes.
- `examples/project-customization/` — shows end users how to extend the pack per-repo.

## Agent roster

| Agent | Delegates to | Purpose |
|---|---|---|
| orpheus | all specialists | Plans, delegates, reconciles, verifies |
| omk-explorer | — | Read-only codebase reconnaissance |
| omk-librarian | — | External docs and API research |
| omk-oracle | — | Architecture, debugging, tradeoffs |
| omk-designer | — | UI, UX, accessibility implementation |
| omk-fixer | — | Bounded implementation and tests |
| omk-reviewer | — | Independent diff review |

## Conventions

- Agents use `model: "auto"` — no provider lock-in.
- `allowedTools` must be a subset of `tools`. Tools outside `allowedTools` require user approval.
- Resource paths use `__OMK_SKILLS_DIR__` as a placeholder; the installer resolves it at install time.
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
3. Reference any skills via `skill://__OMK_SKILLS_DIR__/<skill>/SKILL.md`.
4. Run `./scripts/validate.sh`.
