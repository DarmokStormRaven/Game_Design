-- Luacheck settings for Cozy Couch Mode (a World of Warcraft add-on, Lua 5.1).
-- Run from the repo root:  tools\bin\luacheck.exe CozyCouchMode
-- (tools\bin is git-ignored; get luacheck.exe v1.2.0 from github.com/lunarmodules/luacheck/releases)

std = "lua51"
max_line_length = 150
exclude_files = { "tools/**", "mockups/**" }

-- "self" is often unused or re-declared in WoW script callbacks; that's normal.
ignore = { "212/self", "432/self" }

-- Globals WoW requires us to create or change (saved variables, slash commands, key binding names).
globals = {
    "CozyCouchModeDB",
    "SLASH_COZYCOUCH1", "SLASH_COZYCOUCH2", "SlashCmdList",
    "BINDING_HEADER_COZYCOUCH", "BINDING_NAME_COZYCOUCH_TOGGLEMENU",
}

-- WoW API we only read. Add new names here when the code starts using them;
-- an unknown name usually means a typo or an API that doesn't exist.
read_globals = {
    "UIPanelWindows", "SetOverrideBinding", "GetCursorInfo", "ClearCursor", "PickupAction",
    "C_Container", "C_SpellBook", "C_Spell", "GameTooltip", "SetGamePadCursorControl", "SpellBook_GetSpellBookSlot",
    "C_AddOns", "C_GamePad", "C_Timer", "ClearOverrideBindings", "ConsolePort", "CreateFrame",
    "date", "GetAddOnMetadata", "GetBindingAction", "GetBindingKey", "GetBuildInfo",
    "InCombatLockdown", "IsUsingMouse", "SetOverrideBindingClick", "strtrim", "tinsert",
    "UIParent", "UISpecialFrames", "WorldFrame", "RegisterStateDriver", "GetTime", "wipe",
    "C_CVar", "C_GamepadUI", "C_ActionBar", "issecretvalue", "IsShiftKeyDown",
    "GetCVar", "GetCVarDefault", "SetCVar", "GetCurrentBindingSet", "SetBinding", "SaveBindings",
    "WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC",
    "CreateColor", "GetActionTexture", "GetActionCooldown", "IsUsableAction", "IsActionInRange",
    "UnitXP", "UnitXPMax", "UnitLevel", "GetMaxPlayerLevel",
}
