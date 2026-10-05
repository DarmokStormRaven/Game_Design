# Cozy Couch Mode: engine plan (v2, after adversarial review)

_Last updated: 2026-10-05. Owner: Ryan. This is the plan of record for building Cozy's own controller engine._

## The goal in one line
Log in → pick a cozy vibe → play. No setup, no wizard. Everything fiddly lives behind a gear icon.
For over-stimulated players who just want to hop on and chill. Our own add-on: no ConsolePort dependency, no copied code.

## Why not ConsolePort (measured, not opinion)
- About 80,600 lines of Lua across 9 modules, 262 settings + 45 exposed game settings + bar layout props + every button × layer binding.
- First run is a 4-step guide. On Ryan's PC it stopped after step 1 and left **128 empty controller slots: nothing was bound.**
- Much of its work is turning on things WoW now does natively (modifier buttons, interact, soft targeting, auto-loot).
  The heavy parts it rebuilds itself are action bars (about 13k lines), the menu cursor (about 4k), rings, raid tools and an on-screen keyboard.

## How the plan changed after three independent attacks (technical / chill-player / scope)
| Problem the attackers found | Change |
|---|---|
| A separate "combat mapping" only kicks in once you're already fighting, so you can't pull, and buttons change under your thumb (all three found this) | **Two sets per vibe: hold LT to flip.** Nothing is ever unreachable. No mid-combat rewiring needed. |
| Leftover ConsolePort settings on this PC (LB = Shift, LT = Ctrl, cursor clicks off) would break Cozy and invalidate tests | Cozy sets every setting it relies on explicitly, saves the old values, and `/cozy reset` restores them. Tests run on clean settings. |
| Dying, quest turn-ins, vendors and popups need the mouse; that was planned for week 3 | **Windows work from week 1.** First prove what the game does natively with the pad; fallback "window mode". Death screen first. |
| No way to reach the game menu or Cozy with the pad alone | **Start = Game Menu, Back/View = Cozy Menu, locked in every vibe.** |
| /reload during a fight could leave the pad dead | Pad buttons are written as real saved bindings (only on controller keys, which are empty by default), so they survive /reload. No secure code needed for v1. |
| Buttons that do nothing on a new character (empty bars) | Show and bind only what exists. New characters start on Questing. No class auto-fill. |
| The picker at every login is a gate full of chrome; glow pulses about 25×/min; red flashes; toasts in combat | **Login greeting, not a gate:** a small tray, world visible, last vibe focused, A = go, fades by itself. Full picker on first login, new character, or Back. Still glow, no red, no toasts in combat, "coming later" tabs hidden. |
| Mashing A can accept a stranger's party, trade or duel invite | Popups default to the safe choice and ignore A for 1.5 s. Quest-reward screen locks briefly. |
| Snap-cursor, remap UI and class auto-fill are ConsolePort-sized traps | **Deferred** past launch. |
| Beta builds change every few days | TOC lists several interface numbers, checklist re-run per patch, feature freeze Oct 28. |

