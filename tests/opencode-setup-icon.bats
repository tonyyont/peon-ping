#!/usr/bin/env bats

# Tests for adapters/opencode/setup-icon.sh — replaces terminal-notifier's
# icon with the peon icon.  macOS-only (sips, iconutil, brew).
# All external commands are mocked.

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SETUP_ICON_SH="$REPO_ROOT/adapters/opencode/setup-icon.sh"

  # --- Create fake peon icon ---
  mkdir -p "$TEST_HOME/.config/opencode/peon-ping"
  printf '\x89PNG\r\n' > "$TEST_HOME/.config/opencode/peon-ping/peon-icon.png"

  # --- Create fake terminal-notifier app bundle ---
  APP_DIR="$TEST_HOME/terminal-notifier.app"
  mkdir -p "$APP_DIR/Contents/MacOS"
  mkdir -p "$APP_DIR/Contents/Resources"
  echo "original-icns" > "$APP_DIR/Contents/Resources/Terminal.icns"
  cat > "$APP_DIR/Contents/MacOS/terminal-notifier" <<'SCRIPT'
#!/bin/bash
echo "terminal-notifier stub"
SCRIPT
  chmod +x "$APP_DIR/Contents/MacOS/terminal-notifier"

  # --- Mock bin directory ---
  MOCK_BIN="$(mktemp -d)"

  # Mock brew --prefix
  cat > "$MOCK_BIN/brew" <<SCRIPT
#!/bin/bash
if [ "\$1" = "--prefix" ]; then
  echo "$TEST_HOME/brew-prefix"
fi
SCRIPT
  chmod +x "$MOCK_BIN/brew"

  # Mock terminal-notifier
  cat > "$MOCK_BIN/terminal-notifier" <<SCRIPT
#!/bin/bash
echo "terminal-notifier stub"
SCRIPT
  chmod +x "$MOCK_BIN/terminal-notifier"

  # Mock readlink -f
  cat > "$MOCK_BIN/readlink" <<SCRIPT
#!/bin/bash
echo "$APP_DIR/Contents/MacOS/terminal-notifier"
SCRIPT
  chmod +x "$MOCK_BIN/readlink"

  # Mock realpath
  cat > "$MOCK_BIN/realpath" <<SCRIPT
#!/bin/bash
echo "$APP_DIR/Contents/MacOS/terminal-notifier"
SCRIPT
  chmod +x "$MOCK_BIN/realpath"

  # Mock sips
  cat > "$MOCK_BIN/sips" <<'SCRIPT'
#!/bin/bash
out=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    --out) out="${args[$((i+1))]}" ;;
  esac
done
if [ -n "$out" ]; then
  printf 'PNG-RESIZED' > "$out"
fi
SCRIPT
  chmod +x "$MOCK_BIN/sips"

  # Mock iconutil
  cat > "$MOCK_BIN/iconutil" <<'SCRIPT'
#!/bin/bash
out=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o) out="${args[$((i+1))]}" ;;
  esac
done
if [ -n "$out" ]; then
  echo "FAKE-ICNS" > "$out"
fi
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/iconutil"

  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_HOME" "$MOCK_BIN"
}

# ============================================================
# Syntax
# ============================================================

@test "setup-icon script has valid bash syntax" {
  run bash -n "$SETUP_ICON_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Icon discovery
# ============================================================

@test "finds peon icon in opencode config dir" {
  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 0 ]
}

@test "finds peon icon via brew prefix" {
  rm -f "$TEST_HOME/.config/opencode/peon-ping/peon-icon.png"
  mkdir -p "$TEST_HOME/brew-prefix/lib/peon-ping/docs"
  printf '\x89PNG\r\n' > "$TEST_HOME/brew-prefix/lib/peon-ping/docs/peon-icon.png"

  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 0 ]
}

@test "fails when peon icon is not found anywhere" {
  rm -f "$TEST_HOME/.config/opencode/peon-ping/peon-icon.png"

  # Copy script to isolated dir so dirname fallback doesn't find repo icon
  ISOLATED_DIR="$(mktemp -d)"
  cp "$SETUP_ICON_SH" "$ISOLATED_DIR/setup-icon.sh"

  run bash "$ISOLATED_DIR/setup-icon.sh"
  [ "$status" -eq 1 ]
  rm -rf "$ISOLATED_DIR"
}

# ============================================================
# Dependency checks
# ============================================================

@test "fails when terminal-notifier is not found" {
  rm -f "$MOCK_BIN/terminal-notifier"
  export PATH="$MOCK_BIN:/bin:/usr/bin"

  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 1 ]
}

# ============================================================
# Icon replacement and backup
# ============================================================

@test "replaces Terminal.icns and creates backup" {
  bash "$SETUP_ICON_SH"
  icns_content=$(cat "$APP_DIR/Contents/Resources/Terminal.icns")
  [[ "$icns_content" == "FAKE-ICNS" ]]
  [ -f "$APP_DIR/Contents/Resources/Terminal.icns.backup" ]
  backup_content=$(cat "$APP_DIR/Contents/Resources/Terminal.icns.backup")
  [[ "$backup_content" == "original-icns" ]]
}

@test "does not overwrite existing backup" {
  echo "old-backup" > "$APP_DIR/Contents/Resources/Terminal.icns.backup"
  bash "$SETUP_ICON_SH"
  backup_content=$(cat "$APP_DIR/Contents/Resources/Terminal.icns.backup")
  [[ "$backup_content" == "old-backup" ]]
}

# ============================================================
# Failure modes
# ============================================================

@test "exits with error when iconutil fails" {
  cat > "$MOCK_BIN/iconutil" <<'SCRIPT'
#!/bin/bash
exit 1
SCRIPT
  chmod +x "$MOCK_BIN/iconutil"

  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 1 ]
}

@test "fails gracefully when app bundle cannot be found" {
  cat > "$MOCK_BIN/readlink" <<'SCRIPT'
#!/bin/bash
echo "/nonexistent/path/terminal-notifier"
SCRIPT
  chmod +x "$MOCK_BIN/readlink"

  cat > "$MOCK_BIN/realpath" <<'SCRIPT'
#!/bin/bash
echo "/nonexistent/path/terminal-notifier"
SCRIPT
  chmod +x "$MOCK_BIN/realpath"

  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 1 ]
}

# ============================================================
# Idempotency
# ============================================================

@test "running twice succeeds (idempotent)" {
  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 0 ]
  run bash "$SETUP_ICON_SH"
  [ "$status" -eq 0 ]
}
