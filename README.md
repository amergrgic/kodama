<div align="center">

<img src="https://em-content.zobj.net/source/apple/391/deciduous-tree_1f333.png" width="80" />

# kodama

**A portable, provider-neutral Kiro CLI agent pack**

One orchestrator. Eight specialists. Zero lock-in.

[![GitHub release](https://img.shields.io/github/v/release/amergrgic/kodama)](https://github.com/amergrgic/kodama/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-emerald.svg)](LICENSE)

</div>

> **Note:** kodama is an independent community project. It is not officially affiliated with, endorsed by, or officially connected to Amazon Web Services (AWS), the Kiro IDE, or the Kiro CLI team. "Kiro" is a trademark of Amazon.com, Inc. or its affiliates.

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
| **kodama-forge** | Infrastructure, CI/CD, containerization, and deployment | Write/shell require approval |
| **kodama-scribe** | Documentation, changelogs, ADRs, and technical writing | Write/shell require approval |

The `kodama-` prefix keeps companion agents distinct from generic names that may already be installed by another pack. Only the primary entrypoint is unprefixed:

```bash
kiro-cli chat --agent kodama
```

## Install

One-liner (no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/amergrgic/kodama/main/install-remote.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/amergrgic/kodama.git
cd kodama && ./setup.sh
```

The installer requires `kiro-cli` and `python3`. It validates every generated agent configuration before writing it, then installs only these files:

```text
~/.kiro/agents/kodama.json
~/.kiro/agents/kodama-*.json
~/.kiro/skills/kodama-*/SKILL.md
~/.kiro/kodama/manifest.json
~/.kiro/kodama/setup.sh
~/.kiro/kodama/check-update.sh
~/.kiro/kodama/update.sh
~/.kiro/kodama/backups/<timestamp>/  # on update
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

A copy of `setup.sh` is installed to `~/.kiro/kodama/` so lifecycle commands work without keeping the clone:

```bash
~/.kiro/kodama/setup.sh --uninstall
```

## Update

Kodama automatically checks for updates when a session starts (cached, once per day). To update manually:

```bash
~/.kiro/kodama/update.sh
```

This downloads the latest release, backs up your current installation, and re-runs setup. Check your installed version with:

```bash
./setup.sh --version
```

## Configuration

Each file under `agents/` is a self-contained Kiro JSON configuration with an inline prompt. This keeps installation portable: no prompt-file path rendering, package manager, cloud credential, or provider-specific model is required.

All agents default to `model: "auto"`. Change an installed agent's `model` field to any model ID supported by your Kiro setup. Recommended profiles for users who want to tune:

> **Note:** Updates overwrite installed agent configs. If you customize the `model` field, you'll need to re-apply it after running `update.sh`. Your previous configs are backed up to `~/.kiro/kodama/backups/<timestamp>/`.

| Agent | Profile | Why |
|---|---|---|
| kodama | Strong reasoning (Opus, GPT-5.6 Sol) | Multi-step planning and reconciliation |
| kodama-sage | Strong reasoning (Opus, GPT-5.6 Sol) | Architecture and deep tradeoff analysis |
| kodama-critic | Fast + precise (Sonnet, GPT-5.6 Terra) | Pattern-matching over diffs |
| kodama-scout | Fast (Haiku, GPT-5.6 Luna) | Bulk reads and symbol lookups |
| kodama-scholar | Fast (Sonnet, GPT-5.6 Luna) | Research synthesis |
| kodama-smith | Balanced (Sonnet, GPT-5.6 Terra) | Implementation |
| kodama-artist | Balanced (Sonnet, GPT-5.6 Terra) | UI implementation |
| kodama-forge | Balanced (Sonnet, GPT-5.6 Terra) | Infrastructure and pipeline work |
| kodama-scribe | Fast (Sonnet, GPT-5.6 Luna) | Documentation generation |

The pack intentionally ships no global MCP preset. Add MCP servers through Kiro's normal configuration or customize individual agent configs after installation. Keep credentials and environment-specific integrations outside this repository.

## Skills

The installer adds three namespaced, on-demand playbooks under `~/.kiro/skills/`. Agent configurations reference their installed paths explicitly, so the skills remain available even when Kiro's default skill inheritance is disabled.

| Skill | Purpose | Used by |
|---|---|---|
| **kodama-behavior** | Task classification, codebase assessment, delegation, parallel work, and failure recovery | kodama, kodama-scout, kodama-scholar, kodama-sage |
| **kodama-verification** | Success criteria, targeted validation, and evidence-based completion reports | kodama, kodama-sage, kodama-artist, kodama-smith, kodama-critic, kodama-forge, kodama-scribe |
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

- **Portable:** no provider-specific or cloud-vendor dependencies.
- **Safe by default:** implementation tools are available but not auto-approved.
- **Small roster:** Kodama delegates to purpose-built companions instead of accumulating broad privileges.
- **Evidence-based:** non-trivial work is reviewed and validated before it is declared complete.

## Inspiration

Kodama is inspired by the "oh-my" family of agent packs — [oh-my-claudecode](https://github.com/yeachan-heo/oh-my-claudecode), [oh-my-opencode-slim](https://github.com/alvinunreal/oh-my-opencode-slim), and similar projects that bring structured multi-agent workflows to CLI coding tools. Kodama adapts this pattern for the Kiro CLI ecosystem with a focus on portability and provider neutrality.
