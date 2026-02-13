#!/bin/bash
# peon-ping installer
# Works both via `curl | bash` (downloads from GitHub) and local clone
# Re-running updates core files; sounds are version-controlled in the repo
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

# --- Detect repository URL ---
detect_repo_info() {
  local remote_url=""
  local owner=""
  local repo=""
  
  if [ -n "${PEON_REPO_URL:-}" ]; then
    echo "$PEON_REPO_URL"
    return
  fi
  
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ]; then
    remote_url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)
  fi
  
  if [ -z "$remote_url" ]; then
    echo "https://raw.githubusercontent.com/kenyiu/peon-ping/main"
    return
  fi
  
  if echo "$remote_url" | grep -qE '^git@github\.com:'; then
    owner=$(echo "$remote_url" | sed 's|git@github\.com:\([^/]*\)/.*|\1|')
    repo=$(echo "$remote_url" | sed 's|git@github\.com:[^/]*/\([^.]*\).*|\1|')
  elif echo "$remote_url" | grep -qE '^https://github\.com/'; then
    owner=$(echo "$remote_url" | sed 's|https://github\.com/\([^/]*\)/.*|\1|')
    repo=$(echo "$remote_url" | sed 's|https://github\.com/[^/]*/\([^.]*\).*|\1|')
  fi
  
  if [ -n "$owner" ] && [ -n "$repo" ]; then
    echo "https://raw.githubusercontent.com/$owner/$repo/main"
  else
    echo "https://raw.githubusercontent.com/kenyiu/peon-ping/main"
  fi
}

detect_clone_url() {
  local remote_url=""
  
  if [ -n "${PEON_CLONE_URL:-}" ]; then
    echo "$PEON_CLONE_URL"
    return
  fi
  
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ]; then
    remote_url=$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)
  fi
  
  if [ -n "$remote_url" ]; then
    echo "$remote_url" | sed -E \
      -e 's|git@github\.com:|https://github.com/|' \
      -e 's|\.git$||'
    return
  fi
  
  echo "https://github.com/kenyiu/peon-ping.git"
}

# --- Install mode flags ---
INSTALL_MODE="global"  # default: global only
SKIP_CHECKSUM=false    # default: verify checksums if available
INIT_LOCAL_CONFIG=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)
      INSTALL_MODE="global"
      shift
      ;;
    --local)
      INSTALL_MODE="local"
      shift
      ;;
    --init-local-config)
      INIT_LOCAL_CONFIG=true
      shift
      ;;
    --skip-checksum)
      SKIP_CHECKSUM=true
      shift
      ;;
    --help|-h)
      cat << 'HELPEOF'
Usage: install.sh [OPTIONS]

Options:
  --global                Install hook globally in ~/.claude/ (default)
  --local                 Install hook locally in ./.claude/ (project-specific)
  --init-local-config     Create local config file only (no scripts installed)
  --skip-checksum         Skip checksum verification (for development/testing)
  --help                  Show this help message

Installation modes:
  Global (default): Installs to ~/.claude/hooks/peon-ping/
                    Available across all projects.

  Local:            Installs to ./.claude/hooks/peon-ping/
                    Only available in current project.

  Note: You cannot have both global and local installations.
        If a conflict exists, you'll be asked to remove the other.

Init config:
  Use --init-local-config to create ./.claude/hooks/peon-ping/config.json
  without installing scripts. Useful when global is installed but you want
  per-project settings.

Security: When downloading from GitHub, checksums are verified if available.
HELPEOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Determine install directory based on mode
if [ "$INSTALL_MODE" = "local" ]; then
  INSTALL_DIR="$PWD/.claude/hooks/peon-ping"
else
  INSTALL_DIR="$HOME/.claude/hooks/peon-ping"
fi

