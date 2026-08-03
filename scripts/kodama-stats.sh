#!/usr/bin/env bash
# kodama stats — CLI reporting entrypoint for local telemetry data.
set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/kodama"
TELEMETRY_DIR="$STATE_DIR/telemetry"

info()    { printf '  %b▸%b %b\n' "$CYAN" "$RESET" "$1"; }
success() { printf '  %b✓%b %b\n' "$GREEN" "$RESET" "$1"; }

usage() {
  cat <<EOF
${BOLD}Usage:${RESET} kodama stats [options]

${BOLD}Options:${RESET}
  --enable       Enable local telemetry collection
  --disable      Disable telemetry and stop collecting events
  --status       Show whether telemetry is enabled and data size
  --json         Output query results as JSON
  --period N     Report over the last N days (default: 30)
  --help, -h     Show this help

${BOLD}Examples:${RESET}
  kodama stats                Show usage for the last 30 days
  kodama stats --json         Machine-readable output
  kodama stats --period 7     Last 7 days only
  kodama stats --enable       Start collecting usage data
EOF
  exit 0
}

cmd_enable() {
  mkdir -p "$TELEMETRY_DIR"
  touch "$TELEMETRY_DIR/enabled"
  success "Telemetry enabled. Events are stored locally in $TELEMETRY_DIR"
}

cmd_disable() {
  rm -f "$TELEMETRY_DIR/enabled"
  success "Telemetry disabled. Existing data is preserved; use --status to check size."
}

cmd_status() {
  printf '\n  %bTelemetry status%b\n' "$BOLD" "$RESET"
  if [[ -f "$TELEMETRY_DIR/enabled" ]]; then
    info "Collection: ${GREEN}enabled${RESET}"
  else
    info "Collection: ${YELLOW}disabled${RESET}"
  fi
  if [[ -d "$TELEMETRY_DIR" ]]; then
    local size
    size="$(du -sh "$TELEMETRY_DIR" 2>/dev/null | cut -f1 | xargs)"
    info "Data size:  ${size:-0B}"
  else
    info "Data size:  (no data directory)"
  fi
  printf '\n'
}

# Parse arguments
query_args=()
action=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable)   action="enable";  shift ;;
    --disable)  action="disable"; shift ;;
    --status)   action="status";  shift ;;
    --json)     query_args+=("--json"); shift ;;
    --period)
      shift
      query_args+=("--period" "${1:?--period requires a number}")
      shift
      ;;
    --help|-h)  usage ;;
    *)
      printf '  %b⚠%b Unknown option: %s\n' "$YELLOW" "$RESET" "$1" >&2
      usage
      ;;
  esac
done

case "$action" in
  enable)  cmd_enable  ;;
  disable) cmd_disable ;;
  status)  cmd_status  ;;
  *)
    # Default: run query (pass --json / --period if provided)
    exec python3 "$STATE_DIR/kodama-telemetry.py" query ${query_args[@]+"${query_args[@]}"}
    ;;
esac
