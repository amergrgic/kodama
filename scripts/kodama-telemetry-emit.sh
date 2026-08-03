#!/usr/bin/env bash
# Hot-path telemetry emitter — designed to be backgrounded from agentSpawn hooks.
# Exits immediately if telemetry is not enabled.
set -euo pipefail

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/kodama"

[[ -f "$STATE_DIR/telemetry/enabled" ]] || exit 0

event_type="${1:?usage: kodama-telemetry-emit.sh <event_type> <agent_name>}"
agent_name="${2:?usage: kodama-telemetry-emit.sh <event_type> <agent_name>}"

exec python3 "$STATE_DIR/kodama-telemetry.py" emit "$event_type" "$agent_name"
