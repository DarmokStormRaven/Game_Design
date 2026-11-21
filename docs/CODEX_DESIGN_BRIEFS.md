# Codex design briefs — Hearthfire cozy build (visual pieces)

_2026-11-21. These are art-generation briefs for Ryan to run in Codex (better at visuals than
Fable). Each produces a texture for a staged Hearthfire feature. Fable writes the Lua that
uses them; Codex makes the art. Hand Codex one brief at a time._

## Shared rules (every brief must obey — from hearthfire-ui/CLAUDE.md)

- **Format:** 32-bit TGA, power-of-two sizes (e.g. 128, 256, 512). Ship a couple of sizes if
  the art is shown much smaller than its pixels (no mipmaps, plain smoothing in this client).
- **House palette (Tavern):** lantern gold `#FFD770`, cream text `#F5E8C8`, muted label
  `#B8A988`, dark wood bg `#17120E`/`#211A14`, iron line `#7D6A58`. Warm, candlelit, low
  contrast. Hearthfire orange accent `#FF6A00` only for the wordmark, used sparingly.
- **Feel (Ryan's design rules):** plain wood, amber glass, soft glows. Calm. **No bursts,
  pulses, neon, or light shows.** One thing at a time. Must read at a glance (ADHD/dyslexia
  audience, possibly from couch distance).
- **Licensing:** any art Codex generates for Hearthfire is first-party (commissioned by Ryan /
  Tavern Under the Stairs). Each new texture needs a line in `HearthfireUI/CREDITS.txt`
  naming it, the tool, and the date. No third-party kit art, no fonts baked into images.
- **Match existing art:** the look should sit beside `Textures/Tavern/frame.tga`,
  `sign.tga`, and `journal_book.tga` (the wooden UI kit). Study those first.

## Brief 1 — Welcome-back card background (Stage 3)

**What it's for:** a soft parchment panel that appears once on login, showing where you are
and what you were doing. The calm "re-entry" moment for ADHD players.

**Deliver:** `Textures/welcome_card.tga`, 512×512 (the card is ~420×300 on screen; power-of-two
with transparent margin). Optionally a 256 variant.

**Design:** aged parchment pinned to a thin wood or iron frame, like a tavern notice board
note. Warm cream-to-tan paper (`#F5E8C8` → `#E8D5A8`), soft drop shadow, gently rounded or
torn corners. A faint hearth-glow warmth from the bottom edge (very subtle, no rays). Leave
the center flat and low-contrast so gold/cream TEXT drawn by the Lua reads on top. No text in
the image. No icons in the image. Transparent outside the card shape.

**Avoid:** bright white, hard rectangles, drop-shadow slabs, AI gradient wash, any glow that
pulses or spikes.

## Brief 2 — Signpost row icon (Stage 2)

**What it's for:** a small icon marking each "this now lives in the stock menu" row in /hfui.
A tiny wooden signpost / finger-post, the universal "it moved over there" symbol.

**Deliver:** `Textures/Tavern/icon_signpost.tga`, 64×64 (matches the other `icon_*` in that
folder — study `icon_comfort.tga`, `icon_banner.tga` for weight and palette).

**Design:** a little wooden directional signpost (one arrow board on a post), warm wood with a
thin iron edge, gold rim-light. Same painted style and weight as the existing Tavern icons.
Transparent background.

## Brief 3 — Hearth vignette gradient (Stage 4)

**What it's for:** a soft amber-dark screen-edge dimming that lowers peripheral stimulation
(our cozy answer to Sensory Vignette). Drawn at the lowest UI strata, behind everything.

**Deliver:** `Textures/vignette.tga`, 512×512, a single radial/edge gradient. (The Lua tiles or
stretches it full-screen; a square master is fine.)

**Design:** fully transparent in the center, darkening smoothly toward the edges/corners to a
warm near-black with a faint amber tint (`#14110F` with a whisper of `#2A1C0F`). The falloff
must be very gradual and smooth — no visible banding, no ring, no hard vignette circle. Think
"candlelit room," not "spotlight." The player sets intensity in Lua, so make the master
moderate (it will be scaled down, rarely up).

**Avoid:** heavy black, a crisp circular edge, any color other than warm dark, banding.

## Handoff note for Ryan

Run each brief in Codex, drop the TGA into `World of Warcraft\_forever_\Interface\AddOns\
HearthfireUI\Textures\` (restart the game — new textures need a full restart), and tell Fable
the filename landed so the matching Lua branch can be finished and the CREDITS line added.
Each art piece is independent; they can be done in any order or skipped (each feature has a
code fallback: the card can use a plain `frame.tga`, the vignette a solid color, the signpost
an existing icon).
