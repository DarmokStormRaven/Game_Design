-- ===============================================================
-- Menu.lua — a cozy controller menu built from wood, parchment, and gold.
--
-- Open with the "Toggle Cozy Menu" key binding (set it in ConsolePort's
-- binding screen) or /cozy menu. While open, the D-pad / A / B / LB / RB
-- drive the menu; ConsolePort is told to leave this menu alone.
-- Closing gives the game's buttons back. Combat keeps the menu shut.
-- A saved diary helps us check what happened after a /reload.
-- ===============================================================

local _, ns = ...

local NAV_KEYS = {
    PADDLEFT = "LEFT", PADDRIGHT = "RIGHT", PAD1 = "CHOOSE", PAD2 = "CLOSE",
    PADLSHOULDER = "TABPREV", PADRSHOULDER = "TABNEXT",
}
local MEDIA = "Interface\\AddOns\\CozyCouchMode\\Media\\"
local DISPLAY_FONT = MEDIA .. "Fonts\\MelonHoney.ttf"
local LABEL_FONT = "Fonts\\FRIZQT__.TTF"

-- Card labels share the same source as the actual controller layouts.
local PRESETS = {
    { name = "Vibe Farming", tag = "Herbs, ore and slow sunsets.", icon = "icon_gather",
      map = ns.Vibes[1].labels },
    { name = "Questing", tag = "Chat with folks, follow the trail.", icon = "icon_book",
      map = ns.Vibes[2].labels },
    { name = "Combat", tag = "For when the tavern gets rowdy.", icon = "icon_sword",
      map = ns.Vibes[3].labels },
}
local HEADINGS = { "How are we playing tonight?", "Make it yours", "Pick a vibe", "Little comforts" }
local SOON = {
    [2] = { icon = "icon_move", title = "Your Layout", text = "Move and resize your buttons, right from the couch." },
    [3] = { icon = "icon_gem", title = "Look & Feel", text = "Themes, glow, and how gently things fade in and out." },
    [4] = { icon = "icon_gear", title = "Settings", text = "Choose the menu button, sounds, and other small comforts." },
}
local PAD_COLORS = {
    A = { 0.49, 0.88, 0.56 }, B = { 0.95, 0.48, 0.43 },
    X = { 0.47, 0.68, 0.96 }, Y = { 0.95, 0.83, 0.38 },
}
local TAB_NAMES = { "Presets", "Layout", "Look", "Settings" }

local Menu = CreateFrame("Frame", "CozyCouchMenu", UIParent)
Menu:Hide()  -- Hide before installing OnHide so loading isn't logged as closing.
ns.Menu = Menu
tinsert(UISpecialFrames, "CozyCouchMenu")

Menu.focus = 1
Menu.tab = 1
local needsRelease = false
local loggedDefaults = false

local navOwner = CreateFrame("Frame")

local nav = CreateFrame("Button", "CozyCouchMenuNav")
nav:RegisterForClicks("AnyDown")
nav:SetScript("OnClick", function(self, action, down)
    if down == false then return end
    -- Each override sends our action word as the click's button name.
    Menu:Nav(action)
end)

-- ---------------------------------------------------------------
-- Drawing helpers keep corners sharp and text readable without custom fonts.
-- ---------------------------------------------------------------
local function Wrap(i, n) return (i - 1) % n + 1 end

local function NineSlice(parent, file, edge, cutX, cutY, withCenter, layer, sublevel)
    local pieces = {}
    local function Piece(name, left, right, top, bottom)
        local texture = parent:CreateTexture(nil, layer, nil, sublevel or 0)
        texture:SetTexture(file)
        texture:SetTexCoord(left, right, top, bottom)
        texture.coords = { left, right, top, bottom }  -- kept so a file swap can restore the crop
        pieces[name] = texture
        return texture
    end
    local corners = {
        { "TOPLEFT", 0, cutX, 0, cutY },
        { "TOPRIGHT", 1 - cutX, 1, 0, cutY },
        { "BOTTOMLEFT", 0, cutX, 1 - cutY, 1 },
        { "BOTTOMRIGHT", 1 - cutX, 1, 1 - cutY, 1 },
    }
    for _, corner in ipairs(corners) do
        local texture = Piece(corner[1], corner[2], corner[3], corner[4], corner[5])
        texture:SetSize(edge, edge)
        texture:SetPoint(corner[1], parent, corner[1], 0, 0)
    end
    local top = Piece("TOP", cutX, 1 - cutX, 0, cutY)
    top:SetHeight(edge)
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", edge, 0)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -edge, 0)
    local bottom = Piece("BOTTOM", cutX, 1 - cutX, 1 - cutY, 1)
    bottom:SetHeight(edge)
    bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", edge, 0)
    bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -edge, 0)
    local left = Piece("LEFT", 0, cutX, cutY, 1 - cutY)
    left:SetWidth(edge)
    left:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -edge)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, edge)
    local right = Piece("RIGHT", 1 - cutX, 1, cutY, 1 - cutY)
    right:SetWidth(edge)
    right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -edge)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, edge)
    if withCenter then
        local center = Piece("CENTER", cutX, 1 - cutX, cutY, 1 - cutY)
        center:SetPoint("TOPLEFT", parent, "TOPLEFT", edge, -edge)
        center:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -edge, edge)
    end
    return pieces
