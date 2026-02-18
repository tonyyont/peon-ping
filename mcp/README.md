# peon-ping MCP Server

MCP server for [peon-ping](https://peonping.com) — gives AI agents access to 75+ game sound packs via the [Model Context Protocol](https://modelcontextprotocol.io).

## What it does

One tool: `play_sound`. The agent calls it with a sound key like `"duke_nukem/Groovy"` and it plays through your speakers.

Sound catalog exposed as MCP Resources — the client reads the catalog once, the model knows what's available, no repeated tool calls to browse.

## Setup

```bash
# Install peon-ping if you haven't
curl -fsSL https://peonping.com/install | bash

# Install MCP dependencies
cd mcp && npm install
```

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "peon-ping": {
      "command": "node",
      "args": ["/path/to/peon-ping/mcp/peon-mcp.js"]
    }
  }
}
```

### Cursor

Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "peon-ping": {
      "command": "node",
      "args": ["/path/to/peon-ping/mcp/peon-mcp.js"]
    }
  }
}
```

### Any MCP client

```json
{
  "command": "node",
  "args": ["/path/to/peon-ping/mcp/peon-mcp.js"],
  "env": { "PEON_VOLUME": "0.5" }
}
```

## Architecture

| MCP Feature | What it does |
|-------------|-------------|
| **Tool: `play_sound`** | Play one or more sounds. `{ sound: "pack/Name" }` or `{ sounds: ["a/B", "c/D"] }` |
| **Resource: `peon-ping://catalog`** | Full catalog — all packs and sounds. Client reads once, model has context. |
| **Resource: `peon-ping://pack/{name}`** | Sounds in a specific pack by category. |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PEON_PACKS_DIR` | `~/.openpeon/packs` | Sound packs directory |
| `PEON_VOLUME` | `0.5` | Playback volume (0-1) |

## Platform support

- **macOS** — `afplay`
- **Linux** — `pw-play`, `paplay`, `ffplay`, `mpv`, `play`, or `aplay` (first available)
- **WSL2** — PowerShell `SoundPlayer`
