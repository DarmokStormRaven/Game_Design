# Cozy Couch Mode: Setup

*A Tavern under the Stairs project.*

About 15 minutes, one time only. After this, new versions are just "Fetch/Pull" + `/reload`.

## Step 1: Get the code onto your PC (GitHub Desktop)

1. Install **GitHub Desktop** (desktop.github.com) and sign in with your GitHub account.
2. **File → Clone repository** → pick `darmokstormraven/game_design`.
   Set **Local path** to `C:\Code\Game_Design` → **Clone**.
3. Click **Current branch** at the top → choose `claude/modest-feynman-xeec61`.
   (Not listed? Click **Fetch origin** first.)
4. ✅ You now have `C:\Code\Game_Design\CozyCouchMode` on your PC.

## Step 2: Find the Forever beta's AddOns folder

1. Open the **Battle.net** app → select **WoW Forever (beta)** in the game picker.
2. Click the **gear ⚙️** next to Play → **Show in Explorer**.
3. Open the folder for the beta (name has "forever" or "beta" in it), then `Interface` → `AddOns`.
   - No `Interface` or `AddOns` folder? Right-click → New → Folder and create them.
4. Click the address bar at the top of File Explorer and **copy** the full path.

## Step 3: Link the add-on into WoW

A **junction** is a shortcut folder that WoW treats as the real thing, so WoW always
reads the latest code straight from your repo. No copying, no admin rights needed.

1. Press the **Windows key**, type `cmd`, press **Enter**.
2. Type this, pasting your AddOns path where shown (keep the quotes):

   ```bat
   mklink /J "PASTE-ADDONS-PATH-HERE\CozyCouchMode" "C:\Code\Game_Design\CozyCouchMode"
   ```

3. ✅ It should say `Junction created for ...`.

**To undo:** delete the `CozyCouchMode` folder inside AddOns. Only the shortcut is removed; your code is safe.

## Step 4: Turn on the controller in WoW

1. Plug in or pair your controller **before** starting the game.
2. Launch the beta and log into a character.
3. In chat, type `/console GamePadEnable 1` and press Enter, then type `/reload`.
   (Or turn on **Gamepad** in the game's Options → Controls.)

## Step 5: Turn on the add-on

1. Log out to character select → click **AddOns** (bottom left).
2. Make sure **Cozy Couch Mode** is checked.
   If it says "out of date", tick **Load out-of-date AddOns** at the top.
3. Log in. ✅ Chat says: `Cozy ready! Type /cozy for commands.`

## Step 6: Try it 🎉

1. Press any button on the controller → a diamond of 4 glowing buttons fades in.
2. Press **A, B, X, Y** → each one pops and lights up.
3. Click the mouse → the panel fades away.
4. Nothing showing? Type `/cozy show` to force it on, and `/cozy debug` for extra info.

## Step 7: Report back

Type `/cozy status` and send Claude a screenshot or copy of what it prints.

## Getting updates later

GitHub Desktop → **Fetch origin** → **Pull origin** → in game type `/reload`. Done.

## Dev tips

- `/reload` reloads your UI after code changes. No need to restart the game.
- Install the **BugSack** + **BugGrabber** add-ons to see Lua errors clearly.
- VS Code + the **"WoW API"** extension (by Ketho) gives autocomplete for WoW functions.
