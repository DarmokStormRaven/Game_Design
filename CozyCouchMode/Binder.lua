-- ===============================================================
-- Binder.lua - writes the selected vibe onto controller keys only.
-- Player bindings stay put; work requested during combat waits.
-- ===============================================================

local _, ns = ...
local Binder = {}
ns.Binder = Binder
local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if Binder.pending then Binder:Apply(Binder.pending) end
end)

-- ---------------------------------------------------------------
-- Read back every chord: beta clients can reject a binding write.
-- ---------------------------------------------------------------
function Binder:Save()
    if InCombatLockdown() then return end
    if type(SaveBindings) == "function" and type(GetCurrentBindingSet) == "function" then
        SaveBindings(GetCurrentBindingSet())
    end
end

function Binder:Apply(reason)
    reason = reason or "requested"
    if InCombatLockdown() then
        self.pending = reason
        ns.Log("binder: waiting for combat to end (" .. reason .. ")")
        return
    end
    self.pending = nil
    local loaded = ConsolePort ~= nil
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        loaded = loaded or C_AddOns.IsAddOnLoaded("ConsolePort")
    end
    if loaded then ns.Log("binder: ConsolePort loaded; skipped"); return end
    if ns.db.spikeDisabled then ns.Log("binder: spike disabled; skipped"); return end
    if type(GetBindingAction) ~= "function" or type(SetBinding) ~= "function"
        or type(SaveBindings) ~= "function" or type(GetCurrentBindingSet) ~= "function" then
        ns.Log("binder: binding API unavailable")
        return
    end
    local wanted = ns.Vibes:BuildBindings(ns.db.activePreset or 1)
    ns.db.cozyBindings = ns.db.cozyBindings or {}
    local owned = ns.db.cozyBindings
    for chord, action in pairs(wanted) do
        local current = GetBindingAction(chord)
        if current == "" or owned[chord] ~= nil then
            SetBinding(chord, action)
            -- Trust the read-back, not SetBinding's return value (it differs between client versions).
            if GetBindingAction(chord) == action then owned[chord] = action end
        else
            ns.Log("binder: SKIP " .. chord .. " (player has " .. tostring(current) .. ")")
        end
    end
    for chord in pairs(owned) do
        if not wanted[chord] then
            SetBinding(chord)
            if GetBindingAction(chord) == "" then owned[chord] = nil end
        end
    end
    self:Save()
    local passes, total = 0, 0
    for chord, action in pairs(wanted) do
        total = total + 1
        local actual = GetBindingAction(chord)
        if actual == action then
            passes = passes + 1
        else
            ns.Log("binder: FAIL " .. chord .. " wanted " .. action .. " got " .. tostring(actual))
        end
    end
    local vibe = ns.Vibes[ns.db.activePreset or 1] or ns.Vibes[1]
    ns.Log("binder: " .. vibe.name .. " " .. passes .. "/" .. total .. " pass")
    if ns.HUD then ns.HUD:Refresh() end
end
