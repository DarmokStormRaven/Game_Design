# Handoff: cloud session → local session (Hearthfire UI)

_Written 2026-11-21 by the cloud session. Read this, then do the "Install now" steps.
Repo: `DarmokStormRaven/hearthfire-ui` (private). Follow its CLAUDE.md for everything._

## Standing instruction from Ryan

**Always install the most recent build into his WoW AddOns folder after any change, without
being asked.** The cloud session could not reach his PC (Remote Control folders report
"not available to cloud sessions"), so this falls to you, the local session.

## What was built (all pushed to GitHub, nothing merged to `main`)

| Branch | Head | What it is |
|---|---|---|
| `claude/cozy-plus-map` | `f13c752` | **THE ONE TO INSTALL.** Andrew's latest map (`andrew/map-overhaul` @ `dfb1238`) with all the cozy work layered on top. All 10 test suites pass, including Andrew's map harness. |
| `claude/lite-cuts` | `2490c0d` | Standalone cuts. **Do not merge alone**: it deletes the minimap button, which Andrew's map opens from (shift-click). Superseded by `cozy-plus-map`. |
| `claude/welcome-back` | `0f284d9` | Standalone welcome-back card (also inside `cozy-plus-map`). |
| `claude/hearth-vignette` | `5c60396` | Standalone vignette (also inside `cozy-plus-map`). |
| `claude/blizzard-signposts` | `3f3cc97` | Standalone signposts, stacked on lite-cuts (also inside `cozy-plus-map`, minus the minimap row). |

`main` is still `ba84448` (1.13.1). Installing `main` would REMOVE Andrew's map and Ryan's
DotLine work from his game, so don't install it.

### What `cozy-plus-map` contains
- **Andrew's map is untouched:** Map.lua, MapPoints.lua, Data/, Minimap.lua, Bindings.xml,
  map textures and tools/map/ are identical to his branch. The map is Andrew's domain and
  you must not edit it.
- **Lite cut, minus the minimap button:** the proc alert is removed (WoW's own button glow
  covers it). The dead Bars/Frames/Theme files and the Trim fallback shell are deleted.
  HearthfireTrim textures went from 7.9 MB to 0.6 MB. Healer frames and totems are now
  opt-in (off by default).
- **New:** `WelcomeBack.lua` (`/hfui welcome`), `Vignette.lua` (`/hfui vignette`, off by
  default), and `Signposts.lua` (`/hfui moved`, a "Where it moved" button in /hfui).
- **The minimap button stays,** because Andrew's map opens from it.

## Install now (safe procedure)

Ryan's local clone of the repo has **uncommitted 1.14.0 work (DotLine etc.) on `main`**. Do
not switch branches in that working copy, because it would put that work at risk. Use a
separate worktree:

```
git fetch origin claude/cozy-plus-map
git worktree add ..\hearthfire-cozy-plus-map origin/claude/cozy-plus-map
```

1. **Back up** the installed `AddOns\HearthfireUI` to a dated folder, excluding `Saved`:
   `robocopy <AddOns>\HearthfireUI <backup>\HearthfireUI-<date> /E /XD Saved`
2. **Copy the build in without touching `Saved\`.** `Saved\` is a link to Ryan's real
   settings, so never delete the installed folder wholesale:
   `robocopy ..\hearthfire-cozy-plus-map\HearthfireUI <AddOns>\HearthfireUI /E /XD Saved`
   - Do not use `/MIR` or `/PURGE`. Old files that were removed (Bars.lua, Theme.lua, old
     textures) stay on disk, but they're harmless because the TOC doesn't load them.
3. **Tell Ryan to fully restart WoW** (`/reload` is not enough, because there are new files
   and textures), then check that HearthfireUI is enabled under AddOns at character select.
4. Heads-up for Ryan: this build does not contain his uncommitted DotLine work, so
   installing it replaces DotLine in the game. The backup from step 1 has it, and so does
   his working copy. If he wants DotLine in the test build too, commit it to a branch first
   and merge it in.

Rollback: copy the backup back with the same robocopy (`/XD Saved`), then restart WoW.

## Open items Ryan raised (from his live game, which was still the OLD version)
1. **Lantern looks broken:** the iron hanger and the lantern body don't meet; there's a gap
   between the hook and the lantern's top ring. In `Chat/Lantern.lua` the hanger is placed
   at `TOPLEFT` offset `(-26*SCALE, 24*SCALE)` against a 64-unit canvas. Fix the alignment
   while looking at it in game. The art itself is a good job for Codex.
2. **Chat doesn't show which channel a line comes from:** add a clear per-line channel tag
   or colour on the wooden board (`Chat/Strip.lua`, `Chat/Frame.lua`).
3. **Chat frame is cramped ("LeBron in a Miata"):** loosen the line spacing and padding.
4. **Stage 6, still queued: absorb NiceDamage** (MIT). The plan is in
   `Game_Design/docs/NICE_DAMAGE_ABSORPTION.md`. Finding for this client: the
   `WorldTextScale` CVar does not exist, so build a font picker on the existing
   `DAMAGE_TEXT_FONT` mechanism. That needs LibSharedMedia added, which is a new library and
   needs a CREDITS line.

None of 1–3 are regressions from the merge; the Chat module was not touched.

## Where everything is
- Code: `hearthfire-ui`, branch `claude/cozy-plus-map`
- Plans and research (this repo, `Game_Design`, branch `claude/gifted-brahmagupta-mps71u`, `docs/`):
  `COZY_BUILD_PLAN.md`, `COZY_WOW_USER_RESEARCH.md`, `CODEX_DESIGN_BRIEFS.md`,
  `NICE_DAMAGE_ABSORPTION.md`, and this file.
- A ready-made test zip of `cozy-plus-map` was also built (`HearthfireUI-1.13.1.zip`) and
  sent to Ryan in the Claude app. It contains the same files as the branch.
