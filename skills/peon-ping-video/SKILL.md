---
name: peon-ping-video
description: Generate the next promotional video for peon-ping sound packs. Creates a Remotion composition, renders to MP4, and copies to Desktop. Tracks promoted packs to never create duplicates. Use when user says "create the next video", "make a pack video", or "peon-ping-video".
user_invocable: true
---

# Generate Next Pack Video

Create the next promotional video for a peon-ping sound pack that hasn't been promoted yet.

## Priority Order (English packs first, then non-English)

Prioritize English-language packs with distinctive characters. Skip non-English locale variants (e.g. `peon_fr`, `peasant_cz`) until all English packs are done.

**Suggested English priority:**
`hd2_helldiver` > `peon` > `tf2_engineer` > `molag_bal` > `rick` > `murloc` > `ocarina_of_time` > `aoe2` > `aom_greek` > `sc_firebat` > `sc_medic` > `sc_scv` > `sc_tank` > `sc_terran` > `sc_vessel` > `ra_soviet` > `wc2_peasant` > `peasant`

Then non-English packs in any order.

## Steps

1. **Read `video/promoted-packs.json`** to see what's already done. Never create a video for a pack that's already listed.

2. **Pick the next pack** from the priority list above (first one not in promoted-packs.json).

3. **Read the pack manifest** at `~/Documents/github-repos/og-packs/<pack_name>/openpeon.json` to see available sounds and categories.

4. **Pick 6 sounds** — one for each demo event:
   - session started (from `session.start`)
   - reading files (from `task.acknowledge`)
   - permission needed (from `input.required`)
   - analyzing code (from `task.acknowledge`)
   - task complete (from `task.complete`)
   - error (from `task.error`)

   If a category is missing, reuse sounds from other categories. Pick the most distinctive/entertaining lines.

5. **Check durations** with `ffprobe` for each sound file. Calculate frame count: `ceil(duration_seconds * 30)`.

6. **Copy sounds** to `video/public/sounds/`.

7. **Pick a theme color** that matches the franchise aesthetic. Every video should have a unique accent color.

8. **Create `video/src/<PackName>Preview.tsx`** following the established template pattern:
   - Title card: gradient bars in accent color, GitHub link + peon-portrait.gif at top, pack name centered, subtitle (franchise), 𝕏 @PeonPing bottom-left, peon-render.png bottom-right
   - Terminal: accent-colored border glow, peon-portrait.gif in title bar, WC3_GOLD for sound lines, persistent 𝕏 @PeonPing badge bottom-left
   - Outro: peon-portrait.gif + "peon-ping" lockup, "Stop babysitting your terminal", GitHub link in gold box, "60+ sound packs available", 𝕏 @PeonPing, peon-render.png bottom-right
   - Per-clip duration map (Record<string, number>) using the ffprobe frame counts
   - Use an existing video file (e.g. `AxePreview.tsx` or `KirovPreview.tsx`) as the template — copy and modify

9. **Register in `video/src/Root.tsx`** — add import and Composition (1080x1080, 30fps, 840 frames).

10. **Render**: `cd video && npx remotion render <CompositionId> out/<pack-name>-preview.mp4`

11. **Copy to Desktop**: `cp video/out/<pack-name>-preview.mp4 ~/Desktop/`

12. **Update `video/promoted-packs.json`** — add entry with pack name, today's date, platform "x", and video path.

## Color palette used so far

- Soviet Engineer: already existed before standardization
- Kerrigan: Zerg purple `#7c3aed`
- Sopranos: warm amber `#c4813a`
- GLaDOS: Portal blue `#6eb5ff` / orange `#ff9d2e`
- Sheogorath: daedric purple `#9b59b6` / madness gold `#e8b923`
- Axe: blood red `#c0392b`
- Battlecruiser: Terran blue `#3b82f6`
- Duke Nukem: sunglasses gold `#e6a817`
- Kirov: Soviet red `#cc2936`

Pick something visually distinct from these.

## Key files

- Promoted packs tracker: `video/promoted-packs.json`
- Sound assets: `video/public/sounds/`
- Branding assets: `video/public/peon-portrait.gif`, `video/public/peon-render.png`
- Compositions registry: `video/src/Root.tsx`
- Template to copy from: `video/src/KirovPreview.tsx` (most recent, clean)
- og-packs source: `~/Documents/github-repos/og-packs/`
