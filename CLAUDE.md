# Game_Design — notes for Claude

## Workflow
- **Always commit and push** finished changes to the working branch without asking. The owner does not want to review diffs first.
- Keep commits small and descriptive so any change is easy to roll back.

## Projects
- `CozyCouchMode/` — "Cozy Couch Mode", a World of Warcraft: Forever controller UI add-on (Lua). Part of the *Tavern under the Stairs* brand.
  - Goal: minimalist controller UI, smooth animations, sensible auto-mapping, activity presets (Vibe Farming, Combat, Questing), and custom layouts.
  - Setup and testing steps: `CozyCouchMode/SETUP.md`. Slash commands: `/cozy` or `/couch`.
  - Remember combat lockdown: bindings and secure frames can't change during combat.
