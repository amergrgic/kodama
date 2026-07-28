# Project-local customization

Use project-local files to teach Kodama about a repository without editing the globally installed `kodama` or `kodama-*` agents. Commit these files when they describe shared team conventions; keep personal preferences in `~/.kiro/steering/` instead.

## Supported layout

```text
project-root/
├── AGENTS.md
└── .kiro/
    ├── steering/
    │   ├── conventions.md
    │   └── validation.md
    ├── skills/
    │   └── release-check/
    │       └── SKILL.md
    └── agents/
        └── project-reviewer.json
```

A copyable version is available in [`examples/project-customization/`](../examples/project-customization/).

## Steering: persistent project rules

Put short, shared rules in `.kiro/steering/*.md`: coding conventions, required checks, architecture boundaries, or review expectations. Kodama and the installed `kodama-*` agents load workspace steering through their configured resources.

Keep steering focused. It is present on every turn, so move detailed workflows into a skill instead.

```markdown
# Validation rules

- Run `npm test` before requesting review.
- Run `npm run lint` after changing TypeScript.
- Do not modify generated files under `src/generated/`.
```

## Skills: on-demand project workflows

Create a `.kiro/skills/<skill-name>/SKILL.md` file when a workflow is specific enough to be reused but too detailed for steering. Skills need YAML frontmatter with `name` and `description`.

```markdown
---
name: release-check
description: Validate this project's release checklist. Use before publishing a release candidate.
---

# Release check

1. Run the test suite.
2. Generate release notes from merged changes.
3. Confirm the version and changelog agree.
```

Project-local skills are discovered through Kiro's normal default resource inheritance. If a user has disabled `chat.disableInheritingDefaultResources`, they must re-enable it or explicitly add the skill resource to their local agent configuration.

## Local agents: add a repository-specific specialist

Add a uniquely named JSON config under `.kiro/agents/` for a project-specific task. Local agents take precedence over global agents with the same filename, so choose a new name such as `project-reviewer` instead of replacing `kodama`.

```json
{
  "name": "project-reviewer",
  "description": "Reviews this repository's API compatibility rules.",
  "prompt": "Review changes against AGENTS.md and .kiro/steering/. Report blockers with file and line references.",
  "model": "auto",
  "tools": ["read", "grep", "glob", "code"],
  "allowedTools": ["read", "grep", "glob", "code"],
  "resources": ["file://AGENTS.md", "file://.kiro/steering/**/*.md"]
}
```

Run it directly when useful:

```bash
kiro-cli chat --agent project-reviewer
```

Do not name a local agent `kodama` unless you intentionally want that repository to replace the globally installed entrypoint.

## AGENTS.md: repository map and fast-start instructions

Keep `AGENTS.md` brief and factual. It should help an agent orient itself: source layout, test commands, generated-code boundaries, and deployment or review expectations. Avoid duplicating detailed rules that belong in steering or skills.

## Steering for infrastructure and documentation specialists

When your project has specific infrastructure or documentation conventions, add steering that guides `kodama-forge` and `kodama-scribe` appropriately:

```markdown
# Infrastructure conventions

- CI runs on GitHub Actions; all workflows live in `.github/workflows/`.
- Use multi-stage Docker builds; final images must be based on `distroless`.
- Terraform state is in S3; never use local state.
- All IaC changes must pass `terraform validate` and `tflint` before review.
```

```markdown
# Documentation conventions

- Keep ADRs in `docs/adr/` using the MADR format.
- Update CHANGELOG.md for every user-facing change (Keep a Changelog format).
- API docs are generated from OpenAPI specs in `docs/api/`; do not hand-edit.
- Use American English and sentence-case headings.
```

These steer forge and scribe without modifying the installed agents. Kodama delegates to them with the project context already loaded.

## Safety and update behavior

- Do **not** edit `~/.kiro/agents/kodama.json`, `~/.kiro/agents/kodama-*.json`, or `~/.kiro/skills/kodama-*/` directly. Updates may replace those files; use project-local files instead.
- Treat `.kiro/agents/*.json` as executable configuration: it can grant tools and load resources. Review it before trusting a repository.
- Keep credentials, tokens, and machine-specific paths out of committed local configuration.
- Do not add write-capable or network-capable tools to a project agent unless the team has reviewed the impact.
