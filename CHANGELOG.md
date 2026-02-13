# Changelog

## v1.8.0 (2026-02-13)

### Added
- **Native Windows support**: PowerShell installer (`install.ps1`), hook script (`peon.ps1`), and uninstaller with two-tier audio fallback (WPF MediaPlayer + SoundPlayer) ([#105](https://github.com/PeonPing/peon-ping/pull/105))
- **Windsurf adapter**: Full CESP adapter for Windsurf Cascade hooks with session tracking ([#130](https://github.com/PeonPing/peon-ping/pull/130))
- **Kilo CLI adapter**: Native TypeScript plugin for Kilo CLI (OpenCode fork) ([#129](https://github.com/PeonPing/peon-ping/pull/129))
- **Install progress bar**: Live-updating per-pack progress bar in TTY mode, dot-based fallback for non-TTY ([#121](https://github.com/PeonPing/peon-ping/pull/121))
- **OpenCode adapter tests**: 21 BATS tests covering install, uninstall, idempotency, XDG support, and icon replacement ([#131](https://github.com/PeonPing/peon-ping/pull/131))

### Fixed
- Fix code injection vulnerability in `peon packs use/remove` — pack args now passed via env vars ([#127](https://github.com/PeonPing/peon-ping/pull/127))
- Fix `pw-play` silent on non-English locales by setting `LC_ALL=C` ([#124](https://github.com/PeonPing/peon-ping/pull/124))
- Fix Telegram API call to use POST body instead of URL params ([#128](https://github.com/PeonPing/peon-ping/pull/128))
- Replace bare `except:` clauses with `except Exception:` across all embedded Python ([#126](https://github.com/PeonPing/peon-ping/pull/126))
- Remove broken symlink before curl download in OpenCode adapter ([#125](https://github.com/PeonPing/peon-ping/pull/125))
- Remove Claude Code paths from OpenCode icon resolution ([#123](https://github.com/PeonPing/peon-ping/pull/123))
- Fix race condition in peon.bats (background afplay timing)
- Fix install.bats `--local` tests to check correct settings.json path

## v1.7.1 (2026-02-13)

### Fixed
- `peon packs list` and other CLI commands now work correctly for Homebrew installs ([#101](https://github.com/PeonPing/peon-ping/issues/101))

## v1.7.0 (2026-02-12)

### Added
- **SSH remote audio support**: Auto-detects SSH sessions and routes audio through a relay server running on your local machine (`peon relay`)
- **Relay daemon mode**: `peon relay --daemon`, `--stop`, `--status` for persistent background relay
- **Devcontainer / Codespaces support**: Auto-detects container environments and routes audio to `host.docker.internal`
- **Mobile push notifications**: `peon mobile ntfy|pushover|telegram` — get phone notifications via ntfy.sh, Pushover, or Telegram
- **Enhanced `peon status`**: Shows active pack, installed pack count, and detected IDE ([#91](https://github.com/PeonPing/peon-ping/pull/91))
- **Relay test suite**: 20 tests covering health, playback, path traversal protection, notifications, and daemon mode
- **Automated Homebrew tap updates**: Release workflow now auto-updates `PeonPing/homebrew-tap`

### Fixed
- Prevent duplicate hooks when both global and local installs exist
- Correct Ghostty process name casing in focus detection ([#92](https://github.com/PeonPing/peon-ping/pull/92))
- Suppress replay sounds during session continue ([#19](https://github.com/PeonPing/peon-ping/issues/19))
- Harden installer reliability ([#93](https://github.com/PeonPing/peon-ping/pull/93))

## v1.6.0 (2026-02-12)

### Breaking
- **Subcommand CLI**: All `--flag` commands replaced with subcommands. `peon --pause` is now `peon pause`, `peon --packs` is now `peon packs list`, etc. ([#90](https://github.com/PeonPing/peon-ping/pull/90))

### Added
- **Homebrew install**: `brew install PeonPing/tap/peon-ping` as primary install method
- **Multi-IDE messaging**: Updated all docs and landing page to highlight Claude Code, Codex, Cursor, and OpenCode support
- **`peon packs remove`**: Uninstall specific packs without removing everything ([#89](https://github.com/PeonPing/peon-ping/pull/89))
- **`peonping.com/install` redirect**: Clean install URL via Vercel redirect
- **Dynamic pack counts**: peonping.com fetches live pack count from registry at runtime
- **Session replay suppression**: Sounds no longer fire 3x when continuing a session with `claude -c` ([#19](https://github.com/PeonPing/peon-ping/issues/19))

### Fixed
- Handle read-only shell rc files during install ([#86](https://github.com/PeonPing/peon-ping/issues/86))
- Fix raw escape codes in OpenCode adapter output ([#88](https://github.com/PeonPing/peon-ping/pull/88))
- Fix OpenCode adapter registry lookup and add missing plugin file

## v1.5.14 (2026-02-12)

### Added
- **Registry-based pack discovery**: install.sh fetches packs from the [OpenPeon registry](https://github.com/PeonPing/registry) instead of bundling sounds in the repo
- **CESP standard**: Migrated to the [Coding Event Sound Pack Specification](https://github.com/PeonPing/openpeon) with `openpeon.json` manifests
- **Multi-IDE adapters**: Cursor (`adapters/cursor.sh`), Codex (`adapters/codex.sh`), OpenCode (`adapters/opencode.sh`)
- **`--packs` flag**: Install specific packs by name (`--packs=peon,glados,peasant`)
- **Interactive pack picker**: peonping.com lets you select packs and generates a custom install command
- **`silent_window_seconds`**: Suppress sounds for tasks shorter than N seconds ([#82](https://github.com/PeonPing/peon-ping/pull/82))
- **Help on bare invocation**: Running `peon` with no args on a TTY shows usage ([#83](https://github.com/PeonPing/peon-ping/pull/83))
- **Desktop notification toggle**: Independent `desktop_notifications` config option ([#47](https://github.com/PeonPing/peon-ping/issues/47))
- **Duke Nukem** sound pack
- **Red Alert Soviet Soldier** sound pack

### Fixed
- Missing sound file references in several packs
- zsh completions `bashcompinit` ordering

## v1.4.0 (2026-02-12)

### Added
- **Stop debouncing**: Prevents sound spam from rapid background task completions
- **Pack rotation**: Configure multiple packs in `pack_rotation`, each session picks one randomly
- **CLAUDE_CONFIG_DIR** support for non-standard Claude installs ([#61](https://github.com/PeonPing/peon-ping/pull/61))
- **13 community sound packs**: Czech (peon_cz, peasant_cz), Spanish (peon_es, peasant_es), RA2 Kirov, WC2 Peasant, AoE2, Russian Brewmaster, Elder Scrolls (Molag Bal, Sheogorath), Dota 2 Axe, Helldivers 2, Sopranos, Rick Sanchez

## v1.2.0 (2026-02-11)

### Added
- **WSL2 (Windows) support**: PowerShell `MediaPlayer` audio backend with visual popup notifications
- **PermissionRequest hook**: Sound alert when IDE needs permission approval
- **`peon --pack` command**: Switch packs from CLI with tab completion and cycling
- **Performance**: Consolidated 5 Python invocations into 1 per hook event
- **Polish Orc Peon** sound pack ([#9](https://github.com/PeonPing/peon-ping/pull/9))
- **French packs**: Human Peasant (FR) and Orc Peon (FR) ([#7](https://github.com/PeonPing/peon-ping/pull/7))

### Fixed
- Prevent install.sh from hanging when run via `curl | bash` ([#8](https://github.com/PeonPing/peon-ping/pull/8))

## v1.1.0 (2026-02-11)

### Added
- **Pause/mute toggle**: `peon --toggle` CLI and `/peon-ping-toggle` slash command ([#6](https://github.com/PeonPing/peon-ping/pull/6))
- **Battlecruiser + Kerrigan** sound packs
- **RA2 Soviet Engineer** sound pack
- **Self-update check**: Checks for new versions once per day
- **BATS test suite**: 30+ automated tests with CI ([#5](https://github.com/PeonPing/peon-ping/pull/5))
- **Terminal-agnostic tab titles**: ANSI escape sequences instead of AppleScript ([#3](https://github.com/PeonPing/peon-ping/pull/3))

### Fixed
- Hook runner compatibility ([#5](https://github.com/PeonPing/peon-ping/pull/5))

## v1.0.0 (2026-02-10)

### Added
- Initial release
- Warcraft III Orc Peon and GLaDOS sound packs
- Claude Code hook for `SessionStart`, `UserPromptSubmit`, `Stop`, `Notification`
- Desktop notifications (macOS)
- Terminal tab title updates
- Agent session detection (suppress sounds in delegate mode)
- macOS + Linux audio support
