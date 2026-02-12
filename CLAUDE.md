# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

peon-ping is a Claude Code hook that plays game character voice lines and sends desktop notifications when Claude Code needs attention. It handles 5 hook events: `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`, `PermissionRequest`. Written entirely in bash + embedded Python (no npm/node runtime needed).

## Commands

```bash
# Run all tests (requires bats-core: brew install bats-core)
bats tests/

# Run a single test file
bats tests/peon.bats
bats tests/install.bats

# Run a specific test by name
bats tests/peon.bats -f "plays session.start sound"

# Install locally for development
bash install.sh --local

# Install only specific packs
bash install.sh --packs=peon,glados,peasant
```

There is no build step, linter, or formatter configured for the shell codebase.

## Architecture

### Core Files

- **`peon.sh`** — Main hook script. Receives JSON event data on stdin from Claude Code, routes events via an embedded Python block that handles config loading, event parsing, sound selection, and state management in a single invocation. Shell code then handles async audio playback (`nohup` + background processes) and desktop notifications.
- **`install.sh`** — Installer. Fetches pack registry from GitHub Pages, downloads selected packs, registers hooks in `~/.claude/settings.json`.
- **`config.json`** — Default configuration template.

### Event Flow

Claude Code triggers hook → `peon.sh` reads JSON stdin → single Python call maps events to CESP categories (`session.start`, `task.complete`, `input.required`, `user.spam`, etc.) → picks a sound (no-repeat logic) → shell plays audio async and optionally sends desktop notification.

### Platform Audio Backends

- **macOS:** `afplay`
- **WSL2:** PowerShell `MediaPlayer`
- **Linux:** priority chain: `pw-play` → `paplay` → `ffplay` → `mpv` → `play` (SoX) → `aplay` (each with different volume scaling)

### State Management

`.state.json` persists across invocations: agent session tracking (suppresses sounds in delegate mode), pack rotation index, prompt timestamps (for annoyed easter egg), last-played sounds (no-repeat), and stop debouncing.

### Multi-IDE Adapters

`adapters/cursor.sh` and `adapters/codex.sh` translate IDE-specific events into the standardized CESP JSON format that `peon.sh` expects.

### Pack Format

Packs use `openpeon.json` (CESP standard) with categories mapping to arrays of `{ "file": "sound.wav", "label": "text" }` entries. Packs are downloaded from the [OpenPeon registry](https://github.com/PeonPing/registry) at install time into `~/.peon-ping/packs/`.

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System). Test setup (`tests/setup.bash`) creates isolated temp directories with mock audio backends, manifests, and config so tests never touch real state. Key mock: `afplay` is replaced with a script that logs calls instead of playing audio.

CI runs on macOS (`macos-latest`) via GitHub Actions.

## Skills

Two Claude Code skills live in `skills/`:
- `/peon-ping-toggle` — Mute/unmute sounds
- `/peon-ping-config` — Modify any peon-ping setting (volume, packs, categories, etc.)

## Website

`docs/` contains the static landing page (peonping.com), deployed via Vercel. `video/` is a separate Remotion project for promotional videos (React + TypeScript, independent from the main codebase).
