-- ===============================================================
-- Core.lua — the "brain" of the add-on.
--
-- Its jobs:
--   1. Load saved settings.
--   2. Figure out whether you're playing on controller or mouse.
--   3. Tell the Panel (Panel.lua) to fade in or out.
--   4. Handle the /cozy chat command.
-- ===============================================================

-- Every add-on file receives two values from WoW: the add-on's folder
-- name and a private table shared by all of this add-on's files.
-- We call that shared table "ns" (namespace). Putting things in "ns"
-- instead of making them global keeps us from clashing with other add-ons.
local ADDON_NAME, ns = ...

-- Settings used the very first time (before anything is saved).
local DEFAULTS = {
    enabled = true,   -- master on/off switch
    debug   = false,  -- print extra info to chat while developing
}

-- Short helper to print a colored message in the chat window.
-- |cffffb347 ... |r is WoW's color code: "start warm amber ... reset color".
function ns.Print(...)
    print("|cffffb347Cozy|r", ...)
end

function ns.Debug(...)
    if ns.db and ns.db.debug then
        ns.Print("|cff888888[debug]|r", ...)
    end
end

-- ---------------------------------------------------------------
-- Input mode: are we on "gamepad" or "mouse"?
-- ---------------------------------------------------------------
ns.mode = "mouse"

function ns.SetMode(newMode)
    if newMode == ns.mode then return end   -- nothing changed, do nothing
    ns.mode = newMode
    ns.Debug("input mode ->", newMode)
    if ns.Panel then
        ns.Panel:SetVisible(ns.db.enabled and newMode == "gamepad")
    end
end

-- ---------------------------------------------------------------
-- Events: WoW "shouts" events when things happen. A frame can
-- register to hear specific events and react in its OnEvent script.
-- ---------------------------------------------------------------
local events = CreateFrame("Frame")

-- We try TWO ways of detecting controller use, because WoW Forever is
-- in beta and we want this to keep working if one of them changes:
--   A) GAME_PAD_ACTIVE_CHANGED — WoW tells us directly (best).
--   B) Backup: a controller button press means "gamepad" (see Panel.lua),
--      and a mouse click (GLOBAL_MOUSE_DOWN) means "mouse".
-- pcall = "protected call": try it, and if the event doesn't exist in
-- this game version, don't crash, just return false.
ns.hasActiveEvent = pcall(events.RegisterEvent, events, "GAME_PAD_ACTIVE_CHANGED")
pcall(events.RegisterEvent, events, "GLOBAL_MOUSE_DOWN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= ADDON_NAME then return end  -- some other add-on loaded

        -- Saved settings are ready now. Create them if this is the first run,
        -- and fill in any new default settings added in later versions.
        CozyCouchModeDB = CozyCouchModeDB or {}
        for key, value in pairs(DEFAULTS) do
            if CozyCouchModeDB[key] == nil then CozyCouchModeDB[key] = value end
        end
        ns.db = CozyCouchModeDB

    elseif event == "PLAYER_LOGIN" then
        ns.Panel:Setup()
        -- If a controller is already active when we log in, show right away.
        if C_GamePad and C_GamePad.IsEnabled and C_GamePad.IsEnabled()
           and not IsUsingMouse() then
            ns.SetMode("gamepad")
        end
        ns.Print("ready! Type |cffffd100/cozy|r for commands.")

    elseif event == "GAME_PAD_ACTIVE_CHANGED" then
        local isActive = ...
        ns.SetMode(isActive and "gamepad" or "mouse")

    elseif event == "GLOBAL_MOUSE_DOWN" then
        ns.SetMode("mouse")
    end
end)

-- ---------------------------------------------------------------
-- Slash commands: /cozy (or /couch)
-- ---------------------------------------------------------------
SLASH_COZYCOUCH1 = "/cozy"
SLASH_COZYCOUCH2 = "/couch"
SlashCmdList.COZYCOUCH = function(msg)
    local cmd = strtrim(msg or ""):lower()

    if cmd == "show" then          -- force the panel on (for testing)
        ns.SetMode("gamepad")
    elseif cmd == "hide" then      -- force the panel off
        ns.SetMode("mouse")
    elseif cmd == "on" or cmd == "off" then
        ns.db.enabled = (cmd == "on")
        ns.Print("enabled =", tostring(ns.db.enabled))
        ns.Panel:SetVisible(ns.db.enabled and ns.mode == "gamepad")
    elseif cmd == "debug" then
        ns.db.debug = not ns.db.debug
        ns.Print("debug =", tostring(ns.db.debug))
    elseif cmd == "status" then
        -- Handy facts to report back while testing the beta.
        local version, build, _, tocVersion = GetBuildInfo()
        ns.Print("game version:", version, "build", build)
        ns.Print("interface number (put in .toc):", tocVersion)
        ns.Print("gamepad enabled:", tostring(C_GamePad and C_GamePad.IsEnabled()))
        ns.Print("GAME_PAD_ACTIVE_CHANGED event:", tostring(ns.hasActiveEvent))
        ns.Print("current mode:", ns.mode)
    else
        ns.Print("commands: |cffffd100show|r, |cffffd100hide|r, |cffffd100on|r, "
            .. "|cffffd100off|r, |cffffd100debug|r, |cffffd100status|r")
    end
end
