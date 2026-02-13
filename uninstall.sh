#!/bin/bash
# peon-ping uninstaller
# Removes peon hooks and optionally restores notify.sh
set -euo pipefail

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$INSTALL_DIR/../.." && pwd)"
SETTINGS="$BASE_DIR/settings.json"

IS_LOCAL=true
if [ "$BASE_DIR" = "$HOME/.claude" ]; then
  IS_LOCAL=false
fi

# Hooks are always written to global settings (install.sh design).
# When uninstalling a local install, also clean hooks from global settings.
GLOBAL_SETTINGS="$HOME/.claude/settings.json"

NOTIFY_BACKUP="$BASE_DIR/hooks/notify.sh.backup"
NOTIFY_SH="$BASE_DIR/hooks/notify.sh"

echo "=== peon-ping uninstaller ==="
echo ""

# --- Remove hook entries from settings.json ---
# Clean both local and global settings files (if they differ).
_remove_peon_hooks() {
  local target="$1"
  [ -f "$target" ] || return 0
  python3 -c "
import json, os

settings_path = '$target'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
events_cleaned = []

for event, entries in list(hooks.items()):
    original_count = len(entries)
    entries = [
        h for h in entries
        if not any(
            'peon.sh' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    if len(entries) < original_count:
        events_cleaned.append(event)
    if entries:
        hooks[event] = entries
    else:
        del hooks[event]

settings['hooks'] = hooks

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

if events_cleaned:
    print('Removed hooks for: ' + ', '.join(events_cleaned))
else:
    print('No peon hooks found in settings.json')
"
}

echo "Removing peon hooks from settings.json..."
_remove_peon_hooks "$SETTINGS"

# For local installs, hooks live in global settings — clean those too.
if [ "$IS_LOCAL" = true ] && [ "$SETTINGS" != "$GLOBAL_SETTINGS" ]; then
  echo "Removing peon hooks from global settings.json..."
  _remove_peon_hooks "$GLOBAL_SETTINGS"
fi

# --- Restore notify.sh backup (global install only) ---
if [ "$IS_LOCAL" = false ] && [ -f "$NOTIFY_BACKUP" ]; then
  echo ""
  read -p "Restore original notify.sh from backup? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Re-register notify.sh for its original events
    python3 -c "
import json

settings_path = '$SETTINGS'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
notify_hook = {
    'matcher': '',
    'hooks': [{
        'type': 'command',
        'command': '$NOTIFY_SH',
        'timeout': 10
    }]
}

for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']:
    event_hooks = hooks.get(event, [])
    # Don't add if already present
    has_notify = any(
        'notify.sh' in hk.get('command', '')
        for h in event_hooks
        for hk in h.get('hooks', [])
    )
    if not has_notify:
        event_hooks.append(notify_hook)
    hooks[event] = event_hooks

settings['hooks'] = hooks
with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Restored notify.sh hooks for: SessionStart, UserPromptSubmit, Stop, Notification')
"
    cp "$NOTIFY_BACKUP" "$NOTIFY_SH"
    rm "$NOTIFY_BACKUP"
    echo "notify.sh restored"
  fi
fi

# --- Remove fish completions ---
FISH_COMPLETIONS="$HOME/.config/fish/completions/peon.fish"
if [ -f "$FISH_COMPLETIONS" ]; then
  rm "$FISH_COMPLETIONS"
  echo "Removed fish completions"
fi

# --- Remove skill directories ---
for SKILL_NAME in peon-ping-toggle peon-ping-config; do
  SKILL_DIR="$BASE_DIR/skills/$SKILL_NAME"
  if [ -d "$SKILL_DIR" ]; then
    echo ""
    echo "Removing $SKILL_DIR..."
    rm -rf "$SKILL_DIR"
    echo "Removed $SKILL_NAME skill"
  fi
done

# --- Remove install directory ---
if [ -d "$INSTALL_DIR" ]; then
  echo ""
  echo "Removing $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  echo "Removed"
fi

echo ""
echo "=== Uninstall complete ==="
echo "Me go now."
