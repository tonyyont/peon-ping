# peon-ping

![macOS](https://img.shields.io/badge/macOS-blue) ![WSL2](https://img.shields.io/badge/WSL2-blue) ![Linux](https://img.shields.io/badge/Linux-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Claude Code](https://img.shields.io/badge/Claude_Code-hook-ffab01)

**Your Peon pings you when Claude Code needs attention.**

Claude Code doesn't notify you when it finishes or needs permission. You tab away, lose focus, and waste 15 minutes getting back into flow. peon-ping fixes this with Warcraft III Peon voice lines — so you never miss a beat, and your terminal sounds like Orgrimmar.

**See it in action** &rarr; [peonping.com](https://peonping.com/)

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash
```

One command. Takes 10 seconds. macOS, WSL2 (Windows), and Linux. Re-run to update (sounds and config preserved). Installs 10 curated English packs by default.

**Install all 36 packs** (every language and franchise):

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --all
```

**Project-local install** — installs into `.claude/` in the current project instead of `~/.claude/`:

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- --local
```

Local installs don't add the `peon` CLI alias or shell completions — use `/peon-ping-toggle` inside Claude Code instead.

## What you'll hear

| Event | CESP Category | Examples |
|---|---|---|
| Session starts | `session.start` | *"Ready to work?"*, *"Yes?"*, *"What you want?"* |
| Task finishes | `task.complete` | *"Work, work."*, *"I can do that."*, *"Okie dokie."* |
| Permission needed | `input.required` | *"Something need doing?"*, *"Hmm?"*, *"What you want?"* |
| Rapid prompts (3+ in 10s) | `user.spam` | *"Me busy, leave me alone!"* |

Plus Terminal tab titles (`● project: done`) and desktop notifications when your terminal isn't focused.

peon-ping implements the [Coding Event Sound Pack Specification (CESP)](https://github.com/PeonPing/openpeon) — an open standard for coding event sounds that any agentic IDE can adopt.

## Quick controls

Need to mute sounds and notifications during a meeting or pairing session? Two options:

| Method | Command | When |
|---|---|---|
| **Slash command** | `/peon-ping-toggle` | While working in Claude Code |
| **CLI** | `peon --toggle` | From any terminal tab |

Other CLI commands:

```bash
peon --pause              # Mute sounds
peon --resume             # Unmute sounds
peon --status             # Check if paused or active
peon --packs              # List available sound packs
peon --pack <name>        # Switch to a specific pack
peon --pack               # Cycle to the next pack
peon --notifications-on   # Enable desktop notifications
peon --notifications-off  # Disable desktop notifications
```

Tab completion is supported — type `peon --pack <TAB>` to see available pack names.

Pausing mutes sounds and desktop notifications instantly. Persists across sessions until you resume. Tab titles remain active when paused.

## Configuration

peon-ping installs a `/peon-ping-toggle` slash command in Claude Code. You can also just ask Claude to change settings for you — e.g. "enable round-robin pack rotation", "set volume to 0.3", or "add glados to my pack rotation". No need to edit config files manually.

The config lives at `$CLAUDE_CONFIG_DIR/hooks/peon-ping/config.json` (default: `~/.claude/hooks/peon-ping/config.json`):

```json
{
  "volume": 0.5,
  "categories": {
    "session.start": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  }
}
```

- **volume**: 0.0–1.0 (quiet enough for the office)
- **desktop_notifications**: `true`/`false` — toggle desktop notification popups independently from sounds (default: `true`)
- **categories**: Toggle individual CESP sound categories on/off (e.g. `"session.start": false` to disable greeting sounds)
- **annoyed_threshold / annoyed_window_seconds**: How many prompts in N seconds triggers the `user.spam` easter egg
- **pack_rotation**: Array of pack names (e.g. `["peon", "sc_kerrigan", "peasant"]`). Each session randomly gets one pack from the list and keeps it for the whole session. Leave empty `[]` to use `active_pack` instead.

## Multi-IDE Support

peon-ping works with any agentic IDE that supports hooks. Adapters translate IDE-specific events to the [CESP standard](https://github.com/PeonPing/openpeon).

| IDE | Status | Setup |
|---|---|---|
| **Claude Code** | Built-in | `curl \| bash` install handles everything |
| **OpenAI Codex** | Adapter | Add `command = "bash ~/.claude/hooks/peon-ping/adapters/codex.sh"` to `~/.codex/config.toml` under `[notify]` |
| **Cursor** | Adapter | Add hook entries to `~/.cursor/hooks.json` pointing to `adapters/cursor.sh` |
| **OpenCode** | Adapter | `curl -fsSL .../adapters/opencode.sh \| bash` — installs TypeScript plugin to `~/.config/opencode/plugins/` |

## Sound packs

36 packs across Warcraft, StarCraft, Red Alert, Portal, Dota 2, Helldivers 2, Elder Scrolls, and more. The default install includes 10 curated English packs:

| Pack | Character | Sounds |
|---|---|---|
| `peon` (default) | Orc Peon (Warcraft III) | "Ready to work?", "Work, work.", "Okie dokie." |
| `peasant` | Human Peasant (Warcraft III) | "Yes, milord?", "Job's done!", "Ready, sir." |
| `glados` | GLaDOS (Portal) | "Oh, it's you.", "You monster.", "Your entire team is dead." |
| `sc_kerrigan` | Sarah Kerrigan (StarCraft) | "I gotcha", "What now?", "Easily amused, huh?" |
| `sc_battlecruiser` | Battlecruiser (StarCraft) | "Battlecruiser operational", "Make it happen", "Engage" |
| `ra2_kirov` | Kirov Airship (Red Alert 2) | "Kirov reporting", "Bombardiers to your stations" |
| `dota2_axe` | Axe (Dota 2) | "Axe is ready!", "Axe-actly!", "Come and get it!" |
| `duke_nukem` | Duke Nukem | "Hail to the king!", "Groovy.", "Balls of steel." |
| `tf2_engineer` | Engineer (Team Fortress 2) | "Sentry going up.", "Nice work!", "Cowboy up!" |
| `hd2_helldiver` | Helldiver (Helldivers 2) | "For democracy!", "How 'bout a nice cup of Liber-tea?" |

**[Browse all 36 packs with audio previews &rarr; openpeon.com/packs](https://openpeon.com/packs)**

Install all 36 with `--all`, or switch packs anytime:

```bash
peon --pack glados                # switch to a specific pack
peon --pack                       # cycle to the next pack
peon --packs                      # list all installed packs
```

Want to add your own pack? See the [full guide at openpeon.com/create](https://openpeon.com/create) or [CONTRIBUTING.md](CONTRIBUTING.md).

## Uninstall

```bash
bash "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/hooks/peon-ping/uninstall.sh        # global
bash .claude/hooks/peon-ping/uninstall.sh           # project-local
```

## Requirements

- macOS (uses `afplay` and AppleScript), WSL2 (uses PowerShell `MediaPlayer` and WinForms), or Linux (uses `pw-play`/`paplay`/`ffplay`/`mpv`/`aplay` and `notify-send`)
- Claude Code with hooks support
- python3

## How it works

`peon.sh` is a Claude Code hook registered for `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, and `PermissionRequest` events. On each event it maps to a CESP sound category, picks a random voice line (avoiding repeats), plays it via `afplay` (macOS), PowerShell `MediaPlayer` (WSL2), or `paplay`/`ffplay`/`mpv`/`aplay` (Linux), and updates your Terminal tab title.

Sound packs are downloaded from the [OpenPeon registry](https://github.com/PeonPing/registry) at install time. The original 36 packs are hosted in [PeonPing/og-packs](https://github.com/PeonPing/og-packs). Sound files are property of their respective publishers (Blizzard, Valve, EA, etc.) and are distributed under fair use for personal notification purposes.

## Links

- [peonping.com](https://peonping.com/) — landing page
- [openpeon.com](https://openpeon.com/) — CESP spec, pack browser, creation guide
- [OpenPeon registry](https://github.com/PeonPing/registry) — pack registry (GitHub Pages)
- [og-packs](https://github.com/PeonPing/og-packs) — the original 36 sound packs
- [License (MIT)](LICENSE)
