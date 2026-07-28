# kodama

A portable, provider-neutral Kiro CLI agent pack. It installs a small team with **Kodama** as the entrypoint and works independently of other Kiro packs.

> **Note:** kodama is an independent community project. It is not affiliated with, endorsed by, or officially connected to Amazon Web Services (AWS), the Kiro IDE, or the Kiro CLI team. "Kiro" is a trademark of Amazon.com, Inc. or its affiliates.

## Agents

| Agent | Role | Default access |
|---|---|---|
| **kodama** | Plans work, delegates specialists, reconciles results, and verifies completion | Delegation plus approval-gated implementation tools |
| **kodama-scout** | Read-only codebase reconnaissance | Read/search; readonly shell commands only |
| **kodama-scholar** | External API, library, and documentation research | Web research only |
| **kodama-sage** | Architecture, hard debugging, and consequential tradeoffs | Read-only analysis and research |
| **kodama-artist** | UI, UX, accessibility, and interaction implementation | Write/shell require approval |
| **kodama-smith** | Bounded implementation, tests, and straightforward refactors | Write/shell require approval |
| **kodama-critic** | Independent diff review before non-trivial work is complete | Read-only; Git inspection shell commands only |

The `kodama-` prefix keeps companion agents distinct from generic names that may already be installed by another pack. Only the primary entrypoint is unprefixed:

```bash
kiro-cli chat --agent kodama
```

## Install

One-liner (no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/amergrgic/oh-my-kiro/main/install-remote.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/amergrgic/oh-my-kiro.git
cd oh-my-kiro && ./setup.sh
```

The installer requires `kiro-cli` and `python3`. It validates every generated agent configuration before writing it, then installs only these files:

```text
~/.kiro/agents/kodama.json
~/.kiro/agents/kodama-*.json
~/.kiro/skills/kodama-*/SKILL.md
~/.kiro/oh-my-kiro/manifest.json
~/.kiro/oh-my-kiro/setup.sh
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
./setup.sh --set-default   # set chat.defaultAgent to kodama
./setup.sh --alias         # add 'kodama' shell alias
./setup.sh --uninstall     # remove only unmodified files owned by this pack
```

A first install refuses to overwrite an existing `kodama` or `kodama-*` agent file. Uninstall preserves an agent config that was changed after installation, so customizations are not silently deleted.

A copy of `setup.sh` is installed to `~/.kiro/oh-my-kiro/` so lifecycle commands work without keeping the clone:

```bash
~/.kiro/oh-my-kiro/setup.sh --uninstall
```

## Update

Kodama automatically checks for updates when a session starts (cached, once per day). To update manually:

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
| kodama | Strong reasoning (Opus, GPT-5.6 Sol) | Multi-step planning and reconciliation |
| kodama-sage | Strong reasoning (Opus, GPT-5.6 Sol) | Architecture and deep tradeoff analysis |
| kodama-critic | Fast + precise (Sonnet, GPT-5.6 Terra) | Pattern-matching over diffs |
| kodama-scout | Fast (Haiku, GPT-5.6 Luna) | Bulk reads and symbol lookups |
| kodama-scholar | Fast (Sonnet, GPT-5.6 Luna) | Research synthesis |
| kodama-smith | Balanced (Sonnet, GPT-5.6 Terra) | Implementation |
| kodama-artist | Balanced (Sonnet, GPT-5.6 Terra) | UI implementation |

The pack intentionally ships no global MCP preset. Add MCP servers through Kiro's normal configuration or customize individual agent configs after installation. Keep credentials and environment-specific integrations outside this repository.

## Skills

The installer adds three namespaced, on-demand playbooks under `~/.kiro/skills/`. Agent configurations reference their installed paths explicitly, so the skills remain available even when Kiro's default skill inheritance is disabled.

| Skill | Purpose | Used by |
|---|---|---|
| **kodama-behavior** | Task classification, codebase assessment, delegation, parallel work, and failure recovery | kodama, kodama-scout, kodama-scholar, kodama-sage |
| **kodama-verification** | Success criteria, targeted validation, and evidence-based completion reports | kodama, kodama-sage, kodama-artist, kodama-smith, kodama-critic |
| **kodama-constraints** | Scope, security, destructive-action confirmation, and completion guardrails | all agents |

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
python3 -m json.tool agents/kodama.json
```

The test suite uses a temporary home and stub Kiro CLI. It verifies dry-run behavior, coexistence with a foreign agent, ownership-aware updates and uninstall, explicit default-agent changes, and collision protection.

## Design principles

- **Portable:** no provider-specific, company-internal, or cloud-vendor dependencies.
- **Safe by default:** implementation tools are available but not auto-approved.
- **Small roster:** Kodama delegates to purpose-built companions instead of accumulating broad privileges.
- **Evidence-based:** non-trivial work is reviewed and validated before it is declared complete.
