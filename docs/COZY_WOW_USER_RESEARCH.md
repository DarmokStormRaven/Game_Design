# Cozy WoW — user research for Hearthfire UI

_2026-11-21. Phase 1: desk research — community voices, the cozy-design framework, and the
niche landscape. Phase 2 (below) is the validation kit: interviews + survey with real
players. Evidence here is anecdotal community material plus one academic framework; treat
it as strong direction, not proof, until Phase 2 runs._

## Objective

Find what players would want in a "cozy setup" for WoW: Forever, so Hearthfire can own
the cozy niche (vs. fighting feature-by-feature battles like KyruxDamage over combat text).

## Headline findings

1. **The demand is real and just got orphaned.** Turtle WoW — whose own tagline was a
   "stress free, rush free, fun, and cozy place to play" — ran 8 years with thousands of
   players before the Blizzard lawsuit shut it down. That cohort is migrating to Forever,
   which press frames as "casual friendly again." Nobody has built them a home in the UI.
2. **"Cozy WoW" already exists as a play style, not a game mode.** Players describe it
   themselves: pet and transmog collecting, fishing, professions, RP wandering, slow
   leveling with YouTube on the second screen. The game supports it; the *interface*
   doesn't — it keeps yelling raid-game urgency at putterers.
3. **Neurodivergent players are the loudest articulators of the need.** Forum threads
   from ADHD/autistic players ask for control over how information is presented
   (visually AND audibly), say addons are critical to playing at all — and, crucially,
   that **addons themselves often overwhelm** (settings sprawl is a failure mode).
4. **The niche is stirring but fragmented:** an "AuDHD" addon (shows one next step at a
   time, everything modular), and "Sensory Vignette" (shades screen edges to cut
   peripheral motion, released Nov 8 2026 by the Misophonia Foundation). Single-purpose
   tools. No one ships the full cozy layer. The audit's market scan agrees (warm-themed
   UIs are tiny; ClassicUI Forever's 436K downloads are nostalgia, not coziness).
