# Hearthfire: absorbing NiceDamage (damage numbers decision record)

_2026-11-21. Owner decisions from Ryan: **damage numbers stay in Hearthfire** (the overlap
audit's "/hfui size" cut is reversed), the old addon **NiceDamage gets absorbed** into
Hearthfire, and **the map is Andrew's domain** — map-related audit items route to Andrew._

## What NiceDamage is (verified from source, not guides)

- Current form: **NiceDamage (Reloaded)** v3.1.6, author Azaiko (Rodi Scheele), updated
  2026-11-11. Source: github.com/RodiScheele/nicedamage (cloned and read today).
- **License: MIT** (code). Absorption is legal; the only obligation is keeping the
  copyright notice: _"Portions derived from NiceDamage (Reloaded), © 2026 Rodi Scheele, MIT."_
- **It already supports WoW: Forever** — its TOC interface list includes `16001`.
  The old "font addons don't work on Classic clients" worry is dead.
- Size: ~370 lines of Lua + 16 fonts. The mechanism (NiceDamage.lua:77–130) is two parts:
  1. **World numbers** (floating off mobs): set the global `DAMAGE_TEXT_FONT` to a font
     path, then the CVars `WorldTextScale`, `WorldTextGravity`, `WorldTextRampDuration`
     (each also with a `_v2` suffix for newer clients). Size, float direction and
     animation speed are all CVar-driven — Blizzard renders everything.
  2. **UI scrolling combat text** (on the player frame, optional): re-font the
     `CombatTextFont`, `DamageNumberFont`, `WorldFont` font objects with outline/shadow flags.
- Fonts are registered with **LibSharedMedia**, so they appear in every addon's dropdowns.
  It ships **Bangers** — the exact comic font from the Wallop mockups.
- Libraries: not in the repo; its packager pulls Ace3 + LibSharedMedia at release time.

## The one legal trap: fonts are licensed separately from code

MIT covers the Lua. Each bundled font has its own license. Safe to reuse: **Bangers**
(SIL OFL), **Roboto Bold** (open). NOT safe to copy blindly: **Gotham Narrow Ultra** is a
commercial Hoefler&Co font, and the Pepsi fonts are fan-made trademark-adjacent work.
Rule: absorb the code pattern freely; ship only fonts with licenses we've read
(Bangers, Roboto, and Hearthfire's own OFL reading fonts like Lexend).

## Market note

A Forever-specific competitor exists: **KyruxDamage Forever** (light combat-text
customizer, minimap button, `/kdf`). Its own listing warns that two addons touching
`DAMAGE_TEXT_FONT`/WorldText CVars fight each other — last one loaded wins. Hearthfire
absorbs rather than competes, and inherits that conflict risk (below).

## Absorption plan (Hearthfire `Damage.lua` module)

1. **Take the mechanism, not the scaffolding.** Hearthfire has its own settings window;
   NiceDamage's Ace3 config, minimap icon and DataBroker object stay behind. The core to
   port is ~40 lines.
2. **Settings in /hfui:** font picker (LSM list), size, gravity (float direction),
   ramp duration (animation), and an optional "also restyle UI scrolling text" toggle.
   This reverses the audit's "/hfui size" cut: stock has one size setting; Hearthfire's
   module is a superset (font + size + motion), which is differentiation, not duplication.
3. **Do it better than NiceDamage — snapshot and restore.** NiceDamage sets CVars and
   never restores them. Hearthfire follows the Cozy rule (`docs/ENGINE_PLAN.md`): save
   every CVar before changing it; disable/reset puts everything back.
4. **LSM once, two wins:** one LibSharedMedia integration registers both the damage fonts
   and the dyslexia-friendly reading fonts — the ecosystem move from the Nov 1 gap
   analysis. Needs LibStub + CallbackHandler + LibSharedMedia embedded (3 small libs) if
   Hearthfire doesn't already carry them.
5. **Conflict detection:** on load, if NiceDamage, KyruxDamage or another combat-text
   addon is present, say so once and let the player pick who owns the numbers — the same
   pattern as the audit's UI-overhaul detection. Re-apply on `PLAYER_ENTERING_WORLD` so
   Hearthfire wins load-order races when enabled.
6. **Credits:** add the MIT notice for NiceDamage to Hearthfire's license/credits file.
7. **In-game check on Forever:** NiceDamage's TOC says 16001 works; still verify once on
   the live client that `DAMAGE_TEXT_FONT` and the `WorldText*` CVars behave (the audit's
   evidence standard: [SOURCE]/in-game beats [GUIDES]).

## Status of the audit's related items after this decision

- Cut "/hfui size" → **reversed**; replaced by the absorbed damage module (superset).
- Cut proc alert, minimap button → unchanged (still sound).
- Cooldown-pulse cut → still needs its one in-game look (weakest-evidenced cut).
- Map overlaps (replaceWorldMap, Questie/Leatrix Maps) → **Andrew's domain.**
