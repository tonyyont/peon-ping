#!/bin/bash
# peon-ping installer
# Works both via `curl | bash` (downloads from GitHub) and local clone
# Re-running updates core files; re-downloads sounds only when packs change
set -euo pipefail

INSTALL_DIR="$HOME/.claude/hooks/peon-ping"
SETTINGS="$HOME/.claude/settings.json"
REPO_BASE="https://raw.githubusercontent.com/tonyyont/peon-ping/main"

# All available sound packs (add new packs here)
PACKS="peon ra2_soviet_engineer"

# --- Detect update vs fresh install ---
UPDATING=false
if [ -f "$INSTALL_DIR/peon.sh" ]; then
  UPDATING=true
fi

if [ "$UPDATING" = true ]; then
  echo "=== peon-ping updater ==="
  echo ""
  echo "Existing install found. Updating..."
else
  echo "=== peon-ping installer ==="
  echo ""
fi

# --- Prerequisites ---
if [ "$(uname)" != "Darwin" ]; then
  echo "Error: peon-ping requires macOS (uses afplay + AppleScript)"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

if ! command -v afplay &>/dev/null; then
  echo "Error: afplay is required (should be built into macOS)"
  exit 1
fi

if [ ! -d "$HOME/.claude" ]; then
  echo "Error: ~/.claude/ not found. Is Claude Code installed?"
  exit 1
fi

# --- Snapshot manifest hashes before update ---
declare -A OLD_HASHES 2>/dev/null || true
for pack in $PACKS; do
  manifest="$INSTALL_DIR/packs/$pack/manifest.json"
  if [ -f "$manifest" ]; then
    OLD_HASHES[$pack]=$(md5 -q "$manifest" 2>/dev/null || echo "none")
  else
    OLD_HASHES[$pack]="none"
  fi
done

# --- Detect if running from local clone or curl|bash ---
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -f "$CANDIDATE/peon.sh" ]; then
    SCRIPT_DIR="$CANDIDATE"
  fi
fi

# --- Install/update core files ---
for pack in $PACKS; do
  mkdir -p "$INSTALL_DIR/packs/$pack"
done
mkdir -p "$INSTALL_DIR/scripts"

if [ -n "$SCRIPT_DIR" ]; then
  # Local clone — copy files directly
  cp -r "$SCRIPT_DIR/packs/"* "$INSTALL_DIR/packs/"
  cp "$SCRIPT_DIR/scripts/download-sounds.sh" "$INSTALL_DIR/scripts/"
  cp "$SCRIPT_DIR/peon.sh" "$INSTALL_DIR/"
  if [ "$UPDATING" = false ]; then
    cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/"
  fi
else
  # curl|bash — download from GitHub
  echo "Downloading from GitHub..."
  curl -fsSL "$REPO_BASE/peon.sh" -o "$INSTALL_DIR/peon.sh"
  curl -fsSL "$REPO_BASE/scripts/download-sounds.sh" -o "$INSTALL_DIR/scripts/download-sounds.sh"
  curl -fsSL "$REPO_BASE/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
  for pack in $PACKS; do
    curl -fsSL "$REPO_BASE/packs/$pack/manifest.json" -o "$INSTALL_DIR/packs/$pack/manifest.json"
  done
  if [ "$UPDATING" = false ]; then
    curl -fsSL "$REPO_BASE/config.json" -o "$INSTALL_DIR/config.json"
  fi
fi

chmod +x "$INSTALL_DIR/peon.sh"
chmod +x "$INSTALL_DIR/scripts/download-sounds.sh"

# --- Download sounds per pack (skip if manifest unchanged) ---
echo ""
for pack in $PACKS; do
  manifest="$INSTALL_DIR/packs/$pack/manifest.json"
  new_hash=$(md5 -q "$manifest" 2>/dev/null || echo "new")
  old_hash="${OLD_HASHES[$pack]:-none}"
  sound_dir="$INSTALL_DIR/packs/$pack/sounds"
  sound_count=$({ ls "$sound_dir"/*.wav "$sound_dir"/*.mp3 "$sound_dir"/*.ogg 2>/dev/null || true; } | wc -l | tr -d ' ')

  if [ "$old_hash" = "none" ] || [ "$sound_count" -eq 0 ]; then
    echo "[$pack] New pack — downloading sounds..."
    bash "$INSTALL_DIR/scripts/download-sounds.sh" "$INSTALL_DIR" "$pack"
  elif [ "$old_hash" != "$new_hash" ]; then
    echo "[$pack] Pack updated — re-downloading sounds..."
    bash "$INSTALL_DIR/scripts/download-sounds.sh" "$INSTALL_DIR" "$pack"
  else
    echo "[$pack] Sounds up to date ($sound_count files)."
  fi
done

# --- Backup existing notify.sh (fresh install only) ---
if [ "$UPDATING" = false ]; then
  NOTIFY_SH="$HOME/.claude/hooks/notify.sh"
  if [ -f "$NOTIFY_SH" ]; then
    cp "$NOTIFY_SH" "$NOTIFY_SH.backup"
    echo ""
    echo "Backed up notify.sh → notify.sh.backup"
  fi
fi

# --- Update settings.json ---
echo ""
echo "Updating Claude Code hooks in settings.json..."

/usr/bin/python3 -c "
import json, os, sys

settings_path = os.path.expanduser('~/.claude/settings.json')
hook_cmd = os.path.expanduser('~/.claude/hooks/peon-ping/peon.sh')

# Load existing settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault('hooks', {})

peon_hook = {
    'type': 'command',
    'command': hook_cmd,
    'timeout': 10
}

peon_entry = {
    'matcher': '',
    'hooks': [peon_hook]
}

# Events to register
events = ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']

for event in events:
    event_hooks = hooks.get(event, [])
    # Remove any existing notify.sh or peon.sh entries
    event_hooks = [
        h for h in event_hooks
        if not any(
            'notify.sh' in hk.get('command', '') or 'peon.sh' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    event_hooks.append(peon_entry)
    hooks[event] = event_hooks

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Hooks registered for: ' + ', '.join(events))
"

# --- Initialize state (fresh install only) ---
if [ "$UPDATING" = false ]; then
  echo '{}' > "$INSTALL_DIR/.state.json"
fi

# --- Test sound ---
echo ""
echo "Testing sound..."
ACTIVE_PACK=$(/usr/bin/python3 -c "
import json, os
try:
    c = json.load(open(os.path.expanduser('~/.claude/hooks/peon-ping/config.json')))
    print(c.get('active_pack', 'peon'))
except:
    print('peon')
" 2>/dev/null)
PACK_DIR="$INSTALL_DIR/packs/$ACTIVE_PACK"
TEST_SOUND=$({ ls "$PACK_DIR/sounds/"*.wav "$PACK_DIR/sounds/"*.mp3 "$PACK_DIR/sounds/"*.ogg 2>/dev/null || true; } | head -1)
if [ -n "$TEST_SOUND" ]; then
  afplay -v 0.3 "$TEST_SOUND"
  echo "Sound working!"
else
  echo "Warning: No sound files found. Sounds may not play."
fi

echo ""
if [ "$UPDATING" = true ]; then
  echo "=== Update complete! ==="
  echo ""
  echo "Updated: peon.sh, manifest.json"
  echo "Preserved: config.json, state"
else
  echo "=== Installation complete! ==="
  echo ""
  echo "Config: $INSTALL_DIR/config.json"
  echo "  - Adjust volume, toggle categories, switch packs"
  echo ""
  echo "Uninstall: bash $INSTALL_DIR/uninstall.sh"
fi
echo ""
echo "Ready to work!"
