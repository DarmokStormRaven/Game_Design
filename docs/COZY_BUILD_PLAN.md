# Hearthfire build plan — cozy focus (staged)

_2026-11-21. Ryan's orders: build from the cozy research, lean into the AuDHD patterns,
cut the duplicates, add the vignette, and signpost players from the /hfui menu to the
Blizzard settings that replace what we cut. Stages run one at a time; each is its own
branch and pull request into `main`, which only Ryan merges (per hearthfire-ui CLAUDE.md).
Damage numbers are NOT cut — Ryan reversed that; they grow via the NiceDamage absorption._

## Ground rules (from hearthfire-ui CLAUDE.md)

- One idea per branch, named `claude/<topic>`; Ryan accepts or discards each whole.
- `Saved\` is never touched. TOC `## Version` is never bumped by me.
- Every stage ends with the full test suite green (`lupa` harnesses, 6 commands) plus new
  checks for what changed; PRs say plainly what was and wasn't tested in the live game.
- Anything that changes defaults, removes files, or touches the TOC gets flagged in the PR.
- Blizzard facts come from the `forever` branches of Gethe/wow-ui-source and
  Ketho/BlizzardInterfaceResources — checked, not remembered.
- Risk noted: Ryan's uncommitted 1.14.0 work (DotLine etc.) is not on `main`; stage
  branches stay surgical to keep his later merge easy.

## Stage 1 — `claude/lite-cuts` (the duplicate and dead-weight cuts)

Scope (audit's cut list, minus damage numbers):
1. Delete the dead trio `Bars.lua`, `Frames.lua`, `Theme.lua` (2,171 lines, not in the
   TOC; git history keeps them) + update the CLAUDE.md file table in the same PR.
2. Remove the forced-off shell in `Trim.lua` (~600 lines held off at HearthfireUI.lua:61),
   keeping what the live cast-bar rim actually uses.
3. Texture prune: find every texture path the loaded code references, delete unreferenced
   files in `Textures\HearthfireTrim` (7.9 MB today) — subagent audit, then cut.
4. Remove the proc alert (stock SpellActivationOverlay covers it) and the minimap button
   (`Minimap.lua`; the TOC already registers in the stock addon drawer).
5. Make `Healer.lua` and `Totems.lua` opt-in modules (default off, a tick in /hfui) —
   the audit's lite shape: nothing built is deleted, stock covers the default case.
   Journal stays default-on (it is "beside Blizzard's", not a duplicate, and Stage 3
   builds on it). Default changes flagged prominently for Ryan.
6. Verify `build_release.py` excludes dev files (audit's NOT CHECKED item).
Gate: all harnesses pass (healer harness updated for the module switch), loaded-line
count reported in the PR (target ≈8,000 per the audit).

## Stage 2 — `claude/blizzard-signposts` (Ryan's "link them to Blizzard" requirement)

For each thing we cut or made opt-in, the /hfui window gets a calm row saying where it
lives now, with a button that opens the exact Blizzard settings panel
(`Settings.OpenToCategory` and friends — exact category IDs researched from the forever
sources by a subagent, not remembered). Rows: proc glow → stock spell alerts; party
heal-clicking → stock raid frames + Click Casting UI; totem bar → stock multicast bar;
minimap button → addon drawer; damage-number size → points INTO our own (kept) setting.
Deliverable: `Signposts.lua` + Menu integration + harness checks.

## Stage 3 — `claude/welcome-back` (the AuDHD lean-in)

The research's top candidate, patterned on the AuDHD addon's "one next step at a time":
a soft parchment card on login — where you are, what you were doing when you logged out,
one gentle suggestion (tracked quest first), one button to dismiss, fades on its own,
own switch, never shows in combat. Feeds from Journal/saved state. No pulses, no shine
(house style: "one thing at a time").

## Stage 4 — `claude/hearth-vignette` (the "nice touch")

Hearthfire's own soft screen-edge dimming: amber-dark gradient frame at BACKGROUND
strata, intensity slider in /hfui, modes off / always / combat-only. If the Sensory
Vignette addon is loaded, Hearthfire's stays off and says so once (allies, not rivals).
Build our own ~100 lines; copy nothing from theirs.

## Stage 5 — Codex design briefs (visuals)

No Codex agent is reachable from this session, so the briefs are written here for Ryan
to run in Codex on his machine: welcome-back card parchment art, signpost row icon,
/hfui lite-mode menu layout polish. Each brief lists exact sizes (power-of-two, 32-bit
TGA per repo rules), the house palette, and the license/CREDITS requirement for any
asset that comes back.

## Stage 6 — `claude/nice-numbers` (queued last)

The NiceDamage absorption per `docs/NICE_DAMAGE_ABSORPTION.md` (MIT, Forever-ready):
`Damage.lua` with font picker, size/gravity/ramp, CVar snapshot-and-restore, LSM
registration, rival detection. Runs only after Stages 1–4 land clean.

## Rollback

Every stage is one branch and one PR: discard = close the PR, delete nothing on `main`.
Within the addon, every new piece has its own off switch (house rule).
