#!/bin/bash
# peon-ping adapter for deepagents-cli
# Translates deepagents hook events into peon.sh stdin JSON
#
# Setup: Add to ~/.deepagents/hooks.json:
#   {
#     "hooks": [
#       {
#         "command": ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/deepagents.sh"],
#         "events": ["session.start", "session.end", "task.complete", "input.required", "task.error", "tool.error", "user.prompt", "permission.request", "compact"]
#       }
#     ]
#   }

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

# Read JSON payload from stdin, map event to CESP, and forward to peon.sh
MAPPED_JSON=$(jq -c --arg cwd "$PWD" --arg pid "$$" '
  # Event-to-CESP remap table
  {
    "session.start":      ["SessionStart",      ""],
    "session.end":        ["SessionEnd",        ""],
    "task.complete":      ["Stop",              ""],
    "input.required":     ["Notification",      "permission_prompt"],
    "task.error":         ["Stop",              ""],
    "tool.error":         ["Notification",      "postToolUseFailure"],
    "user.prompt":        ["UserPromptSubmit",  ""],
    "permission.request": ["PermissionRequest",  ""],
    "compact":            ["Notification",      "preCompact"]
  } as $remap |

  . as $input |
  (.thread_id // $pid) as $tid |
  ($remap[.event] // empty) |

  {
    hook_event_name:  .[0],
    notification_type: .[1],
    cwd:              $cwd,
    session_id:       ("deepagents-" + ($tid | tostring)),
    permission_mode:  "",
    tool_name:        ($input.tool_name // "")
  }
' 2>/dev/null)

# Forward to peon.sh only if jq produced a mapped event
if [ -n "$MAPPED_JSON" ]; then
  echo "$MAPPED_JSON" | bash "$PEON_DIR/peon.sh"
fi
