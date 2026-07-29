# Changelog

All notable changes to kodama will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.5.0]: https://github.com/amergrgic/kodama/releases/tag/v0.5.0
[0.4.1]: https://github.com/amergrgic/kodama/releases/tag/v0.4.1
[0.4.0]: https://github.com/amergrgic/kodama/releases/tag/v0.4.0
[0.3.0]: https://github.com/amergrgic/kodama/releases/tag/v0.3.0
[0.2.1]: https://github.com/amergrgic/kodama/releases/tag/v0.2.1
[0.2.0]: https://github.com/amergrgic/kodama/releases/tag/v0.2.0
[0.1.0]: https://github.com/amergrgic/kodama/releases/tag/v0.1.0
