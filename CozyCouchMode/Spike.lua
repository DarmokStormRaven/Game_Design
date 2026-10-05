-- ===============================================================
-- Spike.lua - temporary Week 1 controller test; deleted after Gate 1.
-- Saves the player's settings before trying a small controller layout.
-- The diary records what worked so the owner can just play and /reload.
-- /cozy reset restores settings and removes the bindings we wrote.
-- ===============================================================

local _, ns = ...
local Spike = {}
ns.Spike = Spike

local PAD_KEYS = {
    "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6", "PADDUP", "PADDDOWN", "PADDLEFT", "PADDRIGHT",
    "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER", "PADLSTICK", "PADRSTICK", "PADFORWARD", "PADBACK",
}
local PREFIXES = { "", "SHIFT-", "CTRL-", "ALT-" }
local PROBE_CVARS = {
    "GamePadEnable", "GamePadEmulateShift", "GamePadEmulateCtrl", "GamePadEmulateAlt", "GamePadEmulateTapWindowMs",
    "GamePadCursorAutoEnable", "GamePadCursorLeftClick", "GamePadCursorRightClick", "SoftTargetInteract", "SoftTargetEnemy",
    "autoLootDefault", "ActionButtonUseKeyDown",
}
local MANAGED = {
    { "GamePadEnable", "1" },
    { "GamePadEmulateCtrl", "none" },
    { "GamePadEmulateAlt", "none" },
    { "GamePadEmulateShift", "PADLTRIGGER" },
    { "GamePadCursorAutoEnable", "DEFAULT" },
    { "GamePadCursorLeftClick", "DEFAULT" },
    { "GamePadCursorRightClick", "DEFAULT" },
    { "SoftTargetInteract", "1" },
    { "autoLootDefault", "1" },
}
local LAYOUT = {
    { "PAD1", "JUMP" },
    { "PADRSHOULDER", "INTERACTTARGET" },
    { "PADRTRIGGER", "TARGETNEARESTENEMY" },
    { "PADLSTICK", "TOGGLEAUTORUN" },
    { "PADFORWARD", "TOGGLEGAMEMENU" },
    { "PADBACK", "COZYCOUCH_TOGGLEMENU" },
    { "PAD2", "TOGGLEGAMEMENU" },
    { "PAD3", "OPENALLBAGS" },
    { "PAD4", "TOGGLEQUESTLOG" },
    { "PADDLEFT", "TOGGLEWORLDMAP" },
    { "PADDDOWN", "SITORSTAND" },
    { "SHIFT-PAD2", "ACTIONBUTTON1" },
    { "SHIFT-PAD3", "ACTIONBUTTON2" },
    { "SHIFT-PAD4", "ACTIONBUTTON3" },
    { "SHIFT-PADDUP", "ACTIONBUTTON4" },
    { "SHIFT-PADDRIGHT", "ACTIONBUTTON5" },
    { "SHIFT-PADDDOWN", "ACTIONBUTTON6" },
    { "SHIFT-PADDLEFT", "ACTIONBUTTON7" },
    { "SHIFT-PADLSHOULDER", "ACTIONBUTTON8" },
}
local WINDOWS = {
    "GossipFrame", "QuestFrame", "MerchantFrame", "LootFrame", "StaticPopup1", "MailFrame",
    "TaxiFrame", "BankFrame", "ContainerFrame1", "GameMenuFrame",
}
local pending = false
local events, listener
local hooked = {}
local presses = 0

-- Older clients keep these functions outside C_CVar. Missing APIs or
-- settings are reported rather than guessed at.
local function ReadCVar(name, default)
    local getter
    if C_CVar then
        if default then
            getter = C_CVar.GetCVarDefault
        else
            getter = C_CVar.GetCVar
        end
    elseif default then
        getter = GetCVarDefault
    else
        getter = GetCVar
    end
    if type(getter) == "function" then return getter(name) end
end

local function WriteCVar(name, value)
    if InCombatLockdown() then return end
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) == "function" then
        setter(name, value)
    else
        ns.Log("settings: " .. name .. " missing setter")
    end
end

