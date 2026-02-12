#!/bin/bash
# peon-ping adapter for OpenCode
# Installs the peon-ping CESP v1.0 TypeScript plugin for OpenCode
#
# OpenCode uses a TypeScript plugin system (not shell hooks), so this
# adapter is an install script rather than a runtime event translator.
#
# Install:
#   bash adapters/opencode.sh
#
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode.sh | bash
#
# Uninstall:
#   bash adapters/opencode.sh --uninstall

set -euo pipefail

# --- Config ---
PLUGIN_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/peon-ping.ts"
REGISTRY_URL="https://peonping.github.io/registry/index.json"
DEFAULT_PACK="peon"

OPENCODE_PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/plugins"
PEON_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/peon-ping"
PACKS_DIR="$HOME/.openpeon/packs"

# --- Colors ---
BOLD='\033[1m' DIM='\033[2m' RED='\033[31m' GREEN='\033[32m' YELLOW='\033[33m' RESET='\033[0m'

info()  { printf "${GREEN}>${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}!${RESET} %s\n" "$*"; }
error() { printf "${RED}x${RESET} %s\n" "$*" >&2; }

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  info "Uninstalling peon-ping from OpenCode..."
  rm -f "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
  rm -rf "$PEON_CONFIG_DIR"
  info "Plugin and config removed."
  info "Sound packs in $PACKS_DIR were preserved (shared with other adapters)."
  info "To remove packs too: rm -rf $PACKS_DIR"
  exit 0
fi

# --- Preflight ---
info "Installing peon-ping for OpenCode..."

if ! command -v curl &>/dev/null; then
  error "curl is required but not found."
  exit 1
fi

# Check for afplay (macOS), paplay (Linux), or powershell (WSL)
PLATFORM="unknown"
case "$(uname -s)" in
  Darwin) PLATFORM="mac" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      PLATFORM="wsl"
    else
      PLATFORM="linux"
    fi ;;
esac

case "$PLATFORM" in
  mac)
    command -v afplay &>/dev/null || warn "afplay not found — sounds may not play" ;;
  wsl)
    command -v powershell.exe &>/dev/null || warn "powershell.exe not found — sounds may not play" ;;
  linux)
    if ! command -v paplay &>/dev/null && ! command -v aplay &>/dev/null; then
      warn "No audio player found (paplay/aplay) — sounds may not play"
    fi ;;
esac

# --- Install plugin ---
mkdir -p "$OPENCODE_PLUGINS_DIR"

info "Downloading peon-ping.ts plugin..."
if curl -fsSL "$PLUGIN_URL" -o "$OPENCODE_PLUGINS_DIR/peon-ping.ts" 2>/dev/null; then
  info "Plugin installed to $OPENCODE_PLUGINS_DIR/peon-ping.ts"
else
  warn "Could not download from adapters/opencode/ path, trying standalone repo..."
  FALLBACK_URL="https://raw.githubusercontent.com/atkrv/opencode-peon-ping/main/peon-ping.ts"
  curl -fsSL "$FALLBACK_URL" -o "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
  info "Plugin installed from standalone repo."
fi

# --- Create default config ---
mkdir -p "$PEON_CONFIG_DIR"

if [ ! -f "$PEON_CONFIG_DIR/config.json" ]; then
  cat > "$PEON_CONFIG_DIR/config.json" << 'CONFIGEOF'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "session.end": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "task.progress": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "spam_threshold": 3,
  "spam_window_seconds": 10,
  "pack_rotation": [],
  "debounce_ms": 500
}
CONFIGEOF
  info "Config created at $PEON_CONFIG_DIR/config.json"
else
  info "Config already exists, preserved."
fi

# --- Install default sound pack from registry ---
mkdir -p "$PACKS_DIR"

if [ ! -d "$PACKS_DIR/$DEFAULT_PACK" ]; then
  info "Installing default sound pack '$DEFAULT_PACK' from registry..."

  PACK_URL=$(curl -fsSL "$REGISTRY_URL" 2>/dev/null \
    | python3 -c "
import sys, json
reg = json.load(sys.stdin)
for p in reg.get('packs', []):
    if p.get('name') == '$DEFAULT_PACK':
        print(p.get('url', ''))
        break
" 2>/dev/null || echo "")

  if [ -n "$PACK_URL" ]; then
    TMPDIR_PACK=$(mktemp -d)
    if curl -fsSL "$PACK_URL" -o "$TMPDIR_PACK/pack.tar.gz" 2>/dev/null; then
      mkdir -p "$PACKS_DIR/$DEFAULT_PACK"
      tar xzf "$TMPDIR_PACK/pack.tar.gz" -C "$PACKS_DIR/$DEFAULT_PACK" --strip-components=1 2>/dev/null \
        || tar xzf "$TMPDIR_PACK/pack.tar.gz" -C "$PACKS_DIR/$DEFAULT_PACK" 2>/dev/null
      info "Pack '$DEFAULT_PACK' installed to $PACKS_DIR/$DEFAULT_PACK"
    else
      warn "Could not download pack from registry. You can install packs manually later."
    fi
    rm -rf "$TMPDIR_PACK"
  else
    warn "Could not find '$DEFAULT_PACK' in registry. You can install packs manually later."
  fi
else
  info "Pack '$DEFAULT_PACK' already installed."
fi

# --- Done ---
echo ""
info "${BOLD}peon-ping installed for OpenCode!${RESET}"
echo ""
printf "  ${DIM}Plugin:${RESET}  %s\n" "$OPENCODE_PLUGINS_DIR/peon-ping.ts"
printf "  ${DIM}Config:${RESET}  %s\n" "$PEON_CONFIG_DIR/config.json"
printf "  ${DIM}Packs:${RESET}   %s\n" "$PACKS_DIR/"
echo ""
info "Restart OpenCode to activate. Your Peon awaits."
info "Install more packs: https://openpeon.com/packs"
