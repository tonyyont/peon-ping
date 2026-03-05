#!/bin/bash
# peon-ping adapter for Cursor IDE
# Translates Cursor hook events into peon.sh stdin JSON
#
# Setup: Add to ~/.cursor/hooks.json:
#   {
#     "hooks": [
#       {
#         "event": "stop",
#         "command": "bash ~/.claude/hooks/peon-ping/adapters/cursor.sh stop"
#       },
#       {
#         "event": "beforeShellExecution",
#         "command": "bash ~/.claude/hooks/peon-ping/adapters/cursor.sh beforeShellExecution"
#       }
#     ]
#   }

set -euo pipefail

# Resolve PEON_DIR: check candidate locations in order, verify peon.sh exists in each.
_resolve_peon_dir() {
  local candidates=(
    "${PEON_DIR:-}"
    "${CLAUDE_PEON_DIR:-}"
    "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
    "$HOME/.openpeon"
  )
  for dir in "${candidates[@]}"; do
    if [ -n "$dir" ] && [ -f "$dir/peon.sh" ]; then
      echo "$dir"
      return
    fi
  done
  echo "[peon-ping/cursor] ERROR: peon.sh not found in any candidate directory" >&2
  echo "[peon-ping/cursor] Tried: PEON_DIR, CLAUDE_PEON_DIR, ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping, $HOME/.openpeon" >&2
  exit 1
}

PEON_DIR="$(_resolve_peon_dir)"

CURSOR_EVENT="${1:-stop}"

case "$CURSOR_EVENT" in
  stop)
    EVENT="Stop"
    ;;
  beforeShellExecution)
    EVENT="UserPromptSubmit"
    ;;
  beforeMCPExecution)
    EVENT="UserPromptSubmit"
    ;;
  afterFileEdit)
    EVENT="Stop"
    ;;
  beforeReadFile)
    # Too noisy — skip
    exit 0
    ;;
  *)
    EVENT="Stop"
    ;;
esac

# Cursor sends JSON with conversation_id in stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.conversation_id // empty')
[ -z "$SESSION_ID" ] && SESSION_ID="cursor-$$"
CWD=$(echo "$INPUT" | jq -r '.workspace_roots[0] // .cwd // ""')
[ -z "$CWD" ] && CWD="${PWD}"

echo "$INPUT" | jq --arg event "$EVENT" --arg sid "$SESSION_ID" --arg cwd "$CWD" \
  '{hook_event_name: $event, notification_type: "", cwd: $cwd, session_id: $sid, permission_mode: ""}' \
  | bash "$PEON_DIR/peon.sh"