function Spike:Probe()
    ns.Log("probe: WOW_PROJECT_ID = " .. tostring(WOW_PROJECT_ID))
    ns.Log("probe: WOW_PROJECT_MAINLINE = " .. tostring(WOW_PROJECT_MAINLINE))
    ns.Log("probe: WOW_PROJECT_CLASSIC = " .. tostring(WOW_PROJECT_CLASSIC))
    for _, name in ipairs(PROBE_CVARS) do
        local value, default = ReadCVar(name), ReadCVar(name, true)
        ns.Log("probe: " .. name .. " current=" .. tostring(value or "missing") .. " default=" .. tostring(default or "missing"))
    end
    local smartNavigation = C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function"
        and C_AddOns.IsAddOnLoaded("Blizzard_GamepadSmartNavigation") or false
    ns.Log("probe: C_GamepadUI = " .. tostring(C_GamepadUI ~= nil))
    ns.Log("probe: Blizzard_GamepadSmartNavigation = " .. tostring(not not smartNavigation))
    ns.Log("probe: issecretvalue = " .. tostring(type(issecretvalue) == "function"))
    ns.Log("probe: C_ActionBar.GetActionCooldownDuration = " .. tostring(C_ActionBar ~= nil and C_ActionBar.GetActionCooldownDuration ~= nil))
    ns.Log("probe: ConsolePort = " .. tostring(ConsolePort ~= nil))
    ns.Log("probe: GetCurrentBindingSet = " .. tostring(GetCurrentBindingSet()))
    local empty = 0
    for _, key in ipairs(PAD_KEYS) do
        for _, prefix in ipairs(PREFIXES) do
            local chord = prefix .. key
            local action = GetBindingAction(chord)
            if action and action ~= "" then
                ns.Log("probe: bound " .. chord .. " = " .. action)
            else
                empty = empty + 1
            end
        end
    end
    ns.Log("probe: " .. empty .. " of " .. (#PAD_KEYS * #PREFIXES) .. " controller chords are empty")
end

local function ApplySettings()
    if InCombatLockdown() then pending = true; return end
    if ConsolePort ~= nil then return end
    -- Snapshot the whole list before making any changes. Keep it across reloads.
    if ns.db.savedCVars == nil then
        ns.db.savedCVars = {}
        for _, setting in ipairs(MANAGED) do
            ns.db.savedCVars[setting[1]] = ReadCVar(setting[1])
        end
    end
    for _, setting in ipairs(MANAGED) do
        local name, value = setting[1], setting[2]
        local old = ReadCVar(name)
        if value == "DEFAULT" then value = ReadCVar(name, true) end
        if old == nil or value == nil then
            ns.Log("settings: " .. name .. " missing")
        elseif old ~= value then
            WriteCVar(name, value)
            ns.Log("settings: " .. name .. " " .. tostring(old) .. " -> " .. tostring(value))
        end
    end
end

local function ApplyLayout()
    if InCombatLockdown() then pending = true; return end
    if ConsolePort ~= nil then return end
    ns.db.cozyBindings = ns.db.cozyBindings or {}
    for _, binding in ipairs(LAYOUT) do
        local chord, action = binding[1], binding[2]
        local current = GetBindingAction(chord)
        if current == "" or ns.db.cozyBindings[chord] ~= nil then
            local ok = SetBinding(chord, action)
            if ok == false then
                ns.Log("bind: SETFAIL " .. chord)
            else
                ns.db.cozyBindings[chord] = action
            end
        else
            ns.Log("bind: SKIP " .. chord .. " (player has " .. tostring(current) .. ")")
        end
    end
    SaveBindings(GetCurrentBindingSet())
    local passes = 0
    for _, binding in ipairs(LAYOUT) do
        local chord, action = binding[1], binding[2]
        local actual = GetBindingAction(chord)
        if actual == action then
            passes = passes + 1
            ns.Log("bind: PASS " .. chord .. " = " .. action)
        else
            ns.Log("bind: FAIL " .. chord .. " wanted " .. action .. " got " .. tostring(actual))
        end
    end
    ns.Log("bind: " .. passes .. "/" .. #LAYOUT .. " pass")
end

local function SpotCheck()
    ns.Log("combat: PAD1 = " .. tostring(GetBindingAction("PAD1")))
    ns.Log("combat: SHIFT-PAD2 = " .. tostring(GetBindingAction("SHIFT-PAD2")))
end

local function HookWindows()
    for _, name in ipairs(WINDOWS) do
        local frame = _G[name]
        if frame and not hooked[frame] then
            frame:HookScript("OnShow", function()
                if not ns.db.spikeDisabled and ConsolePort == nil then ns.Log("window: " .. name .. " shown") end
            end)
            hooked[frame] = true
        end
    end
end

local function StartListening()
    if InCombatLockdown() then pending = true; return end
    if listener then return end
    listener = CreateFrame("Frame")
    listener:SetPropagateKeyboardInput(true)
    listener:EnableGamePadButton(true)
    listener:SetScript("OnGamePadButtonDown", function(_, button)
        if ns.db.spikeDisabled or ConsolePort ~= nil or presses >= 40 then return end
        local shift, combat = IsShiftKeyDown(), InCombatLockdown()
        if combat or shift then
            presses = presses + 1
            ns.Log("press: " .. button .. " shift=" .. tostring(shift) .. " combat=" .. tostring(combat))
        end
    end)
end

-- Both login and the deferred work use this safety net, so a beta API
-- error cannot interrupt the rest of the add-on.
local function Protected(work)
    local ok, err = pcall(work)
    if not ok then
        ns.Log("spike: ERROR " .. tostring(err))
        ns.Print("Cozy's test hit an error. Details are in the diary.")
    end
end

local function ApplyPending()
    if InCombatLockdown() then pending = true; return end
    if ns.db.spikeDisabled or ConsolePort ~= nil then pending = false; return end
    ApplySettings()
    ApplyLayout()
    StartListening()
    pending = false
end

local function Observe()
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", function(_, event)
            if ns.db.spikeDisabled or ConsolePort ~= nil then return end
            Protected(function()
                if event == "PLAYER_REGEN_DISABLED" then
                    ns.Log("combat: start")
                    SpotCheck()
                elseif event == "PLAYER_REGEN_ENABLED" then
                    ns.Log("combat: end")
                    SpotCheck()
                    if pending then ApplyPending() end
                elseif event == "PLAYER_DEAD" then
                    ns.Log("life: died")
                elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
                    ns.Log("life: alive")
                elseif event == "ADDON_LOADED" then
                    HookWindows()
                end
            end)
        end)
        for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD",
            "PLAYER_ALIVE", "PLAYER_UNGHOST", "ADDON_LOADED" }) do
            events:RegisterEvent(event)
        end
    end
    HookWindows()
