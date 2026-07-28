# Changelog

All notable changes to oh-my-kiro will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-28

### Added

- Orpheus entrypoint agent with multi-step planning and specialist delegation
- 6 specialist agents: omk-explorer, omk-librarian, omk-oracle, omk-designer, omk-fixer, omk-reviewer
- 3 reusable skills: omk-behavior, omk-verification, omk-constraints
- Lifecycle manager (`setup.sh`) with dry-run, backup, set-default, and safe uninstall
- Manifest-based ownership tracking with SHA-256 hashes
- Collision protection: refuses to overwrite existing agents not owned by this pack
- Automatic update checking via `agentSpawn` hook (cached, silent when up to date)
- Self-update script (`~/.kiro/oh-my-kiro/update.sh`) fetches latest release from GitHub
- Project-local customization support (steering, skills, agents, AGENTS.md)
- Validation suite with installer lifecycle tests and shell/JSON/skill checks
- GitHub Actions CI workflow
- MIT license

[0.1.0]: https://github.com/amergrgic/oh-my-kiro/releases/tag/v0.1.0
