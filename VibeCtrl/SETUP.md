# Vibe Controlling: Setup

## 1. Link the add-on into WoW (one time)

WoW loads add-ons from a folder inside your game install. Instead of copying files there
every time you change something, we create a **junction**: a shortcut folder that WoW
treats as the real thing. You edit files in this repo, and WoW sees the changes.

1. Find your Forever beta install. In your `World of Warcraft` folder, look for a
   folder with "forever" or "beta" in its name (for example `_forever_beta_`).
2. Open **Command Prompt** (not PowerShell) and run this, fixing both paths:

   ```bat
   mklink /J "C:\Program Files (x86)\World of Warcraft\_forever_beta_\Interface\AddOns\VibeCtrl" "C:\path\to\Game_Design\VibeCtrl"
   ```

   - If `Interface\AddOns` doesn't exist yet, create those folders first.
   - The folder name **must** be `VibeCtrl` so it matches `VibeCtrl.toc`.

**To undo:** delete the `VibeCtrl` junction in the AddOns folder. This removes only
the shortcut, not your code.

## 2. Turn on controller support in the game

Options → Controls (or Gameplay) → enable **Gamepad**. It may be labeled "Gamepad (Alpha)" in the beta.

## 3. Test it

1. At character select, click **AddOns** and make sure *Vibe Controlling* is checked.
   If it says "out of date", tick **Load out-of-date AddOns** for now.
2. Log in. The chat window should say: `Vibe ready! Type /vibe for commands.`
3. Pick up your controller and press something. A diamond of 4 glowing buttons should fade in.
   Press A, B, X, or Y to watch each one pop. Click the mouse and the panel fades away.
4. If nothing shows, type `/vibe show` to force it on, and `/vibe debug` to see extra info.

## 4. Report back (this helps us!)

Type `/vibe status` and send me what it prints, especially the **interface number**
(it goes on the first line of `VibeCtrl.toc`) and whether `GAME_PAD_ACTIVE_CHANGED` is `true`.

## Dev tips

- `/reload` reloads your UI after you edit code. No need to restart the game.
- Install the **BugSack** + **BugGrabber** add-ons to see Lua errors clearly.
- VS Code + the **"WoW API"** extension (by Ketho) gives autocomplete for WoW functions.