# Handle --init-local-config early
if [ "$INIT_LOCAL_CONFIG" = true ]; then
  mkdir -p "$PWD/.claude/hooks/peon-ping"
  if [ -f "$PWD/.claude/hooks/peon-ping/config.json" ]; then
    echo "Local config already exists at $PWD/.claude/hooks/peon-ping/config.json"
  else
    if [ -f "config.json" ]; then
      cp config.json "$PWD/.claude/hooks/peon-ping/config.json"
      echo "Created local config at $PWD/.claude/hooks/peon-ping/config.json"
    else
      cat > "$PWD/.claude/hooks/peon-ping/config.json" << 'EOF'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "greeting": true,
    "acknowledge": true,
    "complete": true,
    "error": true,
    "permission": true,
    "annoyed": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10,
  "pack_rotation": []
}
EOF
      echo "Created default local config at $PWD/.claude/hooks/peon-ping/config.json"
    fi
  fi
  exit 0
fi

# All available sound packs (add new packs here)
PACKS="peon peon_fr peon_pl peasant peasant_fr ra2_soviet_engineer sc_battlecruiser sc_kerrigan"

# --- Platform detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "mac" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    *) echo "unknown" ;;
  esac
}
PLATFORM=$(detect_platform)

# --- Git repository detection ---
is_git_repo() {
  if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ]; then
    return 0
  fi
  return 1
}

# --- Checksum verification ---
verify_checksums() {
  local target_dir="$1"
  echo "Verifying checksums..."
  
  if [ "$SKIP_CHECKSUM" = true ]; then
    echo "Checksum verification skipped (--skip-checksum flag)"
    return 0
  fi
  
  local checksum_file="$target_dir/checksums.txt"
  curl -fsSL "$REPO_BASE/checksums.txt" -o "$checksum_file" 2>/dev/null || {
    echo "No checksums.txt available, skipping verification"
    return 0
  }
  
  if [ ! -s "$checksum_file" ]; then
    echo "Checksum file empty, skipping verification"
    rm -f "$checksum_file"
    return 0
  fi
  
  local failed=0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local expected_hash="${line%% *}"
    local file_path="${line#* }"
    file_path="${file_path#/}"
    
    local actual_hash
    if [ -f "$target_dir/$file_path" ]; then
      actual_hash=$(sha256sum "$target_dir/$file_path" 2>/dev/null | cut -d' ' -f1)
      if [ "$expected_hash" != "$actual_hash" ]; then
        echo "ERROR: Checksum mismatch for $file_path"
        echo "  Expected: $expected_hash"
        echo "  Actual:   $actual_hash"
        failed=1
      fi
    else
      echo "WARNING: File not found for checksum: $file_path"
    fi
  done < "$checksum_file"
  
  rm -f "$checksum_file"
  
  if [ "$failed" -eq 1 ]; then
    echo "ERROR: Checksum verification FAILED"
    echo "The downloaded files may have been tampered with or corrupted."
    echo "For development, re-run with --skip-checksum"
    exit 1
  fi
  
  echo "Checksum verification OK"
  return 0
}

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
if [ "$PLATFORM" != "mac" ] && [ "$PLATFORM" != "wsl" ]; then
  echo "Error: peon-ping requires macOS or WSL (Windows Subsystem for Linux)"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required"
  exit 1
fi

if [ "$PLATFORM" = "mac" ]; then
  if ! command -v afplay &>/dev/null; then
    echo "Error: afplay is required (should be built into macOS)"
    exit 1
  fi
elif [ "$PLATFORM" = "wsl" ]; then
  if ! command -v powershell.exe &>/dev/null; then
    echo "Error: powershell.exe is required (should be available in WSL)"
    exit 1
  fi
  if ! command -v wslpath &>/dev/null; then
    echo "Error: wslpath is required (should be built into WSL)"
    exit 1
  fi
fi

if [ ! -d "$HOME/.claude" ]; then
  echo "Error: ~/.claude/ not found. Is Claude Code installed?"
  exit 1
fi

# --- Detect installation locations ---
LOCAL_DIR="$PWD/.claude/hooks/peon-ping"
GLOBAL_DIR="$HOME/.claude/hooks/peon-ping"