end

local function SetNineSliceFile(pieces, file)
    for _, texture in pairs(pieces) do
        texture:SetTexture(file)
        texture:SetTexCoord(unpack(texture.coords))  -- re-apply in case SetTexture reset it
    end
end

local function Text(parent, file, size, r, g, b, flags)
    -- The template stays available if the custom font is missing.
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(file, size, flags or "")
    fs:SetTextColor(r, g, b)
    return fs
end

local function Picture(parent, file, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    texture:SetTexture(file)
    texture:SetAllPoints(parent)
    return texture
end

local function Gem(parent, letter, r, g, b)
    local gem = CreateFrame("Frame", nil, parent)
    gem:SetSize(28, 28)
    Picture(gem, MEDIA .. "gem.tga")
    local label = Text(gem, LABEL_FONT, 12, r, g, b)
    label:SetPoint("CENTER")
    label:SetText(letter)
    label:SetShadowColor(0, 0, 0, 1)
    label:SetShadowOffset(1, -1)
    return gem
end

local function Medallion(parent, size, iconFile, iconSize)
    local medal = CreateFrame("Frame", nil, parent)
    medal:SetSize(size, size)
    Picture(medal, MEDIA .. "socket.tga")
    local ring = medal:CreateTexture(nil, "ARTWORK")
    ring:SetTexture(MEDIA .. "ring.tga")
    ring:SetSize(size + 10, size + 10)
    ring:SetPoint("CENTER")
    medal.icon = medal:CreateTexture(nil, "ARTWORK", nil, 1)
    medal.icon:SetTexture(iconFile)
    medal.icon:SetSize(iconSize, iconSize)
    medal.icon:SetPoint("CENTER")
    return medal
end

local function AlphaAnimation(group, from, to, duration, smoothing)
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(from)
    alpha:SetToAlpha(to)
    alpha:SetDuration(duration)
    alpha:SetSmoothing(smoothing or "NONE")
end

local function ScaleAnimation(group, from, duration)
    local scale = group:CreateAnimation("Scale")
    scale:SetScaleFrom(from, from)
    scale:SetScaleTo(1, 1)
    scale:SetDuration(duration)
    scale:SetSmoothing("OUT")
end

-- ---------------------------------------------------------------
-- Builders: each part has its own frame so the layers stay predictable.
-- ---------------------------------------------------------------
local function BuildSign(self)
    local sign = CreateFrame("Frame", nil, self)
    sign:SetFrameLevel(self:GetFrameLevel() + 6)
    sign:SetSize(620, 130)
    sign:SetPoint("TOP", self, "TOP", 0, 0)
    Picture(sign, MEDIA .. "sign.tga")
    for i, word in ipairs({ "Cozy", "Couch" }) do
        local label = Text(sign, DISPLAY_FONT, 46, 0.95, 0.71, 0.27)
        label:SetText(word)
        label:SetPoint("CENTER", sign, "CENTER", (i == 1 and -158 or 158), -4)
        label:SetShadowColor(0.42, 0.24, 0.07, 1)
        label:SetShadowOffset(0, -2)
    end
    local medal = CreateFrame("Frame", nil, sign)
    medal:SetSize(112, 112)
    medal:SetPoint("CENTER", sign, "CENTER", 0, 3)
    Picture(medal, MEDIA .. "sign_socket.tga")
    local ring = medal:CreateTexture(nil, "ARTWORK")
    ring:SetTexture(MEDIA .. "ring.tga")
    ring:SetSize(124, 124)
    ring:SetPoint("CENTER")
    local icon = medal:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetTexture(MEDIA .. "glyph_controller.tga")
    icon:SetSize(80, 80)
    icon:SetPoint("CENTER")
end

local function BuildPanel(self)
    local panel = CreateFrame("Frame", nil, self)
    panel:SetFrameLevel(self:GetFrameLevel() + 1)
    panel:SetSize(920, 540)
    panel:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -82)
    local board = panel:CreateTexture(nil, "BACKGROUND")
    board:SetTexture(MEDIA .. "board.tga")
    board:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -14)
    board:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 14)
    board:SetTexCoord(0, 1, 0, 0.566)
    local shade = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    shade:SetColorTexture(0.055, 0.031, 0.012, 0.44)
    shade:SetAllPoints(board)
    NineSlice(panel, MEDIA .. "frame.tga", 22, 30 / 346, 30 / 346, false, "ARTWORK")
    -- Parent to the panel so its wood cannot cover the heading.
    self.heading = Text(panel, DISPLAY_FONT, 31, 0.94, 0.72, 0.24)
    self.heading:SetPoint("TOP", self, "TOP", 0, -189)
    self.heading:SetShadowColor(0.29, 0.16, 0.05, 1)
    self.heading:SetShadowOffset(0, -2)
