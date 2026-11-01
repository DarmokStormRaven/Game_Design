# Wallop! — addon gap analysis

_Drafted 2026-11-01. Owner: Ryan. **Supersedes ADDON_GAP_ANALYSIS.md (Cozy Couch Mode), which
is retired: the active project is Wallop.**_

_Status: **provisional.** The Instagram reel that prompted this (reel `DfDBv9SNwa5`) cannot be
opened from the cloud session — Instagram is outside the allowed network domains, and the reel
is not indexed anywhere public. This doc compares Wallop against the addons that do Wallop's
job today, which is what combat-feedback addon reels feature. Reconcile against the reel's
actual lineup when Ryan pastes it (or allows `www.instagram.com` in the environment's
network settings)._

## What Wallop is today

Wallop exists as **mockups only** — the "Wallop Mockups" design canvas
(https://claude.ai/artifact/NbwV1K8DN7ZGn1aVSqBM88, 2026-10-10). Zero Lua has been written.
The designed v1.0 feature set:

- **Damage font** — comic (Bangers) numbers popping off targets
- **Cast punch** — your ability icon slams onto the screen
- **Ready pulse** — big icon + chime when a cooldown comes back (slider: ignore cooldowns under N s)
- **Shockwave ring** — burst behind ready icons
- **Proc alert** — flash when a button lights up
- **Combat banner** — "FIGHT!" slams in when combat starts
- **Spell types** — Holy/Frost/Fire/Shadow/Arcane/Nature/Ranged/Physical, matched by words in
  the spell name; each type has a glow color and a sound; "pin a spell to a type or sound"
- **Sounds** — per-event sounds, an 18-sound library, custom `.ogg`/`.mp3` via `Wallop\Sounds\Custom`
- **Layout mode** — drag see-through zones (banner / ready+proc / cast punch) on the real screen
- **Settings** — `/wallop` panel, per-character profile, test-effects button, reset per tab

## The addons in Wallop's space, and the gap each exposes

### 1. MikScrollingBattleText / Parrot / xCT+ (scrolling combat text)
**They do:** animated damage numbers in configurable scroll areas, with filtering.
**Wallop's gap — the big one: spam handling.** One comic "1,284!" looks great; a whirlwind
hitting six mobs twice a second becomes unreadable noise — the opposite of dopamine.
These addons solve it by **merging repeated hits** ("Fireball ×4  3,210") and throttling.
**Fill:** a merge window (hits of the same spell within ~0.75 s combine into one bigger,
louder number) and a hard cap on simultaneous numbers. This is a v1 requirement, not polish.

### 2. Doom_CooldownPulse (the classic cooldown-ready flash)
**It does:** exactly Wallop's Ready pulse — icon flashes center-screen when a cooldown finishes.
**Wallop's gap:** none in concept — Wallop's version is *richer* (sound + shockwave + size
slider + min-cooldown filter). The gap is the detail that addon learned the hard way:
**ignore items/trinkets and spells you can't use**, else the pulse fires constantly and
players turn it off.
**Fill:** pulse only player-castable spells by default; the "ignore under N s" slider already
designed covers the rest.

### 3. OmniCC (cooldown numbers on buttons)
**It does:** countdown text on action buttons.
**Wallop's gap:** none — different moment (waiting vs. ready). **Coexist**; never draw on
action buttons, so the two can't fight.

### 4. WeakAuras (custom proc/trigger toolkit; limited on Forever)
**It does:** anything, if you program it.
**Wallop's gap:** none to close — Wallop IS the "no setup" alternative. The one idea worth
keeping from reels about it: per-spell overrides. The mockup's **"pin a spell to a type or
sound"** already covers this. Keep it in v1; it's the escape hatch that stops feature requests.

### 5. GTFO (audio alert when you stand in bad stuff)
**It does:** instant "move!" sound on avoidable damage.
**Wallop's gap:** Wallop celebrates what the *player* does, but has **no "ouch" channel** —
taking a big hit is silent. One subtle incoming-damage sound/flinch would complete the
feel loop (hit things = juicy, get hit = visceral).
**Fill:** post-v1 candidate, one toggle, default off.

### 6. SharedMedia / LibSharedMedia (fonts and sounds registry shared across addons)
**It does:** lets any addon's fonts/sounds show up in every other addon's dropdowns.
**Wallop's gap:** the custom-sounds folder is designed, but **not LSM registration**.
Registering Wallop's 18 sounds + Bangers with LSM makes Wallop instantly useful even to
people who keep MSBT — and pulls their media into Wallop's dropdowns for free.
**Fill:** ~20 lines of Lua, big ecosystem win. v1.

### 7. DBM / BigWigs (boss warnings)
**Different lane** (danger ahead vs. feedback now). **Coexist** — but both slam banners
mid-screen. **Fill:** Wallop's layout zones must be movable (already designed) and the combat
banner should auto-suppress while a boss-mod bar is on screen. Small v1.1 nicety.

### 8. The generic "must-have" reel list (Questie, TomTom, Leatrix, bag addons…)
**Different lane entirely** — navigation and QoL. No gaps; nothing to borrow. If the reel was
this list, the honest answer is: Wallop competes with none of them and should say so in its
CurseForge description ("works alongside everything").

## Two meta-gaps bigger than any addon

1. **Wallop has no code.** The mockups are a complete spec; the addon is 0% built. Every
   feature-gap above is academic until a `Wallop/` folder with a TOC file exists.
2. **WoW already draws damage numbers.** Floating combat text is a game feature; Wallop must
   either restyle it (the `DAMAGE_TEXT_FONT` override — set once at login, this is how damage-font
   addons work) or replace it from the combat log and tell the player to turn the Blizzard one
   off. Decide this first — it shapes the whole Effects module. Same class of decision as
   Cozy's "native first" rule, and the same testing lesson applies: WoW only scans addon
   sound/font files at launch, hence the mockup's "restart the game" note.

## How to proceed, in order

1. **Confirm the reel** — paste its addon names into chat, or allow `www.instagram.com` in the
   environment's network settings; this doc gets reconciled in minutes.
2. **Decide the damage-number strategy** (restyle native vs. rebuild from combat log).
   Recommendation: v1 restyles native (font override + game's own numbers), because it's
   ~50 lines and zero spam risk; rebuild later only if Forever's native text proves too rigid.
3. **Scaffold the addon** in this repo: `Wallop/Wallop.toc` + `Core.lua`, `Effects.lua`,
   `Types.lua`, `Sounds.lua`, `Layout.lua`, `Panel.lua`, reusing what Cozy already proved:
   luacheck config, the in-game diary test pattern, the art pipeline (`tools/build_art.py`)
   for TGA textures, and the combat-lockdown rules. Cozy is retired as a product, not as
   parts.
4. **Build in dopamine order** (each step playable same-day): combat banner → ready pulse +
   chime → damage font override → cast punch → spell-type sounds → proc alert → layout mode →
   settings panel last (hardcoded defaults until then).
5. **Bake in the gap fixes from day one:** merge/cap spam (#1), castable-only pulses (#2),
   LSM registration (#6).
6. **Convert brand assets** — Bangers needs to ship as a `.ttf` in the addon; the mockup's
   sound names need real `.ogg` files (freesound/jsfxr, license-checked).