remove_installation() {
  local target_dir="$1"
  local install_type="$2"
  
  echo ""
  echo "Removing $install_type installation..."
  
  # Remove from settings.json
  if [ -f "$SETTINGS" ]; then
    python3 -c "
import json
import os
import sys

settings_path = '$SETTINGS'
hook_name = os.path.basename('$target_dir')

try:
    with open(settings_path, 'r') as f:
        settings = json.load(f)
    
    modified = False
    for key in ['hooks', 'userHooks']:
        if key in settings and isinstance(settings[key], dict):
            # Remove any hook that contains our hook_name
            to_remove = [k for k in settings[key].keys() if hook_name in settings[key][k]]
            for k in to_remove:
                del settings[key][k]
                modified = True
    
    if modified:
        with open(settings_path, 'w') as f:
            json.dump(settings, f, indent=2)
        print(f'Removed hooks from {settings_path}')
except Exception as e:
    print(f'Warning: Could not update settings: {e}', file=sys.stderr)
" 2>/dev/null || true
  fi
  
  # Remove directory
  rm -rf "$target_dir"
  echo "$install_type installation removed."
}

check_conflict_and_resolve() {
  local install_mode="$1"
  
  if [ "$install_mode" = "global" ]; then
    if [ -f "$LOCAL_DIR/peon.sh" ]; then
      echo ""
      echo "=== Conflict: Local Installation Exists ==="
      echo ""
      echo "You have peon-ping installed locally at:"
      echo "  $LOCAL_DIR"
      echo ""
      echo "Cannot install globally while local installation exists."
      echo "Options:"
      echo "  1. Remove local installation and install globally"
      echo "  2. Keep local installation and abort"
      echo ""
      read -p "Remove local installation? (y/N): " -n 1 -r
      echo
      if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        remove_installation "$LOCAL_DIR" "local"
      else
        echo "Aborted. Local installation kept."
        exit 0
      fi
    fi
  elif [ "$install_mode" = "local" ]; then
    if [ -f "$GLOBAL_DIR/peon.sh" ]; then
      echo ""
      echo "=== Conflict: Global Installation Exists ==="
      echo ""
      echo "You have peon-ping installed globally at:"
      echo "  $GLOBAL_DIR"
      echo ""
      echo "Cannot install locally while global installation exists."
      echo "Options:"
      echo "  1. Remove global installation and install locally"
      echo "  2. Keep global installation and abort"
      echo ""
      read -p "Remove global installation? (y/N): " -n 1 -r
      echo
      if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        remove_installation "$GLOBAL_DIR" "global"
      else
        echo "Aborted. Global installation kept."
        exit 0
      fi
    fi
  fi
}

check_conflict_and_resolve "$INSTALL_MODE"

# --- Detect if running from local clone or curl|bash ---
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "bash" ]; then
  CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [ -f "$CANDIDATE/peon.sh" ]; then
    SCRIPT_DIR="$CANDIDATE"
  fi
fi

REPO_BASE=$(detect_repo_info)
CLONE_URL=$(detect_clone_url)

# --- Auto-clone if not in git repo ---
if [ -z "$SCRIPT_DIR" ] && ! is_git_repo; then
  if command -v git &>/dev/null; then
    # Auto-clone to /tmp
    TEMP_DIR=$(mktemp -d "/tmp/peon-ping-XXXXXX")
    echo "Cloning peon-ping to temporary directory..."
    if git clone --depth 1 "$CLONE_URL" "$TEMP_DIR" 2>/dev/null; then
      SCRIPT_DIR="$TEMP_DIR"
      echo "Cloned to $SCRIPT_DIR"
    else
      echo "Warning: Failed to clone repository. Falling back to curl download."
    fi
  else
    # git not available - show warning and require confirmation
    echo ""
    echo "=============================================="
    echo "WARNING: git is not installed on this system."
    echo "=============================================="
    echo ""
    echo "Running curl|bash without git limits your ability to:"
    echo "  - Verify the code before execution"
    echo "  - Easily receive updates"
    echo "  - Contribute or inspect changes"
    echo ""
    echo "For better security, install git and re-run:"
    echo "  git clone $CLONE_URL"
    echo "  cd peon-ping"
    echo "  ./install.sh"
    echo ""
    echo "Alternatively, re-run with --skip-checksum to bypass this message"
    echo ""
    read -p "Type \"I understand the risks\" to continue: " -r
    echo
    if [[ "$REPLY" != "I understand the risks" ]]; then
      echo "Aborted. Install git or use a local clone for safer installation."
      exit 0
    fi
  fi
