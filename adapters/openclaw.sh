#!/bin/bash
# peon-ping adapter for OpenClaw gateway agents
# Translates OpenClaw events into peon.sh stdin JSON
#
# Setup: Add play.sh to your OpenClaw skill, or call this adapter directly:
#   bash adapters/openclaw.sh <event>
#
# Events:
#   session.start    — Agent session started
#   task.complete    — Agent finished a task
#   task.error       — Agent encountered an error
#   input.required   — Agent needs user input
#   task.acknowledge — Agent acknowledged a task
#   user.spam        — Too many rapid prompts
#
# Or use Claude Code hook event names:
#   SessionStart, Stop, Notification, UserPromptSubmit

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
[ -d "$PEON_DIR" ] || PEON_DIR="$HOME/.openpeon"

if [ ! -f "$PEON_DIR/peon.sh" ]; then
  echo "peon-ping not installed. Run: brew install PeonPing/tap/peon-ping" >&2
  exit 1
fi

OC_EVENT="${1:-task.complete}"

# Map CESP category names to Claude Code hook events (which peon.sh expects)
case "$OC_EVENT" in
  session.start|greeting|ready)
    EVENT="SessionStart"
    ;;
  task.complete|complete|done)
    EVENT="Stop"
    ;;
  task.acknowledge|acknowledge|ack)
    EVENT="UserPromptSubmit"
    ;;
  task.error|error|fail)
    EVENT="Stop"
    # peon.sh detects errors from transcript content; force error category
    # by setting a non-zero exit in the transcript
    ;;
  input.required|permission|input|waiting)
    EVENT="Notification"
    NTYPE="permission_prompt"
    ;;
  user.spam|annoyed|spam)
    EVENT="UserPromptSubmit"
    ;;
  # Also accept raw Claude Code hook event names
  SessionStart|Stop|Notification|UserPromptSubmit|PermissionRequest)
    EVENT="$OC_EVENT"
    ;;
  *)
    EVENT="Stop"
    ;;
esac

NTYPE="${NTYPE:-}"
SESSION_ID="openclaw-${OPENCLAW_SESSION_ID:-$$}"
CWD="${PWD}"

echo "{\"hook_event_name\":\"$EVENT\",\"notification_type\":\"$NTYPE\",\"cwd\":\"$CWD\",\"session_id\":\"$SESSION_ID\",\"permission_mode\":\"\"}" \
  | bash "$PEON_DIR/peon.sh"
