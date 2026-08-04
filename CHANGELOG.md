# Changelog

All notable changes to kodama will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.1] - 2026-08-04

### Changed

- Orchestrator prompt: structured delegation contract (goal, context, constraints, success criteria), safe parallelism rules, explicit feedback/retry loops, routing tie-breakers
- Critic prompt: structured 7-dimension review rubric with severity levels (blocker/warning/suggestion)
- Scout prompt: structured evidence report format with confidence levels and uncertainty disclosure
- Scholar prompt: source prioritization, version-pinning, structured research output
- Artist prompt: accessibility checklist (keyboard, ARIA, WCAG AA, responsive, states)
- Forge prompt: mandatory dry-run/validation before apply, blast radius analysis for production changes
- Smith prompt: broken-test ownership, convention-following heuristic, scope-uncertainty escalation

## [0.7.0] - 2026-08-04

### Added

- **Project memory** — persistent, per-project knowledge that accumulates across sessions
- Memory categories: facts, decisions, failures, conventions, architecture, sessions
- `kodama memory` command to view, reset, or audit stored memory
- Agents write memory when discovering project structure, recording failures, or noting conventions
- Memory loaded automatically at session start via agentSpawn hook (4KB context budget)
- Privacy filter rejects secrets, tokens, and credential patterns from memory writes
- Auto-compaction enforces size limits (50 entries per file, 20 session entries)
- `kodama memory audit` scans for accidentally stored secrets

## [0.6.2] - 2026-08-04

### Added

- `kodama doctor` — diagnostic health check: validates manifest, agent/skill hashes, scripts, alias, telemetry, and session state
- `kodama uninstall` — shorthand for `setup.sh --uninstall`

### Changed

- All user-facing references now use `kodama update` / `kodama version` instead of raw script paths
- Update notice from `check-update.sh` now says `Run: kodama update`

## [0.6.1] - 2026-08-03

### Changed

- Orchestrator prompt now enforces delegation-first behavior: create task list, then immediately delegate rather than implementing directly

## [0.6.0] - 2026-08-03

### Added

- **CLI wrapper** (`kodama.sh`): unified entrypoint with subcommands — `kodama stats`, `kodama update`, `kodama version`, `kodama help`
- **Usage insights** (`kodama stats`): opt-in, local-only telemetry tracking agent spawns, sessions, and delegations. No data leaves your machine.
- Shell alias now installs by default on fresh installs (use `--no-alias` to skip)
- All specialist agents emit telemetry events via `agentSpawn` hooks (zero cost when disabled)
- `kodama stats --enable/--disable/--status/--json/--period N` for full control over tracking
- Automatic log rotation (max ~5 MB) and 90-day age purge

### Changed

- Shell alias now points to the wrapper (`$HOME/.kiro/kodama/kodama.sh`) instead of directly to `kiro-cli`
- `update.sh` automatically migrates old aliases and adds the alias if missing
- `install-remote.sh` alias prompt defaults to Yes

### Fixed

- Empty array expansion in stats script under `set -u`

## [0.5.1] - 2026-07-30

### Fixed

- Installed `setup.sh` no longer crashes when running `--set-default` or `--alias` without source files
- Lifecycle commands (`--set-default`, `--alias`, `--uninstall`, `--version`) work directly from `~/.kiro/kodama/setup.sh`
- Full reinstall directs users to `update.sh`

### Changed

- Primary install URL is now `https://dl.getkodama.dev`
- Landing site served from `getkodama.dev`

## [0.5.0] - 2026-07-29

### Added

- Kodama automatically cleans up handoff files from `.kiro/kodama/handoffs/` after task completion
- Project-customization docs updated to mention auto-cleanup behavior

## [0.4.1] - 2026-07-28

### Fixed

- Renamed all `__OMK_*` placeholders to `__KODAMA_*` across agent configs, setup.sh, and tests
- Renamed `OMK_VERSION` variable to `KODAMA_VERSION` in setup.sh
- Added kodama-forge and kodama-scribe to test suite verification (30 tests now)

### Added

- AGENT_NAMES vs `agents/` directory drift check in validate.sh

## [0.4.0] - 2026-07-28

### Added

- Inter-agent handoff convention: specialists write structured context to `.kiro/kodama/handoffs/` when chaining tasks
- Kodama orchestrates handoff-based chains for multi-specialist workflows
- Handoff writing instructions added to forge, scribe, smith, and artist prompts
- Project-customization docs updated with handoff convention and example
- Example `.gitignore` for ephemeral handoff files

## [0.3.0] - 2026-07-28

### Added

- **kodama-forge** agent: infrastructure, CI/CD, containerization, and deployment specialist
- **kodama-scribe** agent: documentation, changelogs, ADRs, and technical writing specialist
- Both agents added to kodama's delegation targets

## [0.2.1] - 2026-07-28

### Added

- Remote installer asks interactively about shell alias
- `setup.sh` installed to `~/.kiro/kodama/` so uninstall works without keeping the clone

## [0.2.0] - 2026-07-28

### Added

- One-liner remote install (`curl | bash`, no clone needed)
- `--alias` flag: adds `kodama` shell alias to your profile (zsh/bash/fish)
- `--version` flag to print the installed pack version
- Automatic update checking via `agentSpawn` hook (cached daily, silent when up to date)
- Self-update script (`~/.kiro/kodama/update.sh`) fetches latest release from GitHub
- Interactive confirmation prompt on `--uninstall`
- Version tracking in manifest
- CONTRIBUTING.md

## [0.1.0] - 2026-07-28

### Added

- Kodama entrypoint agent with multi-step planning and specialist delegation
- 6 specialist agents: kodama-scout, kodama-scholar, kodama-sage, kodama-artist, kodama-smith, kodama-critic
- 3 reusable skills: kodama-behavior, kodama-verification, kodama-constraints
- Lifecycle manager (`setup.sh`) with dry-run, backup, set-default, and safe uninstall
- Manifest-based ownership tracking with SHA-256 hashes
- Collision protection: refuses to overwrite existing agents not owned by this pack
- Automatic update checking via `agentSpawn` hook (cached, silent when up to date)
- Self-update script (`~/.kiro/kodama/update.sh`) fetches latest release from GitHub
- Project-local customization support (steering, skills, agents, AGENTS.md)
- Validation suite with installer lifecycle tests and shell/JSON/skill checks
- GitHub Actions CI workflow
- MIT license

[0.7.1]: https://github.com/amergrgic/kodama/releases/tag/v0.7.1
[0.7.0]: https://github.com/amergrgic/kodama/releases/tag/v0.7.0
[0.6.2]: https://github.com/amergrgic/kodama/releases/tag/v0.6.2
[0.6.1]: https://github.com/amergrgic/kodama/releases/tag/v0.6.1
[0.6.0]: https://github.com/amergrgic/kodama/releases/tag/v0.6.0
[0.5.1]: https://github.com/amergrgic/kodama/releases/tag/v0.5.1
[0.5.0]: https://github.com/amergrgic/kodama/releases/tag/v0.5.0
[0.4.1]: https://github.com/amergrgic/kodama/releases/tag/v0.4.1
[0.4.0]: https://github.com/amergrgic/kodama/releases/tag/v0.4.0
[0.3.0]: https://github.com/amergrgic/kodama/releases/tag/v0.3.0
[0.2.1]: https://github.com/amergrgic/kodama/releases/tag/v0.2.1
[0.2.0]: https://github.com/amergrgic/kodama/releases/tag/v0.2.0
[0.1.0]: https://github.com/amergrgic/kodama/releases/tag/v0.1.0