end

local function BuildTabs(self)
    self.tabs = {}
    for i, name in ipairs(TAB_NAMES) do
        local tab = CreateFrame("Frame", nil, self)
        tab:SetFrameLevel(self:GetFrameLevel() + 3)
        tab:SetSize(132, 40)
        tab:SetPoint("TOP", self, "TOP", (i - 2.5) * 142, -142)
        tab.pieces = NineSlice(tab, MEDIA .. "tab_off.tga", 10, 26 / 512, 26 / 256, true, "BACKGROUND")
        tab.label = Text(tab, LABEL_FONT, 12, 0.72, 0.66, 0.53)
        tab.label:SetPoint("CENTER")
        tab.label:SetText(string.upper(name))
        self.tabs[i] = tab
    end
    for i, name in ipairs({ "LB", "RB" }) do
        local pill = CreateFrame("Frame", nil, self)
        pill:SetFrameLevel(self:GetFrameLevel() + 3)
        pill:SetSize(36, 24)
        pill:SetPoint("TOP", self, "TOP", (i == 1 and -307 or 307), -150)
        local background = pill:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.10, 0.07, 0.04, 1)
        for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local border = pill:CreateTexture(nil, "BORDER")
            border:SetColorTexture(0.42, 0.31, 0.18, 1)
            if edge == "TOP" or edge == "BOTTOM" then
                border:SetHeight(1)
                border:SetPoint(edge .. "LEFT", pill, edge .. "LEFT", 0, 0)
                border:SetPoint(edge .. "RIGHT", pill, edge .. "RIGHT", 0, 0)
            else
                border:SetWidth(1)
                border:SetPoint("TOP" .. edge, pill, "TOP" .. edge, 0, 0)
                border:SetPoint("BOTTOM" .. edge, pill, "BOTTOM" .. edge, 0, 0)
            end
        end
        local label = Text(pill, LABEL_FONT, 10, 0.72, 0.66, 0.53)
        label:SetPoint("CENTER")
        label:SetText(name)
    end
end

