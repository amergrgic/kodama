# oh-my-kiro

A portable, provider-neutral Kiro CLI agent pack. It installs a small team with **Orpheus** as the entrypoint and works independently of other Kiro packs.

> **Note:** oh-my-kiro is an independent community project. It is not affiliated with, endorsed by, or officially connected to Amazon Web Services (AWS), the Kiro IDE, or the Kiro CLI team. "Kiro" is a trademark of Amazon.com, Inc. or its affiliates.

## Agents

| Agent | Role | Default access |
|---|---|---|
| **orpheus** | Plans work, delegates specialists, reconciles results, and verifies completion | Delegation plus approval-gated implementation tools |
| **omk-explorer** | Read-only codebase reconnaissance | Read/search; readonly shell commands only |
| **omk-librarian** | External API, library, and documentation research | Web research only |
| **omk-oracle** | Architecture, hard debugging, and consequential tradeoffs | Read-only analysis and research |
| **omk-designer** | UI, UX, accessibility, and interaction implementation | Write/shell require approval |
| **omk-fixer** | Bounded implementation, tests, and straightforward refactors | Write/shell require approval |
| **omk-reviewer** | Independent diff review before non-trivial work is complete | Read-only; Git inspection shell commands only |

The `omk-` prefix keeps companion agents distinct from generic names that may already be installed by another pack. Only the primary entrypoint is unprefixed:

```bash
kiro-cli chat --agent orpheus
```

## Install

```bash
./setup.sh
```

The installer requires `kiro-cli` and `python3`. It validates every generated agent configuration before writing it, then installs only these files:

```text
~/.kiro/agents/orpheus.json
~/.kiro/agents/omk-*.json
~/.kiro/skills/omk-*/SKILL.md
~/.kiro/oh-my-kiro/manifest.json
~/.kiro/oh-my-kiro/check-update.sh
~/.kiro/oh-my-kiro/update.sh
~/.kiro/oh-my-kiro/backups/<timestamp>/  # on update
```

It does **not** modify:

- other agent packs or their configuration
- global MCP settings
- your Kiro default agent, unless requested explicitly

Use the optional lifecycle commands:

```bash
./setup.sh --dry-run       # preview without writes
./setup.sh --set-default   # set chat.defaultAgent to orpheus
./setup.sh --uninstall     # remove only unmodified files owned by this pack
```

A first install refuses to overwrite an existing `orpheus` or `omk-*` agent file. Uninstall preserves an agent config that was changed after installation, so customizations are not silently deleted.

## Update

Orpheus automatically checks for updates when a session starts (cached, once per day). To update manually:

```bash
~/.kiro/oh-my-kiro/update.sh
```

This downloads the latest release, backs up your current installation, and re-runs setup. Check your installed version with:

```bash
./setup.sh --version
```

## Configuration

Each file under `agents/` is a self-contained Kiro JSON configuration with an inline prompt. This keeps installation portable: no prompt-file path rendering, package manager, cloud credential, or provider-specific model is required.

All agents default to `model: "auto"`. Change an installed agent's `model` field to any model ID supported by your Kiro setup. Recommended profiles for users who want to tune:

| Agent | Profile | Why |
|---|---|---|
| orpheus | Strong reasoning (Opus, GPT-5.6 Sol) | Multi-step planning and reconciliation |
| omk-oracle | Strong reasoning (Opus, GPT-5.6 Sol) | Architecture and deep tradeoff analysis |
| omk-reviewer | Fast + precise (Sonnet, GPT-5.6 Terra) | Pattern-matching over diffs |
| omk-explorer | Fast (Haiku, GPT-5.6 Luna) | Bulk reads and symbol lookups |
| omk-librarian | Fast (Sonnet, GPT-5.6 Luna) | Research synthesis |
| omk-fixer | Balanced (Sonnet, GPT-5.6 Terra) | Implementation |
| omk-designer | Balanced (Sonnet, GPT-5.6 Terra) | UI implementation |

The pack intentionally ships no global MCP preset. Add MCP servers through Kiro's normal configuration or customize individual agent configs after installation. Keep credentials and environment-specific integrations outside this repository.

## Skills

The installer adds three namespaced, on-demand playbooks under `~/.kiro/skills/`. Agent configurations reference their installed paths explicitly, so the skills remain available even when Kiro's default skill inheritance is disabled.

| Skill | Purpose | Used by |
|---|---|---|
| **omk-behavior** | Task classification, codebase assessment, delegation, parallel work, and failure recovery | orpheus, omk-explorer, omk-librarian, omk-oracle |
| **omk-verification** | Success criteria, targeted validation, and evidence-based completion reports | orpheus, omk-oracle, omk-designer, omk-fixer, omk-reviewer |
| **omk-constraints** | Scope, security, destructive-action confirmation, and completion guardrails | all agents |

Skills are the only workflow Markdown shipped by the pack. Agent prompts remain self-contained inside their JSON configurations.

## Project-local customization

Keep repository-specific rules and workflows in the repository instead of editing installed pack files. See the [project-local customization guide](docs/project-customization.md) and copy [`examples/project-customization/`](examples/project-customization/) as a starting point.

## Development and validation

Run the full portable validation suite before sharing a change or wiring up CI:

```bash
./scripts/validate.sh
```

It requires only `bash` and `python3`; the installer lifecycle suite uses an isolated temporary home and a stub Kiro CLI. To run individual checks while developing:

```bash
bash tests/test_install.sh
bash tests/test_project_customization.sh
bash -n setup.sh
python3 -m json.tool agents/orpheus.json
```

The test suite uses a temporary home and stub Kiro CLI. It verifies dry-run behavior, coexistence with a foreign agent, ownership-aware updates and uninstall, explicit default-agent changes, and collision protection.

## Design principles

- **Portable:** no provider-specific, company-internal, or cloud-vendor dependencies.
- **Safe by default:** implementation tools are available but not auto-approved.
- **Small roster:** Orpheus delegates to purpose-built companions instead of accumulating broad privileges.
- **Evidence-based:** non-trivial work is reviewed and validated before it is declared complete.
