#!/bin/bash
# Download and extract sounds for a character pack
# Usage: download-sounds.sh <install_dir> <pack_name>
set -euo pipefail

INSTALL_DIR="${1:?Usage: download-sounds.sh <install_dir> <pack_name>}"
PACK_NAME="${2:-peon}"

MANIFEST="$INSTALL_DIR/packs/$PACK_NAME/manifest.json"
if [ ! -f "$MANIFEST" ]; then
  echo "Error: manifest not found at $MANIFEST"
  exit 1
fi

# Parse manifest for source URL and subfolder
eval "$(/usr/bin/python3 -c "
import json, sys, shlex
m = json.load(open(sys.argv[1]))
print('SOURCE_URL=' + shlex.quote(m['source_url']))
print('SUBFOLDER=' + shlex.quote(m['source_subfolder']))
" "$MANIFEST")"

SOUNDS_DIR="$INSTALL_DIR/packs/$PACK_NAME/sounds"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading $PACK_NAME sounds..."
if ! curl -L -o "$TMPDIR/sounds.zip" "$SOURCE_URL" 2>/dev/null; then
  echo ""
  echo "Automatic download failed. Please download manually:"
  echo "  1. Go to: $SOURCE_URL"
  echo "  2. Save the ZIP file"
  echo "  3. Extract the '$SUBFOLDER' folder to: $SOUNDS_DIR/"
  echo ""
  exit 1
fi

echo "Extracting $PACK_NAME sounds..."
mkdir -p "$SOUNDS_DIR"

# Extract only the pack's subfolder
unzip -o -j "$TMPDIR/sounds.zip" "$SUBFOLDER/*" -d "$SOUNDS_DIR" > /dev/null 2>&1

# Verify we got files (support wav, mp3, ogg)
COUNT=$({ ls "$SOUNDS_DIR"/*.wav "$SOUNDS_DIR"/*.mp3 "$SOUNDS_DIR"/*.ogg 2>/dev/null || true; } | wc -l | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
  echo "Error: No sound files found after extraction"
  exit 1
fi

echo "Extracted $COUNT sound files to $SOUNDS_DIR/"