local function BuildCards(self)
    self.boxes = {}
    for i, preset in ipairs(PRESETS) do
        local card = CreateFrame("Frame", nil, self)
        card:SetFrameLevel(self:GetFrameLevel() + 3)
        card:SetSize(250, 232)
        card:SetPoint("TOP", self, "TOP", (i - 2) * 284, -288)
        card.glow = card:CreateTexture(nil, "BACKGROUND", nil, -8)
        card.glow:SetTexture(MEDIA .. "parchment_glow.tga")
        card.glow:SetSize(320, 297)
        card.glow:SetPoint("CENTER")
        card.breathe = card.glow:CreateAnimationGroup()
        card.breathe:SetLooping("BOUNCE")
        AlphaAnimation(card.breathe, 0.55, 1, 1.2, "IN_OUT")
        card:SetScript("OnShow", function()
            if card.glow:IsShown() then card.breathe:Play() end
        end)
        card:SetScript("OnHide", function() card.breathe:Stop() end)
        card.parchment = Picture(card, MEDIA .. "parchment.tga")
        local medal = Medallion(card, 88, MEDIA .. preset.icon .. ".tga", 58)
        medal:SetFrameLevel(card:GetFrameLevel() + 2)
        medal:SetPoint("CENTER", card, "TOP", 0, 0)
        local title = Text(card, DISPLAY_FONT, 28, 0.23, 0.14, 0.06)
        title:SetPoint("TOP", card, "TOP", 0, -52)
        title:SetText(preset.name)
        local tag = Text(card, LABEL_FONT, 12, 0.36, 0.26, 0.16)
        tag:SetPoint("TOP", card, "TOP", 0, -86)
        tag:SetWidth(225)
        tag:SetJustifyH("CENTER")
        tag:SetText(preset.tag)
        local divider = card:CreateTexture(nil, "ARTWORK")
        divider:SetColorTexture(0.36, 0.23, 0.10, 0.6)
        divider:SetSize(176, 2)
        divider:SetPoint("TOP", card, "TOP", 0, -114)
        -- A small gold stud in the middle of the line (a solid color can't be turned into a diamond).
        local stud = card:CreateTexture(nil, "ARTWORK", nil, 1)
        stud:SetTexture(MEDIA .. "gem.tga")
        stud:SetSize(11, 11)
        stud:SetPoint("CENTER", divider, "CENTER")
        for j, letter in ipairs({ "A", "B", "X", "Y" }) do
            local color = PAD_COLORS[letter]
            local gem = Gem(card, letter, color[1], color[2], color[3])
            gem:SetPoint("TOPLEFT", card, "TOPLEFT", (j % 2 == 1 and 26 or 128), (j <= 2 and -126 or -158))
            local label = Text(card, LABEL_FONT, 13, 0.23, 0.14, 0.06)
            label:SetPoint("LEFT", gem, "RIGHT", 4, 0)
            label:SetText(preset.map[letter])
        end
        card.ribbon = CreateFrame("Frame", nil, card)
        card.ribbon:SetSize(172, 37)
        card.ribbon:SetPoint("TOP", card, "BOTTOM", 0, 16)
        Picture(card.ribbon, MEDIA .. "ribbon.tga")
        local label = Text(card.ribbon, LABEL_FONT, 11, 0.23, 0.14, 0.06)
        label:SetPoint("CENTER", card.ribbon, "CENTER", 0, 3)
        label:SetText("IN USE")
        card.pop = card.ribbon:CreateAnimationGroup()
        ScaleAnimation(card.pop, 0.7, 0.25)
        card.ribbon:Hide()
        self.boxes[i] = card
    end
end

local function BuildSoon(self)
    local card = CreateFrame("Frame", nil, self)
    card:SetFrameLevel(self:GetFrameLevel() + 3)
    card:SetSize(520, 220)
    card:SetPoint("TOP", self, "TOP", 0, -272)
    Picture(card, MEDIA .. "parchment.tga")
    card.medal = Medallion(card, 88, MEDIA .. "icon_move.tga", 54)
    card.medal:SetPoint("CENTER", card, "TOP", 0, 0)
    card.title = Text(card, DISPLAY_FONT, 30, 0.23, 0.14, 0.06)
    card.title:SetPoint("TOP", card, "TOP", 0, -58)
    card.text = Text(card, LABEL_FONT, 14, 0.36, 0.26, 0.16)
    card.text:SetPoint("TOP", card, "TOP", 0, -100)
    card.text:SetWidth(440)
    card.text:SetJustifyH("CENTER")
    local pill = card:CreateTexture(nil, "ARTWORK")
    pill:SetColorTexture(0.36, 0.23, 0.10, 0.16)
    pill:SetSize(230, 22)
    pill:SetPoint("TOP", card, "TOP", 0, -150)
    local label = Text(card, LABEL_FONT, 10, 0.23, 0.14, 0.06)
    label:SetPoint("CENTER", pill, "CENTER")
    label:SetText("COMING IN A LATER STEP")
    self.comingLater = card
end

local function BuildHints(self)
    for i, name in ipairs({ "MOVE", "CHOOSE", "CLOSE", "TABS" }) do
        local chip = CreateFrame("Frame", nil, self)
        chip:SetFrameLevel(self:GetFrameLevel() + 3)
        chip:SetSize(130, 52)
        chip:SetPoint("TOP", self, "TOP", (i - 2.5) * 146, -548)
        Picture(chip, MEDIA .. "chip.tga")
        if i == 1 then
            local glyph = chip:CreateTexture(nil, "ARTWORK")
            glyph:SetTexture(MEDIA .. "glyph_dpad.tga")
            glyph:SetSize(24, 24)
            glyph:SetPoint("CENTER", chip, "LEFT", 26, 0)
        elseif i == 2 or i == 3 then
            local letter = i == 2 and "A" or "B"
            local color = PAD_COLORS[letter]
            local gem = Gem(chip, letter, color[1], color[2], color[3])
            gem:SetPoint("CENTER", chip, "LEFT", 26, 0)
        else
            local shoulders = Text(chip, LABEL_FONT, 9, 1, 0.84, 0.44)
            shoulders:SetText("LB RB")
            shoulders:SetPoint("CENTER", chip, "LEFT", 26, 0)
        end
        local label = Text(chip, LABEL_FONT, 11, 0.96, 0.91, 0.78)
        label:SetPoint("CENTER", chip, "CENTER", 21, 0)
        label:SetText(name)
    end
    local brand = Text(self, DISPLAY_FONT, 19, 0.79, 0.65, 0.42)
    brand:SetAlpha(0.85)
    brand:SetPoint("TOP", self, "TOP", 0, -634)
    brand:SetText("from the Tavern under the Stairs")
end

local function BuildToast()
    local toast = CreateFrame("Frame", "CozyCouchToast", UIParent)
    toast:SetSize(380, 76)
    toast:SetPoint("TOP", UIParent, "TOP", 0, -40)
    toast:SetFrameStrata("FULLSCREEN_DIALOG")
    toast:Hide()
    Picture(toast, MEDIA .. "toast.tga")
    local label = Text(toast, LABEL_FONT, 14, 0.23, 0.14, 0.06)
    label:SetPoint("CENTER", toast, "CENTER", 0, 2)
    label:SetWidth(320)
    label:SetJustifyH("CENTER")
    local fadeIn = toast:CreateAnimationGroup()
    AlphaAnimation(fadeIn, 0, 1, 0.25)
    fadeIn:SetToFinalAlpha(true)
    local fadeOut = toast:CreateAnimationGroup()
    AlphaAnimation(fadeOut, 1, 0, 0.3)
    fadeOut:SetToFinalAlpha(true)
    local counter = 0
    local fadingCounter = 0
    fadeOut:SetScript("OnFinished", function()
        if fadingCounter == counter then toast:Hide() end
    end)
    function ns.Toast(msg)
        counter = counter + 1
        local current = counter
        -- Old timers and fades must not hide a newer message.
        fadeIn:Stop()
        fadeOut:Stop()
        label:SetText(msg)
        toast:SetAlpha(0)
        toast:Show()
        fadeIn:Play()
        C_Timer.After(2.6, function()
            if current ~= counter then return end
            fadingCounter = current
            fadeOut:Play()
        end)
    end
end

-- ---------------------------------------------------------------
-- Refresh only changes the presentation of the current selection.
-- ---------------------------------------------------------------
function Menu:Refresh()
    for i, tab in ipairs(self.tabs) do
        if i == self.tab then
            SetNineSliceFile(tab.pieces, MEDIA .. "tab_on.tga")
            tab.label:SetTextColor(1, 0.84, 0.44)
        else
            SetNineSliceFile(tab.pieces, MEDIA .. "tab_off.tga")
            tab.label:SetTextColor(0.72, 0.66, 0.53)
        end
    end
    self.heading:SetText(HEADINGS[self.tab])
    for i, card in ipairs(self.boxes) do
        local focused = i == self.focus
        card:SetShown(self.tab == 1)
        card:ClearAllPoints()
        card:SetPoint("TOP", self, "TOP", (i - 2) * 284, focused and -280 or -288)
        card.glow:SetShown(focused and self.tab == 1)
        if focused and self.tab == 1 and card:IsVisible() then
            if not card.breathe:IsPlaying() then card.breathe:Play() end
        else
            card.breathe:Stop()
        end
        if focused then
            card.parchment:SetVertexColor(1, 1, 1)
            card:SetAlpha(1)
        else
            card.parchment:SetVertexColor(0.74, 0.74, 0.74)
            card:SetAlpha(0.9)
        end
        local active = i == ns.db.activePreset
        local newlyActive = active and not card.ribbon:IsShown()
        card.ribbon:SetShown(active)
        if newlyActive and self.busy then card.pop:Play() end
    end
    local soon = SOON[self.tab]
    self.comingLater:SetShown(self.tab ~= 1)
    if soon then
        self.comingLater.medal.icon:SetTexture(MEDIA .. soon.icon .. ".tga")
        self.comingLater.title:SetText(soon.title)
        self.comingLater.text:SetText(soon.text)
    end
end

-- ---------------------------------------------------------------
-- Temporary overrides leave the player's saved bindings alone.
--
-- An "override binding" says: "when this button is pressed, click our
-- hidden button instead of doing its normal job". It lasts until we
-- clear it (or until /reload), and your real keybinds are never changed.
-- WoW only allows adding or clearing them OUT of combat.
-- ---------------------------------------------------------------
-- ConsolePort has its own on-screen cursor for menus. Ours navigates itself,
-- so while it is open we ask ConsolePort's cursor to step aside.
local function ObstructConsolePortCursor(state)
    if ConsolePort and ConsolePort.SetCursorObstructor then
        ConsolePort:SetCursorObstructor(Menu, state)
    end
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
        SetOverrideBindingClick(navOwner, true, "SHIFT-" .. key, "CozyCouchMenuNav", action)
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
        ns.Toast("The Cozy Menu opens after combat.")
        ns.Log("open blocked (combat) via", source)
        return
    end
    self.busy = false
    self.focus = ns.db.activePreset or 1
    self.tab = 1
    self:Refresh()
    ObstructConsolePortCursor(true)
    TakeNavButtons()
    self:Show()
    self.dim:Show()
    self.openAnimation:Play()
    ns.Log("opened via", source)
end

function Menu:Close(reason)
    if not self:IsShown() then return end
    self.openAnimation:Stop()
    self.dim:Hide()
    self.closeReason = reason
    self:Hide()
    -- OnHide only fires if the menu was actually visible (not if the whole
    -- UI was hidden with Alt+Z), so release here too. Releasing twice is harmless.
    ReleaseNavButtons()
    ObstructConsolePortCursor(false)
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
    if self.busy then return end
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
            local name = PRESETS[self.focus].name
            ns.db.activePreset = self.focus
            ns.Binder:Apply("vibe change")
            ns.HUD:OnVibeChanged()
            self.busy = true
            self:Refresh()
            ns.Toast(name .. " is on. Enjoy.")
            ns.Log("chose", name)
            C_Timer.After(0.35, function()
                -- Skip if the menu was already closed (or closed and reopened) meanwhile.
                if not self.busy then return end
                self.busy = false
                self:Close("chose " .. name)
            end)
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
    self:SetSize(920, 660)
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:SetFrameStrata("DIALOG")
    self:EnableMouse(true)

    self.dim = CreateFrame("Frame", "CozyCouchMenuDim", UIParent)
    self.dim:SetAllPoints(UIParent)
    self.dim:SetFrameStrata("DIALOG")
    self.dim:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
    self.dim:EnableMouse(false)
    local shade = self.dim:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0.03, 0.02, 0.01, 0.6)
    self.dim:Hide()

    BuildSign(self)
    BuildPanel(self)
    BuildTabs(self)
    BuildCards(self)
    BuildSoon(self)
    BuildHints(self)
    BuildToast()
    self.openAnimation = self:CreateAnimationGroup()
    AlphaAnimation(self.openAnimation, 0, 1, 0.26, "OUT")
    ScaleAnimation(self.openAnimation, 0.96, 0.32)
    self.openAnimation:SetToFinalAlpha(true)

    self:SetScript("OnHide", function(self)
        self.dim:Hide()
        -- Every way of closing must give the game's navigation buttons back.
        ReleaseNavButtons()
        ObstructConsolePortCursor(false)
        ns.Log("closed:", self.closeReason or "Escape key or other")
        self.closeReason = nil
        -- If the whole UI was hidden (Alt+Z, a cutscene), close for real so the
        -- menu can't come back later without its buttons.
        if self:IsShown() then self:Hide() end
    end)
    self:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self.busy = false
            -- This fires just BEFORE combat lockdown, so release is still allowed.
            if self:IsShown() then
                self:Close("combat started")
                ns.Toast("Combat! Menu tucked away.")
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if needsRelease then
                ReleaseNavButtons()
                ns.Log("buttons released after combat")
            end
        end
    end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:Refresh()
    -- ConsolePort automatically "adopts" menus that close with Escape (UISpecialFrames).
    -- Opt this one out: it does its own controller navigation.
    if ConsolePort and ConsolePort.RemoveInterfaceCursorFrame then
        ConsolePort:RemoveInterfaceCursorFrame(self)
    end
    ns.Log("menu ready; Toggle Cozy Menu is on:", GetBindingKey("COZYCOUCH_TOGGLEMENU") or "nothing yet")
end
