# Addon gap analysis: Cozy Couch Mode vs. the "must-have WoW Forever addons" lists

_Drafted 2026-11-01. Owner: Ryan. Status: **provisional** — the Instagram reel that prompted
this could not be opened from the cloud session (Instagram is outside the session's allowed
network domains). This analysis uses the consensus list that late-2026 "best WoW Forever
addons" roundups and reels share. When Ryan pastes the reel's actual lineup (or allows
instagram.com in the environment's network settings), re-check this doc against it._

## Foundation: how to read this doc

A WoW **addon** is a folder of Lua files the game loads at login. Each addon does one job.
The famous ones below are *keyboard-and-mouse* tools: they assume you can click precisely.

Cozy Couch Mode's job is different: it is the **controller-first, calm UI layer**. So for
each famous addon there are three possible verdicts:

- **Coexist** — the addon works fine next to Cozy; no gap to close. Recommending it is enough.
- **Cozy-fy** — the *idea* is right for our over-stimulated target player, but the famous
  addon's delivery (flashing bars, dense settings) is wrong. We build a calm, tiny version.
- **Skip** — it serves power users we are not building for. Naming it in the README as
  "compatible, not our lane" is the whole move.

There is also one **meta-gap** that cuts across every entry, described at the end.

## The addons, one by one

### 1. Questie (quest objectives on the map)
- **What it does:** draws "go here, kill/collect this" markers on the map and minimap.
- **Gap in our app:** Cozy's Questing vibe binds the quest log and map but gives no routing.
  We never planned to: the gap is that **Questie's map pins need a mouse click** to read.
- **Verdict:** Coexist. Its pins are mostly visual, so a pad player still benefits.
  Post-launch: teach the snap cursor to land on map pins (see meta-gap).

### 2. TomTom (waypoint arrow)
- **What it does:** a floating arrow pointing at a coordinate.
- **Gap in our app:** none — purely visual, zero interaction needed.
- **Verdict:** Coexist. Add to the "plays well with" list in SETUP.md.

### 3. Leatrix Plus (quality-of-life bundle: auto-sell junk, auto-repair, faster loot)
- **What it does:** dozens of small friction removers behind a settings panel.
- **Gap in our app:** the two highest-dopamine features — **auto-sell grey junk** and
  **auto-repair at vendors** — are exactly Cozy's "no fiddling" philosophy, and our vendor
  flow (ENGINE_PLAN: "quest accept/turn-in and vendor... not yet exercised") is still the
  weakest tested area.
- **Verdict:** Cozy-fy (post-launch v0.2). Two toggles, on by default, inside the gear icon.
  Tiny code, big calm.

### 4. Bagnon / Baganator (one-big-bag inventory)
- **What they do:** merge all bags into one searchable grid, replacing Blizzard's bag frames.
- **Gap in our app:** Y opens bags, and the snap cursor drives **Blizzard's** bag frames —
  but these addons **replace** those frames, so the cursor goes dead in them.
- **Verdict:** Coexist with a warning for now; the real fix is the meta-gap below. Interim
  recommendation in SETUP.md: WoW's own "Combined Bags" option gives 80% of the benefit
  and stays cursor-compatible.

### 5. Deadly Boss Mods / BigWigs (boss timers and warnings)
- **What they do:** loud bars, sounds and screen flashes before boss abilities.
- **Gap in our app:** we have **no alert system at all** — and DBM's delivery (red flashes,
  klaxons) is the opposite of our design rules ("no red, no toasts in combat").
- **Verdict:** Cozy-fy (post-launch, bigger ticket): **Calm Alerts** — a soft screen-edge
  glow plus one gentle sound for "move now" moments. This is Cozy's answer for dungeon
  nights, and a genuine differentiator no one else ships.

### 6. Omen / Forever Threat (threat meter)
- **What they do:** show how close you are to pulling the monster off the tank.
- **Gap in our app:** nothing warns a chill player before they pull aggro.
- **Verdict:** Cozy-fy, small version, after Calm Alerts: a quiet amber tint on the Hearth
  Bar when threat is high. No numbers, no list.

### 7. Recount / Details! (damage meters)
- **What they do:** DPS scoreboards.
- **Verdict:** Skip. Scoreboards are stimulation, not calm. Coexists fine for those who want it.

### 8. WeakAuras (custom buff/cooldown displays; limited on Forever)
- **What it does:** a programming toolkit for on-screen triggers.
- **Gap in our app:** none that matters — the Hearth Bar already shows cooldown, usable and
  range, which is the slice our player needs.
- **Verdict:** Skip (and note that roundups themselves warn it has combat limits on Forever).

### 9. Full UI overhauls (EllesmereUI, MelloUI, ElvUI-likes)
- **What they do:** replace the whole interface.
- **Gap in our app:** these are the one true **conflict**: they fight the Hearth Bar for the
  action bars and the screen. We already solved this pattern once for ConsolePort
  ("if loaded, say so once and stay menu-only").
- **Verdict:** Close the gap with **detection**: if a known overhaul is loaded, Cozy says so
  once and offers menu-only mode. One table of addon names plus the existing code path.

### 10. AtlasLoot / dungeon-prep and PvP tools (BattlegroundTargets, Spy)
- **What they do:** loot tables, enemy trackers.
- **Verdict:** Skip. Not the launch demographic ("hop on and chill").

## The meta-gap (the one that matters most)

Every addon above was built for a mouse. **Our snap cursor (Cursor.lua) only knows
Blizzard's own windows.** The player who watches that reel installs Questie and Bagnon,
then finds Cozy's cursor can't click either one. That — not any single missing feature —
is the real gap the reel exposes.

**Post-launch ticket:** a generic frame scanner so the cursor can walk *addon* frames
(start with one bag addon and Questie's map pins). This is the "snap-cursor, full remap UI"
class of work ENGINE_PLAN already deferred — it stays deferred, but now with a concrete
target list and a reason.

## How to proceed (in order)

1. **Before Nov 4 (launch): change nothing.** Feature freeze was Oct 28. Instead run one
   **compatibility smoke test**: a Gate-3-style acceptance run with Questie, TomTom,
   Leatrix Plus, Baganator and DBM all loaded, diary logging on. Fix only breakage.
2. **Ship a "Plays well with" section in SETUP.md** naming TomTom + Questie as recommended,
   Combined Bags instead of bag addons for now, and UI overhauls as not supported.
3. **v0.2 (first post-launch patch):** auto-sell junk + auto-repair toggles; UI-overhaul
   detection table.
4. **v0.3:** Calm Alerts (screen-edge glow), then the quiet threat tint.
5. **v0.4:** cursor support for addon frames (bags first, then map pins).
6. **Re-verify this doc** against the actual reel once its addon list is available.
