#!/bin/bash
# peon-ping adapter for OpenAI Codex CLI
# Translates Codex notify events into peon.sh stdin JSON
#
# Setup: Add to ~/.codex/config.toml:
#   notify = ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/codex.sh"]
#
# Or if installed locally:
#   notify = ["bash", "/absolute/path/to/peon-ping/adapters/codex.sh"]

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
PEON_SH="$PEON_DIR/peon.sh"
[ -f "$PEON_SH" ] || exit 0

# Codex notifies with limited payload; accept event arg and optional stdin JSON.
CODEX_EVENT="${1:-}"
if [ -t 0 ]; then
  CODEX_STDIN=""
else
  CODEX_STDIN="$(cat)"
fi

_CODEX_EVENT="$CODEX_EVENT" _CODEX_STDIN="$CODEX_STDIN" python3 - <<'PY' | bash "$PEON_SH"
import json
import os
import re


def first_non_empty(*values):
    for value in values:
        if value is None:
            continue
        if isinstance(value, str):
            if value.strip():
                return value.strip()
        else:
            return value
    return ""


raw_stdin = os.environ.get("_CODEX_STDIN", "").strip()
event_data = {}
if raw_stdin:
    try:
        parsed = json.loads(raw_stdin)
        if isinstance(parsed, dict):
            event_data = parsed
    except Exception:
        event_data = {}

workspace_roots = event_data.get("workspace_roots")
root0 = ""
if isinstance(workspace_roots, list) and workspace_roots:
    root0 = str(workspace_roots[0] or "")

raw_event = first_non_empty(
    os.environ.get("_CODEX_EVENT", ""),
    event_data.get("hook_event_name", ""),
    event_data.get("event", ""),
    event_data.get("type", ""),
    "agent-turn-complete",
)
event_key = str(raw_event).strip().lower().replace("_", "-")

notif_type = str(event_data.get("notification_type", "")).strip().lower()
if (
    event_key.startswith("permission")
    or event_key.startswith("approve")
    or event_key in ("approval-requested", "approval-needed", "input-required")
    or notif_type == "permission_prompt"
):
    mapped_event = "Notification"
    mapped_ntype = "permission_prompt"
elif event_key in ("start", "session-start"):
    mapped_event = "SessionStart"
    mapped_ntype = notif_type
elif event_key == "idle-prompt":
    mapped_event = "Notification"
    mapped_ntype = "idle_prompt"
elif event_key.startswith("error") or event_key.startswith("fail"):
    mapped_event = "PostToolUseFailure"
    mapped_ntype = notif_type
else:
    mapped_event = "Stop"
    mapped_ntype = notif_type

cwd = str(
    first_non_empty(
        event_data.get("cwd", ""),
        event_data.get("workspace_root", ""),
        root0,
        os.environ.get("CODEX_CWD", ""),
        os.environ.get("PWD", ""),
        "/",
    )
)

raw_session_id = str(
    first_non_empty(
        event_data.get("session_id", ""),
        event_data.get("conversation_id", ""),
        event_data.get("thread_id", ""),
        os.environ.get("CODEX_SESSION_ID", ""),
        os.getpid(),
    )
)
safe_session_id = re.sub(r"[^A-Za-z0-9._:-]", "-", raw_session_id).strip("-")
if not safe_session_id:
    safe_session_id = str(os.getpid())
session_id = f"codex-{safe_session_id}"

payload = {
    "hook_event_name": mapped_event,
    "notification_type": mapped_ntype,
    "cwd": cwd,
    "session_id": session_id,
    "permission_mode": str(event_data.get("permission_mode", "")),
    "source": "codex",
}

summary = first_non_empty(
    event_data.get("transcript_summary", ""),
    event_data.get("summary", ""),
)
if isinstance(summary, str) and summary:
    payload["transcript_summary"] = summary[:120]

tool_name = first_non_empty(event_data.get("tool_name", ""), event_data.get("tool", ""))
if mapped_event == "PostToolUseFailure" and not tool_name:
    tool_name = "Bash"
if isinstance(tool_name, str) and tool_name:
    payload["tool_name"] = tool_name[:64]

error = first_non_empty(event_data.get("error", ""), event_data.get("message", ""))
if mapped_event == "PostToolUseFailure":
    if not error:
        error = f"Codex event: {raw_event}"
    payload["error"] = str(error)[:180]

print(json.dumps(payload))
PY