end

function Spike:Reset()
    if InCombatLockdown() then
        ns.Print("Try again after combat.")
        return
    end
    if ns.db.spikeDisabled then
        ns.db.spikeDisabled = nil
        ns.Print("Cozy will set up again after /reload.")
        return
    end
    for name, value in pairs(ns.db.savedCVars or {}) do
        WriteCVar(name, value)
    end
    for chord in pairs(ns.db.cozyBindings or {}) do
        local ok = SetBinding(chord)
        if ok == false then ns.Log("bind: SETFAIL " .. chord) end
    end
    SaveBindings(GetCurrentBindingSet())
    ns.db.savedCVars = nil
    ns.db.cozyBindings = nil
    ns.db.spikeDisabled = true
    pending = false
    ns.Print("Cozy's test settings are removed. Type /reload to finish.")
    ns.Log("reset: done")
end

function Spike:Setup()
    Protected(function()
        if ConsolePort ~= nil then
            ns.Log("ConsolePort is loaded: spike stays out of its way")
            if type(ns.Toast) == "function" then ns.Toast("ConsolePort is on, so Cozy is staying out of its way.") end
            self:Probe()
            return
        end
        self:Probe()
        if ns.db.spikeDisabled then
            ns.Log("spike: disabled")
            return
        end
        if InCombatLockdown() then
            ns.Log("login: in combat")
            SpotCheck()
            pending = true
        else
            ApplyPending()
        end
        Observe()
    end)
end
