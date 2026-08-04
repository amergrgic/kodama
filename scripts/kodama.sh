#!/usr/bin/env bash
# kodama CLI wrapper — dispatches subcommands or falls through to kiro-cli chat.
set -euo pipefail

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/kodama"

# Detect and export the project root so memory commands target the right project.
# This persists for the lifetime of this process and any child (kiro-cli session).
export KODAMA_PROJECT_ROOT="${KODAMA_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)}"

case "${1:-}" in
  doctor)
    exec "$STATE_DIR/kodama-doctor.sh"
    ;;
  stats)
    shift
    exec "$STATE_DIR/kodama-stats.sh" "$@"
    ;;
  update)
    exec "$STATE_DIR/update.sh"
    ;;
  uninstall)
    exec "$STATE_DIR/setup.sh" --uninstall
    ;;
  version)
    exec "$STATE_DIR/setup.sh" --version
    ;;
  memory)
    shift
    exec python3 "$STATE_DIR/kodama-memory.py" "${1:-show}" "${@:2}"
    ;;
  help|--help|-h)
    cat <<'EOF'
Usage: kodama [subcommand] [options]

Subcommands:
  doctor      Check installation health
  memory      Show or manage project memory
  stats       Show usage insights (local-only telemetry)
  update      Update kodama to the latest release
  uninstall   Remove kodama and all owned files
  version     Print the installed version
  help        Show this help

Without a subcommand, starts a Kiro CLI chat session with the kodama agent.
Any flags not matching a subcommand are passed through to kiro-cli.

Examples:
  kodama                  Start a chat session
  kodama memory             Show project memory
  kodama stats            Show agent usage for the last 30 days
  kodama stats --json     Machine-readable usage data
  kodama stats --enable   Enable usage tracking
  kodama update           Self-update to latest release
EOF
    exit 0
    ;;
  *)
    exec kiro-cli chat --agent kodama "$@"
    ;;
esac
