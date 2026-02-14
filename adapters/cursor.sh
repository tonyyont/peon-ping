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

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

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
