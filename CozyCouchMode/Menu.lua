-- ===============================================================
-- Menu.lua — a plain controller menu for testing button control.
--
-- Back opens or closes it. While open, the D-pad picks a preset,
-- the shoulder buttons change tabs, A chooses, and B closes.
-- Closing gives the game's buttons back. Combat keeps the menu shut.
-- A saved diary helps us check what happened after a /reload.
-- ===============================================================

local _, ns = ...

local OPEN_KEY = "PADBACK"
local NAV_KEYS = {
    PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PAD1 = "CHOOSE", PAD2 = "CLOSE",
    PADLSHOULDER = "TABPREV", PADRSHOULDER = "TABNEXT",
}
local PRESET_NAMES = { "Vibe Farming", "Questing", "Combat" }
local TAB_NAMES = { "Presets", "Layout", "Look", "Settings" }

local Menu = CreateFrame("Frame", "CozyCouchMenu", UIParent)
Menu:Hide()  -- Hide before installing OnHide so loading isn't logged as closing.
ns.Menu = Menu
tinsert(UISpecialFrames, "CozyCouchMenu")

Menu.focus = 1
Menu.tab = 1
local needsOpenerBind = false
local needsRelease = false
local loggedDefaults = false

-- Separate owners let us release navigation without losing the Back opener.
local openOwner = CreateFrame("Frame")
local navOwner = CreateFrame("Frame")

local opener = CreateFrame("Button", "CozyCouchMenuOpener")
opener:RegisterForClicks("AnyDown")
opener:SetScript("OnClick", function(self, mouseButton, down)
    if down == false then return end
    Menu:Toggle("Back button")
end)

local nav = CreateFrame("Button", "CozyCouchMenuNav")
nav:RegisterForClicks("AnyDown")
nav:SetScript("OnClick", function(self, action, down)
    if down == false then return end
    -- Each override sends our action word as the click's button name.
    Menu:Nav(action)
end)

-- ---------------------------------------------------------------
-- Drawing helpers and the current highlight.
-- ---------------------------------------------------------------
local function Wrap(i, n) return (i - 1) % n + 1 end

local function CreateBorder(frame)
    local edges = {}
    for i, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetColorTexture(0.94, 0.72, 0.24, 1)
        if edge == "TOP" or edge == "BOTTOM" then
            texture:SetHeight(2)
            texture:SetPoint(edge .. "LEFT", frame, edge .. "LEFT", 0, 0)
            texture:SetPoint(edge .. "RIGHT", frame, edge .. "RIGHT", 0, 0)
        else
            texture:SetWidth(2)
            texture:SetPoint("TOP" .. edge, frame, "TOP" .. edge, 0, 0)
            texture:SetPoint("BOTTOM" .. edge, frame, "BOTTOM" .. edge, 0, 0)
        end
        edges[i] = texture
    end
    return edges
end

function Menu:Refresh()
    for i, tab in ipairs(self.tabs) do
        if i == self.tab then
            tab:SetTextColor(1, 0.84, 0.44)
        else
            tab:SetTextColor(0.72, 0.66, 0.53)
        end
    end
    for i, box in ipairs(self.boxes) do
        box:SetShown(self.tab == 1)
        if i == self.focus then
            box.background:SetColorTexture(0.38, 0.26, 0.11, 1)
        else
            box.background:SetColorTexture(0.18, 0.13, 0.08, 1)
        end
        for _, edge in ipairs(box.border) do
            edge:SetShown(i == self.focus)
        end
    end
    self.comingLater:SetText(TAB_NAMES[self.tab] .. ": coming later")
    self.comingLater:SetShown(self.tab ~= 1)
end

-- ---------------------------------------------------------------
-- Temporary overrides leave the player's saved bindings alone.
--
-- An "override binding" says: "when this button is pressed, click our
-- hidden button instead of doing its normal job". It lasts until we
-- clear it (or until /reload), and your real keybinds are never changed.
-- WoW only allows adding or clearing them OUT of combat.
-- ---------------------------------------------------------------
local function BindOpener()
    if InCombatLockdown() then
        needsOpenerBind = true
        ns.Log("opener waits for combat to end")
        return
    end
    ns.Log("before override,", OPEN_KEY, "was bound to:", GetBindingAction(OPEN_KEY))
    SetOverrideBindingClick(openOwner, true, OPEN_KEY, "CozyCouchMenuOpener")
    needsOpenerBind = false
    ns.Log("opener bound to", OPEN_KEY)
end

local function TakeNavButtons()
    -- Open checks combat lockdown before reaching this binding change.
    if not loggedDefaults then
        for key in pairs(NAV_KEYS) do
            ns.Log("while open,", key, "normally does:", GetBindingAction(key))
        end
        loggedDefaults = true
    end
    for key, action in pairs(NAV_KEYS) do
        SetOverrideBindingClick(navOwner, true, key, "CozyCouchMenuNav", action)
    end
