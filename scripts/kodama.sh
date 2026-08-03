#!/usr/bin/env bash
# kodama CLI wrapper — dispatches subcommands or falls through to kiro-cli chat.
set -euo pipefail

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/kodama"

case "${1:-}" in
  stats)
    shift
    exec "$STATE_DIR/kodama-stats.sh" "$@"
    ;;
  update)
    exec "$STATE_DIR/update.sh"
    ;;
  version)
    exec "$STATE_DIR/setup.sh" --version
    ;;
  help|--help|-h)
    cat <<'EOF'
Usage: kodama [subcommand] [options]

Subcommands:
  stats       Show usage insights (local-only telemetry)
  update      Update kodama to the latest release
  version     Print the installed version
  help        Show this help

Without a subcommand, starts a Kiro CLI chat session with the kodama agent.
Any flags not matching a subcommand are passed through to kiro-cli.

Examples:
  kodama                  Start a chat session
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