fi

# --- Install/update core files ---
for pack in $PACKS; do
  mkdir -p "$INSTALL_DIR/packs/$pack/sounds"
done

if [ -n "$SCRIPT_DIR" ]; then
  # Local clone — copy files directly (including sounds)
  cp -r "$SCRIPT_DIR/packs/"* "$INSTALL_DIR/packs/"
  cp "$SCRIPT_DIR/peon.sh" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/completions.bash" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/VERSION" "$INSTALL_DIR/"
  cp "$SCRIPT_DIR/uninstall.sh" "$INSTALL_DIR/"
  if [ "$UPDATING" = false ]; then
    cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/"
  fi
else
  # curl|bash — download from GitHub (sounds are version-controlled in repo)
  echo "Downloading from GitHub..."
  curl -fsSL "$REPO_BASE/peon.sh" -o "$INSTALL_DIR/peon.sh"
  curl -fsSL "$REPO_BASE/completions.bash" -o "$INSTALL_DIR/completions.bash"
  curl -fsSL "$REPO_BASE/VERSION" -o "$INSTALL_DIR/VERSION"
  curl -fsSL "$REPO_BASE/uninstall.sh" -o "$INSTALL_DIR/uninstall.sh"
  for pack in $PACKS; do
    curl -fsSL "$REPO_BASE/packs/$pack/manifest.json" -o "$INSTALL_DIR/packs/$pack/manifest.json"
  done
  # Download sound files for each pack
  for pack in $PACKS; do
    manifest="$INSTALL_DIR/packs/$pack/manifest.json"
    # Extract sound filenames from manifest and download each one
    python3 -c "
import json
m = json.load(open('$manifest'))
seen = set()
for cat in m.get('categories', {}).values():
    for s in cat.get('sounds', []):
        f = s['file']
        if f not in seen:
            seen.add(f)
            print(f)
" | while read -r sfile; do
      curl -fsSL "$REPO_BASE/packs/$pack/sounds/$sfile" -o "$INSTALL_DIR/packs/$pack/sounds/$sfile" </dev/null
    done
  done
  if [ "$UPDATING" = false ]; then
    curl -fsSL "$REPO_BASE/config.json" -o "$INSTALL_DIR/config.json"
  fi
  verify_checksums "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/peon.sh"

# --- Install skill (slash command) ---
SKILL_DIR="$HOME/.claude/skills/peon-ping-toggle"
mkdir -p "$SKILL_DIR"
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/skills/peon-ping-toggle" ]; then
  cp "$SCRIPT_DIR/skills/peon-ping-toggle/SKILL.md" "$SKILL_DIR/"
elif [ -z "$SCRIPT_DIR" ]; then
  curl -fsSL "$REPO_BASE/skills/peon-ping-toggle/SKILL.md" -o "$SKILL_DIR/SKILL.md"
else
  echo "Warning: skills/peon-ping-toggle not found in local clone, skipping skill install"
fi

# --- Add shell alias (global only) ---
if [ "$INSTALL_MODE" = "global" ]; then
  ALIAS_LINE="alias peon=\"bash $HOME/.claude/hooks/peon-ping/peon.sh\""
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rcfile" ] && ! grep -qF 'alias peon=' "$rcfile"; then
      echo "" >> "$rcfile"
      echo "# peon-ping quick controls" >> "$rcfile"
      echo "$ALIAS_LINE" >> "$rcfile"
      echo "Added peon alias to $(basename "$rcfile")"
    fi
  done

  # --- Add tab completion (global only) ---
  COMPLETION_LINE='[ -f ~/.claude/hooks/peon-ping/completions.bash ] && source ~/.claude/hooks/peon-ping/completions.bash'
  for rcfile in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rcfile" ] && ! grep -qF 'peon-ping/completions.bash' "$rcfile"; then
      echo "$COMPLETION_LINE" >> "$rcfile"
      echo "Added tab completion to $(basename "$rcfile")"
    fi
  done
