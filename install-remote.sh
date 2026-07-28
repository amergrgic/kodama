#!/usr/bin/env bash
# oh-my-kiro remote installer — curl -fsSL https://raw.githubusercontent.com/amergrgic/oh-my-kiro/main/install-remote.sh | bash
set -euo pipefail

REPO="amergrgic/oh-my-kiro"
BRANCH="main"

BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
RESET='\033[0m'

info()    { printf '  %b▸%b %s\n' "$CYAN" "$RESET" "$1"; }
success() { printf '  %b✓%b %s\n' "$GREEN" "$RESET" "$1"; }
fail()    { printf '  %b✗ %s%b\n' "$RED" "$*" "$RESET" >&2; exit 1; }

# Check prerequisites
command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
command -v kiro-cli >/dev/null 2>&1 || fail "kiro-cli is required (https://kiro.dev)"

printf '\n%b━━ oh-my-kiro remote install%b\n\n' "$BOLD" "$RESET"

# Try latest release first, fall back to main branch
info "Fetching latest release..."
tarball_url="$(curl -fsSL --max-time 10 \
  "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('tarball_url',''))" 2>/dev/null)" || tarball_url=""

if [[ -z "$tarball_url" ]]; then
  info "No release found, using $BRANCH branch"
  tarball_url="https://github.com/$REPO/archive/$BRANCH.tar.gz"
fi

# Download and extract
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

info "Downloading..."
curl -fsSL --max-time 30 "$tarball_url" | tar xz -C "$TEMP_DIR" --strip-components=1 \
  || fail "Download failed. Check your network connection."

success "Downloaded"

# Ask about alias if interactive and not already passed as flag
EXTRA_FLAGS=""
if [[ -t 0 ]] && [[ ! " $* " =~ " --alias " ]]; then
  printf '  Add %borpheus%b alias to your shell? [y/N] ' "$BOLD" "$RESET"
  read -r add_alias
  if [[ "$add_alias" =~ ^[Yy]$ ]]; then
    EXTRA_FLAGS="--alias"
  fi
fi

# Run setup
info "Running setup..."
bash "$TEMP_DIR/setup.sh" $EXTRA_FLAGS "$@"