end

local function ReleaseNavButtons()
    -- WoW forbids binding changes during lockdown; retry after combat.
    if InCombatLockdown() then
        if not needsRelease then
            ns.Print("Your menu buttons come back after this fight.")
        end
        needsRelease = true
        ns.Log("WARNING: could not release buttons in combat; will release after combat")
        return
    end
    ClearOverrideBindings(navOwner)
    needsRelease = false
end

-- ---------------------------------------------------------------
-- Opening, closing, and controller actions.
-- ---------------------------------------------------------------
function Menu:Open(source)
    if self:IsShown() then return end
    if InCombatLockdown() then
        ns.Print("The Cozy Menu opens after combat.")
        ns.Log("open blocked (combat) via", source)
        return
    end
    self.focus = 1
    self.tab = 1
    self:Refresh()
    TakeNavButtons()
    self:Show()
    ns.Log("opened via", source)
end

function Menu:Close(reason)
    if not self:IsShown() then return end
    self.closeReason = reason
    self:Hide()
    -- OnHide only fires if the menu was actually visible (not if the whole
    -- UI was hidden with Alt+Z), so release here too. Releasing twice is harmless.
    ReleaseNavButtons()
end

function Menu:Toggle(source)
    if self:IsShown() then
        self:Close(source)
    else
        self:Open(source)
    end
end

function Menu:Nav(action)
    if not self:IsShown() then return end
    ns.Log("press", action)
    if action == "LEFT" then
        if self.tab == 1 then self.focus = Wrap(self.focus - 1, 3) end
    elseif action == "RIGHT" then
        if self.tab == 1 then self.focus = Wrap(self.focus + 1, 3) end
    elseif action == "TABPREV" then
        self.tab = Wrap(self.tab - 1, 4)
    elseif action == "TABNEXT" then
        self.tab = Wrap(self.tab + 1, 4)
    elseif action == "CHOOSE" then
        if self.tab == 1 then
            local name = PRESET_NAMES[self.focus]
            ns.Print("Picked |cffffd100" .. name .. "|r  (test only: presets come next)")
            ns.Log("chose", name)
            self:Close("chose " .. name)
            return
        end
        ns.Log("A pressed on", TAB_NAMES[self.tab], "tab (nothing there yet)")
    elseif action == "CLOSE" then
        self:Close("B button")
        return
    end
    self:Refresh()
end

-- ---------------------------------------------------------------
-- Setup: called once from Core.lua after login.
-- ---------------------------------------------------------------
function Menu:Setup()
    self:SetSize(560, 300)
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:SetFrameStrata("DIALOG")
    self:EnableMouse(true)

    local background = self:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.10, 0.07, 0.04, 0.94)
    self.border = CreateBorder(self)

    local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", self, "TOP", 0, -16)
    title:SetText("Cozy Menu  |cff888888(controller test)|r")
    title:SetTextColor(1, 0.84, 0.44)

    self.tabs = {}
    for i, name in ipairs(TAB_NAMES) do
        local tab = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab:SetPoint("TOP", self, "TOP", (i - 2.5) * 110, -50)
        tab:SetText(name)
        self.tabs[i] = tab
    end

    self.boxes = {}
    for i, name in ipairs(PRESET_NAMES) do
        local box = CreateFrame("Frame", nil, self)
        box:SetSize(150, 110)
        box:SetPoint("CENTER", self, "CENTER", (i - 2) * 170, -6)
        box.background = box:CreateTexture(nil, "BACKGROUND")
        box.background:SetAllPoints()
        box.border = CreateBorder(box)
        local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("CENTER")
        label:SetText(name)
        label:SetTextColor(1, 0.84, 0.44)
        self.boxes[i] = box
    end

    self.comingLater = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.comingLater:SetPoint("CENTER")
    self.comingLater:SetTextColor(1, 0.84, 0.44)

    local hint = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", self, "BOTTOM", 0, 18)
    hint:SetText("D-pad: move     A: choose     B: close     LB / RB: tabs")
    hint:SetTextColor(0.72, 0.66, 0.53)

    self:SetScript("OnHide", function(self)
        -- Every way of closing must give the game's navigation buttons back.
        ReleaseNavButtons()
        ns.Log("closed:", self.closeReason or "Escape key or other")
        self.closeReason = nil
    end)
    self:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- This fires just BEFORE combat lockdown, so release is still allowed.
            if self:IsShown() then
                self:Close("combat started")
                ns.Print("Combat! Menu tucked away.")
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if needsOpenerBind then BindOpener() end
            if needsRelease then
                ReleaseNavButtons()
                ns.Log("buttons released after combat")
            end
        end
    end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:Refresh()
    BindOpener()
    ns.Log("menu ready")
end