## Buttons (Xbox names; glyphs follow the controller automatically)
**Always, in every vibe:**
- LS moves, RS camera.
- **A = Jump** (Ryan's choice), **RB = Interact** (talk, loot, gather).
- RT = target nearest enemy, L3 = auto-run.
- **LT (hold) = flip to your other set.**
- Start = Game Menu, Back/View = Cozy Menu.
- Inside Cozy's own menus and popups, A still means "choose / yes".

**Calm set:**
- Shared by Vibe Farming and Questing: B = Back/close; D-pad Up = Mount, Left = Map, Down = Sit.
- Vibe Farming: X = Track herbs/ore, Y = Bags, D-pad Right = Emotes.
- Questing: X = Quest item (only when usable), Y = Quest log, D-pad Right = Bags.

**Fight set:** your own action bar, with B/X/Y = slots 1–3, D-pad = 4–7, LB = 8.
- In Vibe Farming and Questing, hold LT for the fight set.
- In the Combat vibe the fight set is on top, and LT gives your calm set.

Actions are placeholders until tested in game; only actions the character actually has get bound.

## Engine (simplest thing that works)
- **Native first.**
  - Modifier = the game's own `GamePadEmulateShift` on LT (explicitly set; Ctrl/Alt cleared). Ryan's PC currently has LB = Shift and LT = Ctrl left over from ConsolePort.
  - Interact = `INTERACTTARGET` + `SoftTargetInteract=1` (gamepad only, not "always").
  - `autoLootDefault=1`; glyph style from the game's own controller label styles.
- **Bindings = data:** button → native binding ID (ACTIONBUTTONn, JUMP, INTERACTTARGET, TARGETNEARESTENEMY, TOGGLEGAMEMENU…).
  - Written out of combat as real bindings on controller keys only, so the player's keyboard binds are never touched.
  - Re-applied on vibe change. Read back with `GetBindingAction` and logged pass/fail to the diary.
- **No custom action bars.** Blizzard's bars keep doing paging, forms, stances and new spells.
  The HUD reads `ActionButtonN.action` and never touches Blizzard's buttons (taint).
- **Combat auto-flip** (fight set on top while fighting) is a **stretch goal** after launch basics are proven; it needs secure code.
- **Every setting Cozy changes is saved first; `/cozy reset` puts everything back.** No uninstall hook exists, so this matters.
- **If ConsolePort is loaded,** Cozy says so once and stays in menu-only mode.

## Launch plan (Forever launches Nov 4)
- **Week 1, prove it (by Oct 11).** Remove the ConsolePort dependency, then build a throwaway test module that logs results to the diary. Riskiest first:
  - (a) Bindings work, including mid-fight. ConsolePort's code notes a game bug where saving controller bindings can fail; check for it.
  - (b) Windows (death, quest, vendor) with a vibe active: what the pad does natively.
  - (c) Hold-LT flip in combat.
  - (d) Picker open/close, relog, login in combat.
  - (e) Settings snapshot.
  - **Gate 1:** a–d pass in one 15-minute scripted run. If two fail, cut features (fewer actions, simpler window mode), never the date.
- **Week 2 (by Oct 18):** real binder, wire the picker to real vibes, calm defaults + reset, first-run flow, HUD v0.
  **Gate 2:** 30 minutes of play on two classes, zero errors.
- **Week 3 (by Oct 25):** window helpers, mount, gear panel (5 rows), HUD icons, 3 outside testers.
  **Gate 3 acceptance test:** fresh profile, no keyboard; at most 3 presses after Enter World; jump, accept a quest, kill with the fight set, loot, sell. Zero Lua errors.
- **Week 4:** freeze Oct 28, fixes only, package (ZIP + 3-step README), re-test on each beta patch, Nov 2–3 buffer.

**Deferred past launch:** snap-cursor, full remap UI, combat auto-flip (stretch), class auto-fill, cooldown swirls on the HUD
(secret values), quest-item auto-detect beyond the basics, themes, share codes, on-screen keyboard (use quick phrases or plug in a keyboard).

## Claims we can prove at launch
Measured on a clean profile, 5+ people including 2 outside testers:
- Presses and time from Enter World to the first action.
- Number of visible settings (script-counted).
- Acceptance-test pass rate.
- Zero Lua errors or blocked actions over 60 minutes.

We will **not** claim "better" for things we haven't measured.

## Progress
- **Week 1 proof (2026-10-05):**
  - Passed, per the in-game diary:
    - All 19 test bindings wrote and read back.
    - Hold LT (emulated Shift) works in and out of combat.
    - Bindings survive combat.
    - The Back button opens the Cozy Menu.
    - Settings are saved and restored.
    - The death popup was handled.
  - Facts learned:
    - The game's own defaults already put Shift on LT.
    - Blizzard_GamepadSmartNavigation and C_GamepadUI exist.
    - issecretvalue and action-cooldown duration objects exist.
    - WOW_PROJECT_ID is 18.
  - **Not yet exercised:** quest accept/turn-in and vendor with the pad.
- **Pulled forward from week 2 (2026-10-05):**
  - Real Binder with 3 switchable vibes.
  - Picker wired to them.
  - The **Hearth Bar**: a controller-shaped action bar in the Tavern style that reads live bindings, flips on LT, shows
    cooldown/usable/range, idles to 45%, and hides the keyboard bars in controller mode.
  - Design reference: `mockups/cozy-hud/index.html`.

## Owner decisions (2026-10-05)
- Combat: **hold LT to flip** between the calm and fight sets (no automatic combat mapping for launch).
- Login: **small greeting tray** that fades by itself; full picker on first login, new characters, or Back.
- **A = Jump**, RB = Interact.
- Code checker approved: luacheck v1.2.0. It lives in `tools/bin` (git-ignored), and its settings are in `.luacheckrc`.

## Process
- **`tools\bin\luacheck.exe CozyCouchMode` must show 0 warnings before every commit.**
- One task per session.
- Every in-game session starts from a short checklist; the add-on writes pass/fail to the diary (SavedVariables), so Ryan only plays and says "done".
- A weekly always-playable tag.
- Adding scope means cutting scope.