fi

# --- Verify sounds are installed ---
echo ""
for pack in $PACKS; do
  sound_dir="$INSTALL_DIR/packs/$pack/sounds"
  sound_count=$({ ls "$sound_dir"/*.wav "$sound_dir"/*.mp3 "$sound_dir"/*.ogg 2>/dev/null || true; } | wc -l | tr -d ' ')
  if [ "$sound_count" -eq 0 ]; then
    echo "[$pack] Warning: No sound files found!"
  else
    echo "[$pack] $sound_count sound files installed."
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

# --- Update settings.json (global only) ---
if [ "$INSTALL_MODE" = "global" ]; then
  echo ""
  echo "Updating Claude Code hooks in settings.json..."

  python3 -c "
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
events = ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']

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
else
  echo ""
  echo "Local installation complete."
  echo "To use this hook, add it to your project's .claude/settings.json:"
  echo ""
  echo '  {'
  echo '    "hooks": {'
  echo '      "SessionStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "'"$PWD"'/.claude/hooks/peon-ping/peon.sh", "timeout": 10 }] }],'
  echo '      ...'
  echo '    }'
  echo '  }'
fi

# --- Initialize state (fresh install only) ---
if [ "$UPDATING" = false ]; then
  echo '{}' > "$INSTALL_DIR/.state.json"
fi

# --- Test sound ---
echo ""
echo "Testing sound..."
ACTIVE_PACK=$(python3 -c "
import json, os
try:
    c = json.load(open('$INSTALL_DIR/config.json'))
    print(c.get('active_pack', 'peon'))
except:
    print('peon')
" 2>/dev/null)
PACK_DIR="$INSTALL_DIR/packs/$ACTIVE_PACK"
TEST_SOUND=$({ ls "$PACK_DIR/sounds/"*.wav "$PACK_DIR/sounds/"*.mp3 "$PACK_DIR/sounds/"*.ogg 2>/dev/null || true; } | head -1)
if [ -n "$TEST_SOUND" ]; then
  if [ "$PLATFORM" = "mac" ]; then
    afplay -v 0.3 "$TEST_SOUND"
  elif [ "$PLATFORM" = "wsl" ]; then
    wpath=$(wslpath -w "$TEST_SOUND")
    # Convert backslashes to forward slashes for file:/// URI
    wpath="${wpath//\\//}"
    powershell.exe -NoProfile -NonInteractive -Command "
      Add-Type -AssemblyName PresentationCore
      \$p = New-Object System.Windows.Media.MediaPlayer
      \$p.Open([Uri]::new('file:///$wpath'))
      \$p.Volume = 0.3
      Start-Sleep -Milliseconds 200
      \$p.Play()
      Start-Sleep -Seconds 3
      \$p.Close()
    " 2>/dev/null
  fi
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
  if [ "$INSTALL_MODE" = "global" ]; then
    echo "Installed globally at: $INSTALL_DIR"
  else
    echo "Installed locally at: $INSTALL_DIR"
  fi
  echo ""
  echo "Config: $INSTALL_DIR/config.json"
  echo "  - Adjust volume, toggle categories, switch packs"
  echo ""
  echo "Uninstall: bash $INSTALL_DIR/uninstall.sh"
fi

if [ "$INSTALL_MODE" = "global" ]; then
  echo ""
  echo "Quick controls:"
  echo "  /peon-ping-toggle  — toggle sounds in Claude Code"
  echo "  peon --toggle      — toggle sounds from any terminal"
  echo "  peon --status      — check if sounds are paused"
fi

echo ""
echo "Ready to work!"
