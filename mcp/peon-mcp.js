#!/usr/bin/env node
// peon-mcp.js — MCP server for peon-ping sound effects
// One tool (play_sound) + Resources for catalog discovery

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { readFileSync, readdirSync, existsSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";
import { spawn, execSync } from "child_process";
import { platform as osPlatform } from "os";

const __dirname = dirname(fileURLToPath(import.meta.url));
let version = "2.1.0";
try { version = readFileSync(join(__dirname, "..", "VERSION"), "utf-8").trim(); } catch {}

// ── Packs directory ────────────────────────────────────────────────────────

function findPacksDir() {
  const envDir = process.env.PEON_PACKS_DIR;
  if (envDir && existsSync(envDir)) return envDir;
  const home = process.env.HOME || process.env.USERPROFILE || "";
  for (const dir of [
    join(home, ".openpeon", "packs"),
    join(home, ".claude", "hooks", "peon-ping", "packs"),
  ]) {
    if (existsSync(dir)) return dir;
  }
  return null;
}

// ── Catalog ────────────────────────────────────────────────────────────────

let catalogCache = null;

function loadCatalog() {
  if (catalogCache) return catalogCache;
  const packsDir = findPacksDir();
  if (!packsDir) { catalogCache = { packsDir: null, packs: new Map() }; return catalogCache; }
  const packs = new Map();
  try {
    for (const entry of readdirSync(packsDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const mp = join(packsDir, entry.name, "openpeon.json");
      if (!existsSync(mp)) continue;
      try { packs.set(entry.name, JSON.parse(readFileSync(mp, "utf-8"))); } catch {}
    }
  } catch {}
  catalogCache = { packsDir, packs };
  return catalogCache;
}

function resolveSound(packName, soundName) {
  const { packsDir, packs } = loadCatalog();
  if (!packsDir) return { error: "No packs directory found" };
  const manifest = packs.get(packName);
  if (!manifest) return { error: `Pack "${packName}" not found` };
  for (const cat of Object.values(manifest.categories || {})) {
    for (const s of cat.sounds || []) {
      if (s.file.split("/").pop().replace(/\.\w+$/, "") === soundName) {
        return { file: join(packsDir, packName, s.file), label: s.label || soundName };
      }
    }
  }
  return { error: `Sound "${soundName}" not found in pack "${packName}"` };
}

// ── Playback ───────────────────────────────────────────────────────────────

function detectPlatform() {
  const p = osPlatform();
  if (p === "darwin") return "mac";
  if (p === "win32") return "windows";
  if (p === "linux") {
    try { if (/microsoft/i.test(readFileSync("/proc/version", "utf-8"))) return "wsl"; } catch {}
    return "linux";
  }
  return "unknown";
}

function detectLinuxPlayer() {
  for (const p of ["pw-play", "paplay", "ffplay", "mpv", "play", "aplay"]) {
    try { execSync(`command -v ${p}`, { stdio: "ignore" }); return p; } catch {}
  }
  return null;
}

function playFile(filePath, volume) {
  const plat = detectPlatform();
  let cmd, args;
  switch (plat) {
    case "mac":
      cmd = "afplay"; args = ["-v", String(volume), filePath]; break;
    case "linux": {
      const player = detectLinuxPlayer();
      if (!player) return;
      cmd = player;
      const v = volume;
      if (player === "pw-play" || player === "paplay") args = ["--volume", String(Math.round(v * 65536)), filePath];
      else if (player === "ffplay") args = ["-nodisp", "-autoexit", "-volume", String(Math.round(v * 100)), filePath];
      else if (player === "mpv") args = ["--no-video", `--volume=${Math.round(v * 100)}`, filePath];
      else if (player === "play") args = ["-v", String(v), filePath];
      else args = [filePath];
      break;
    }
    case "wsl":
      cmd = "powershell.exe";
      args = ["-NoProfile", "-Command", `$p=New-Object Media.SoundPlayer '${filePath.replace(/\//g, "\\")}';$p.PlaySync()`];
      break;
    default: return;
  }
  const child = spawn(cmd, args, { stdio: "ignore", detached: true });
  child.unref();
}

// ── MCP Server ─────────────────────────────────────────────────────────────

const server = new McpServer({ name: "peon-ping", version });
const volume = parseFloat(process.env.PEON_VOLUME || "0.5") || 0.5;

// ── Resource: catalog (all packs + sounds) ─────────────────────────────────

server.resource(
  "catalog",
  "peon-ping://catalog",
  { description: "Complete sound pack catalog — all packs and their sounds organized by category", mimeType: "text/plain" },
  () => {
    const { packs } = loadCatalog();
    if (packs.size === 0) return { contents: [{ uri: "peon-ping://catalog", text: "No packs installed." }] };

    const lines = [`${packs.size} sound packs available. Use play_sound with "pack/SoundName".\n`];
    for (const [name, manifest] of [...packs.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
      const display = manifest.display_name || name;
      const sounds = [];
      for (const [cat, data] of Object.entries(manifest.categories || {})) {
        for (const s of data.sounds || []) {
          const fname = s.file.split("/").pop().replace(/\.\w+$/, "");
          sounds.push(`${name}/${fname} ("${s.label || fname}")`);
        }
      }
      lines.push(`**${name}** (${display}) — ${sounds.length} sounds: ${sounds.join(", ")}`);
    }
    return { contents: [{ uri: "peon-ping://catalog", text: lines.join("\n") }] };
  }
);

// ── Resource template: individual pack ─────────────────────────────────────

server.resource(
  "pack",
  "peon-ping://pack/{name}",
  { description: "Sounds in a specific pack, organized by category", mimeType: "text/plain" },
  (uri, { name }) => {
    const { packs } = loadCatalog();
    const manifest = packs.get(name);
    if (!manifest) return { contents: [{ uri: uri.href, text: `Pack "${name}" not found.` }] };

    const lines = [`${manifest.display_name || name}:\n`];
    for (const [cat, data] of Object.entries(manifest.categories || {})) {
      lines.push(`${cat}:`);
      for (const s of data.sounds || []) {
        const fname = s.file.split("/").pop().replace(/\.\w+$/, "");
        lines.push(`  ${name}/${fname} — "${s.label || fname}"`);
      }
    }
    return { contents: [{ uri: uri.href, text: lines.join("\n") }] };
  }
);

// ── Tool: play_sound ───────────────────────────────────────────────────────

server.tool(
  "play_sound",
  'Play a game sound effect through the speaker. Use sound keys like "pack/sound" (e.g., "duke_nukem/Groovy", "peon/PeonReady1"). Use sparingly to express mood.',
  {
    sound: z.string().optional().describe('Sound key in format "pack/sound"'),
    sounds: z.array(z.string()).optional().describe("Multiple sound keys to play sequentially"),
  },
  { title: "Play Sound Effect", readOnlyHint: false, destructiveHint: false, openWorldHint: false },
  async ({ sound, sounds: soundsArr }) => {
    const keys = soundsArr || (sound ? [sound] : []);
    if (keys.length === 0) return { content: [{ type: "text", text: "No sound specified" }] };
    if (keys.length > 5) return { content: [{ type: "text", text: "Max 5 sounds per call" }] };

    const results = [];
    for (let i = 0; i < keys.length; i++) {
      const [pack, name] = keys[i].split("/", 2);
      if (!pack || !name) { results.push(`❌ Invalid: "${keys[i]}"`); continue; }
      const r = resolveSound(pack, name);
      if (r.error) { results.push(`❌ ${r.error}`); continue; }
      if (!existsSync(r.file)) { results.push(`❌ File missing: ${keys[i]}`); continue; }
      playFile(r.file, volume);
      results.push(`🔊 ${keys[i]} ("${r.label}")`);
      if (i < keys.length - 1) await new Promise((res) => setTimeout(res, 300));
    }
    return { content: [{ type: "text", text: results.join("\n") }] };
  }
);

// ── Start ──────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
