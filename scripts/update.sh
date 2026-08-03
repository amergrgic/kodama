#!/usr/bin/env bash
# kodama updater — downloads the latest release and re-runs setup.
set -euo pipefail

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { printf '  %b▸%b %s\n' "$CYAN" "$RESET" "$1"; }
success() { printf '  %b✓%b %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '  %b⚠%b %s\n' "$YELLOW" "$RESET" "$1"; }
fail()    { printf '  %b✗ %s%b\n' "$RED" "$*" "$RESET" >&2; exit 1; }

STATE_DIR="${KIRO_DIR:-$HOME/.kiro}/kodama"
MANIFEST="$STATE_DIR/manifest.json"
REPO="amergrgic/kodama"

# Check prerequisites
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"

printf '\n%b━━ kodama update%b\n' "$BOLD" "$RESET"

# Read installed version
installed_version=""
if [[ -f "$MANIFEST" ]]; then
  installed_version="$(python3 -c "
import json
with open('$MANIFEST') as f:
    print(json.load(f).get('version', 'unknown'))
" 2>/dev/null)" || installed_version="unknown"
fi
info "Installed: ${installed_version:-not found}"

# Fetch latest release info
info "Checking for latest release..."
release_info="$(curl -fsSL --max-time 10 \
  "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null)" \
  || fail "Could not reach GitHub. Check your network connection."

latest_version="$(echo "$release_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tag_name','').lstrip('v'))" 2>/dev/null)"
tarball_url="$(echo "$release_info" | python3 -c "import json,sys; print(json.load(sys.stdin).get('tarball_url',''))" 2>/dev/null)"

[[ -n "$latest_version" ]] || fail "Could not determine latest version"
[[ -n "$tarball_url" ]] || fail "Could not determine download URL"

if [[ "$latest_version" == "$installed_version" ]]; then
  success "Already up to date (v$installed_version)"
  exit 0
fi

info "Available: $latest_version"

# Download and extract
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

info "Downloading v$latest_version..."
curl -fsSL --max-time 30 "$tarball_url" | tar xz -C "$TEMP_DIR" --strip-components=1 \
  || fail "Download failed"

# Run setup from the new version
info "Installing..."
bash "$TEMP_DIR/setup.sh" || fail "Setup failed"

# Clear update cache
rm -f "$STATE_DIR/.update-cache"

printf '\n'
success "Updated kodama: $installed_version → $latest_version"

# Check if old-style alias exists in shell profile
SHELL_PROFILE=""
case "${SHELL:-}" in
  */zsh)  SHELL_PROFILE="$HOME/.zshrc" ;;
  */bash)
    if [[ -f "$HOME/.bash_profile" ]]; then
      SHELL_PROFILE="$HOME/.bash_profile"
    else
      SHELL_PROFILE="$HOME/.bashrc"
    fi
    ;;
  */fish) SHELL_PROFILE="$HOME/.config/fish/config.fish" ;;
esac

if [[ -n "$SHELL_PROFILE" ]] && grep -qF 'alias kodama="kiro-cli chat --agent kodama"' "$SHELL_PROFILE" 2>/dev/null; then
  sed -i.bak 's|alias kodama="kiro-cli chat --agent kodama"|alias kodama="$HOME/.kiro/kodama/kodama.sh"|' "$SHELL_PROFILE"
  rm -f "${SHELL_PROFILE}.bak"
  success "Updated alias in $SHELL_PROFILE (reload your shell to use subcommands)"
elif [[ -n "$SHELL_PROFILE" ]] && ! grep -qF 'alias kodama=' "$SHELL_PROFILE" 2>/dev/null; then
  printf '\n# kodama\nalias kodama="$HOME/.kiro/kodama/kodama.sh"\n' >> "$SHELL_PROFILE"
  success "Added 'kodama' alias to $SHELL_PROFILE (reload your shell to use it)"
fi

printf '\n'