5. **Cozy is a validated, giant market elsewhere:** cozy-game revenue estimates run
   $1–4B/yr (sources conflict; all agree it's large and growing), ~375 "cozy" Steam
   releases in 2024 alone, "cozy" called the dominant Steam keyword of 2026. The WoW
   addon ecosystem simply hasn't caught up to the trend. First-mover space.

## The design framework: Safety, Abundance, Softness

Project Horseshoe's cozy-games framework (2017) defines coziness as the fantasy of
**safety** (no danger, okay to be vulnerable), **abundance** (needs met, always something
gentle to do), and **softness** (low-arousal stimuli, slow tempo, comfort aesthetics) —
and stresses that coziness is an *aesthetic any genre can adopt* and that the main
destroyers are **interruptions and pressure**.

Use it as the acceptance test for every Hearthfire feature: _does this add safety,
abundance, or softness — or does it interrupt or pressure?_

Stock WoW's cozy blockers, through that lens: red error text and flashing procs
(softness), unsolicited duel/party/trade popups (safety), the quest tracker's constant
"go go go" (pressure), login screens full of promotions (interruption), losing your
place between sessions (abundance of friction, not of play).

## What this validates in Hearthfire today

- **Reading fonts (Lexend etc.)** — softness + accessibility; the research's clearest
  "no one else does this" feature. Market harder.
- **Framed chat, lantern board, letters-for-whispers** — social softness; cozy players
  are heavily social-ambient.
- **Wooden skins over Blizzard frames** — softness without replacing function (the
  "layer, not replacement" positioning matches how cozy players actually play).
- **The lite shape (opt-in modules)** — directly validated: "the addons themselves
  overwhelm me." Modularity and few visible settings ARE cozy features.
- **The Journal** — reframe it: not a second quest log (the audit's duplicate concern)
  but a **session re-entry and savoring companion**. ADHD players' biggest unmet need in
  long games is "what was I doing?" A journal that answers that is unique.

## New feature candidates from the research (prioritized)

1. **Welcome-back card** (high value, small build): on login, one soft panel — where you
   are, what you were doing, one gentle suggestion. Kills the ADHD re-entry wall.
   Feeds from the Journal. (Pattern precedent: AuDHD's "one next step at a time.")
2. **Cozy mode / do-not-disturb**: one toggle that suppresses non-essential popups and
   toasts, defaults popups to the safe choice with a short input lock (the Cozy Couch
   popup-safety lesson, now externally validated), and quiets glow/pulse effects.
3. **Sensory sliders**: motion/glow/pulse intensity controls in /hfui. Coordinate with,
   don't duplicate, Sensory Vignette (detect it; recommend it; stay compatible).
4. **Second-screen legibility**: cozy players half-watch media; key info must read at a
   glance from couch distance (ties to reading fonts + damage-number work).
5. **Putter loops support** (later): gentle fishing/collecting/profession touches —
   coexist with dedicated addons rather than rebuild.

## Positioning language (evidence-backed)

"The cozy, easy-to-read layer over Blizzard's UI" (audit) holds. Add the Turtle echo —
**stress free, rush free** — to the CurseForge copy; it's the phrase the orphaned
community already uses for what they want. AuDHD and Sensory Vignette are allies for
cross-recommendation, not rivals.

## Phase 2 — validation kit

**Method:** 5–8 interviews (30–40 min) + a 10-question survey. Per the research-methods
table this is the right size for needs-finding; a 1-week diary study is the stretch
option — and Hearthfire can reuse the Cozy Couch in-game diary pattern (SavedVariables
notes) so participants log friction the moment it happens.

**Recruit from:** the "Is WoW a cozy game?" and ADHD-accessibility forum threads (reply
to posters), r/CozyGamers and r/wow, ex-Turtle WoW community spaces, comment sections of
AuDHD / Sensory Vignette, and the guild. Ryan + daughter are pilot participants (note
insider bias; run the pilot first to tune questions).

**Interview guide:**
- Warm-up: How long have you played? What does a good WoW evening look like?
- Context: Walk me through your last session, from login to logout. Where did the UI
  help; where did it poke you?
- Deep dive: Tell me about the last time WoW felt *cozy*. What were you doing? What was
  on screen? · Tell me about the last time it felt overwhelming — what exactly spiked it
  (visual, audio, social, pressure)? · When you return after a week away, what happens in
  your head? What do you do first? · If you could mute three things in the interface
  forever, what are they? · What do you putter at (collecting, fishing, professions, RP)?
  What's annoying about doing it?
- Reaction: show Hearthfire screenshots (cast bar, chat, fonts, journal) and the
  welcome-back card concept. "What would you expect this to do? What's missing? Would
  you install it — why/why not?"
- Wrap: What didn't I ask about? Who else should I talk to?

**Survey (link in CurseForge description + subreddit posts):** 1) How do you mostly play?
(putter/level/dungeon/raid/RP/collect) 2) Rate agreement: "WoW's interface stresses me
out more than the game does." 3) Which bothers you most: flashing effects / popups /
clutter / sounds / losing my place between sessions? 4) After time away, how hard is it
to pick WoW back up? 5) Do you identify as a cozy gamer? 6) Neurodivergent (optional,
ADHD/autism/other/prefer not to say)? 7) Rank 5 feature cards (welcome-back, cozy mode,
reading fonts, warm skins, journal). 8) What addon made WoW calmer for you? 9) What
would make WoW feel like Stardew for an evening? (free text) 10) May we follow up?

**Success metrics for the niche claim** (same discipline as Cozy's "claims we can
prove"): % identifying as cozy/neurodivergent in installs' survey responses, welcome-back
card usage rate, settings-opened-per-session (lower = calmer), qualitative "calm" words
in reviews.

## Sources

- Blizzard forums: "Is WoW a cozy game?"; "Really Worried About Addon Changes (ADHD &
  Accessibility)"; "As a player with autism and ADD, addons have been critical for me";
  "This game is hard for someone with ADHD"
- Project Horseshoe 2017 cozy-games report (via Kitfox "Designing for Coziness", 80.lv,
  uxdesign.cc summaries)
- CurseForge: AuDHD addon; PRLog: Sensory Vignette (Misophonia Foundation, 2026-11-08)
- Turtle WoW shutdown coverage: Windows Central, GamesRadar, MassivelyOP
- WoW Forever casual reception: PC Gamer, MassivelyOP "Casually Classic", Team
  Overpowered launch-week feedback, Blizzard forums "Leveling is soul-crushingly slooow!"
- Market: VoxBooster/IntelMarketResearch cozy-market figures (low-authority, conflicting;
  direction only), Rolling Stone on r/CozyGamers, Outlook Respawn on "cozy" as 2026's
  dominant Steam keyword
