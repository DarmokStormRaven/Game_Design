-- ===============================================================
-- HUD.lua - the Hearth Bar shows what your controller does right now.
-- It only reads bindings and action slots. Blizzard still casts spells,
-- handles paging and forms, and owns all of its action buttons.
-- ===============================================================

local _, ns = ...
local HUD = CreateFrame("Frame", "CozyCouchHUD", UIParent)
ns.HUD = HUD
HUD:Hide()
local MEDIA = "Interface\\AddOns\\CozyCouchMode\\Media\\"
local LABEL = "Fonts\\FRIZQT__.TTF"
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local SOCKETS = {
    { "PAD2", "B", 732, 150 }, { "PAD3", "X", 608, 150 },
    { "PAD4", "Y", 670, 88 }, { "PAD1", "A", 670, 212 },
    { "PADDRIGHT", "right", 212, 150 }, { "PADDLEFT", "left", 88, 150 },
    { "PADDUP", "up", 150, 88 }, { "PADDDOWN", "down", 150, 212 },
    { "PADLSHOULDER", "LB", 222, 26, true }, { "PADRSHOULDER", "RB", 598, 26, true },
}
local COLORS = {
    A = { 0.49, 0.88, 0.56 }, B = { 0.95, 0.48, 0.43 },
    X = { 0.47, 0.68, 0.96 }, Y = { 0.95, 0.83, 0.38 },
}
local NATIVE = {
    JUMP = "Interface\\Icons\\Ability_Rogue_Sprint", INTERACTTARGET = "Interface\\CURSOR\\Interact",
    TOGGLEGAMEMENU = "Interface\\Icons\\INV_Misc_Gear_01", OPENALLBAGS = "Interface\\Icons\\INV_Misc_Bag_08",
    TOGGLEQUESTLOG = "Interface\\Icons\\INV_Misc_Book_09", TOGGLEWORLDMAP = "Interface\\Icons\\INV_Misc_Map_01",
    SITORSTAND = "Interface\\Icons\\Spell_Nature_Sleep", COZYCOUCH_TOGGLEMENU = MEDIA .. "glyph_controller.tga",
}
local BARS = {
    "MainMenuBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MainMenuBarArtFrame",
    "MicroButtonAndBagsBar", "StatusTrackingBarManager",
}
local sockets, byKey = {}, {}
local elapsedShift, elapsedRange, idle = 0, 0, 0

-- ---------------------------------------------------------------
-- Drawing and animation helpers operate only on our own regions.
-- ---------------------------------------------------------------
local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Shift()
    -- Strict true/false: the calm/fight logic compares it with ~=.
    return not not (type(IsShiftKeyDown) == "function" and IsShiftKeyDown())
end

local function Picture(parent, file, width, height, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    texture:SetSize(width, height)
    texture:SetPoint("CENTER")
    if file then texture:SetTexture(MEDIA .. file .. ".tga") end
    return texture
end

local function Place(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
end

local function Text(parent, text, size, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont(LABEL, size, "")
    label:SetText(text)
    label:SetTextColor(0.72, 0.66, 0.53)
    Place(label, parent, x, y)
    return label
end

local function Alpha(region, from, to, duration)
    local group = region:CreateAnimationGroup()
    local animation = group:CreateAnimation("Alpha")
    animation:SetFromAlpha(from)
    animation:SetToAlpha(to)
    animation:SetDuration(duration)
    animation:SetSmoothing("OUT")
    return group
end

-- One reusable fade per region: WoW never frees animation groups, so making
-- a new one on every press would slowly leak memory over a long session.
local function Fade(region, to, duration)
    local from = region:GetAlpha()
    if not region.fade then
        region.fade = region:CreateAnimationGroup()
        region.fade.alpha = region.fade:CreateAnimation("Alpha")
        region.fade.alpha:SetSmoothing("OUT")
        region.fade:SetToFinalAlpha(true)
    end
    region.fade:Stop()
    region:SetAlpha(from)
    region.fade.alpha:SetFromAlpha(from)
    region.fade.alpha:SetToAlpha(to)
    region.fade.alpha:SetDuration(duration)
    region.fade:Play()
end

local function Scale(region, fromX, fromY, toX, toY, duration, smoothing, delay)
    local group = region:CreateAnimationGroup()
    local animation = group:CreateAnimation("Scale")
    animation:SetScaleFrom(fromX, fromY)
    animation:SetScaleTo(toX, toY)
    animation:SetDuration(duration)
    animation:SetSmoothing(smoothing)
    animation:SetStartDelay(delay or 0)
    return group
end

local function Gradient(texture, direction, first, last)
    if type(texture.SetGradient) == "function" and type(CreateColor) == "function" then
        texture:SetGradient(direction, CreateColor(unpack(first)), CreateColor(unpack(last)))
    end
end

-- ---------------------------------------------------------------
-- Action state: secret values never participate in decisions or math.
-- ---------------------------------------------------------------
local function ClearCooldown(socket)
    if type(socket.cooldown.Clear) == "function" then socket.cooldown:Clear() end
end

local function Cooldown(socket)
    ClearCooldown(socket)
    if not socket.slot then return end
    local cd = socket.cooldown
    if C_ActionBar and type(C_ActionBar.GetActionCooldown) == "function"
        and type(C_ActionBar.GetActionCooldownDuration) == "function"
        and type(cd.SetCooldownFromDurationObject) == "function" then
        local info = C_ActionBar.GetActionCooldown(socket.slot)
        if not Secret(info) and info and not Secret(info.isActive) and info.isActive then
            local duration = C_ActionBar.GetActionCooldownDuration(socket.slot)
            if not Secret(duration) and duration then cd:SetCooldownFromDurationObject(duration) end
        end
    elseif type(GetActionCooldown) == "function" and type(cd.SetCooldown) == "function" then
        local start, duration = GetActionCooldown(socket.slot)
        if not Secret(start) and not Secret(duration) and type(start) == "number" and type(duration) == "number" then
            pcall(cd.SetCooldown, cd, start, duration)
        end
    end
end

local function Usable(socket)
    local usable, range
    if socket.slot then
        if type(IsUsableAction) == "function" then usable = IsUsableAction(socket.slot) end
        if type(IsActionInRange) == "function" then range = IsActionInRange(socket.slot) end
    end
    local unavailable = not Secret(usable) and usable == false
    socket.icon:SetDesaturated(unavailable)
    if not Secret(range) and range == false then
        socket.icon:SetVertexColor(1, 0.45, 0.4)
    elseif unavailable then
        socket.icon:SetVertexColor(0.55, 0.55, 0.55)
    else
        socket.icon:SetVertexColor(1, 1, 1)
    end
end

local function Paint(socket)
    local action = ""
    if type(GetBindingAction) == "function" then
        action = GetBindingAction((Shift() and "SHIFT-" or "") .. socket.key)
    end
    if Secret(action) then action = "" end
    socket.slot = nil
    local texture, crop
    local number = action and action:match("^ACTIONBUTTON(%d+)$")
    if number then
        local n = tonumber(number)
        local button = _G["ActionButton" .. number]
        local slot = button and button.action
        if Secret(slot) then slot = nil end
        slot = slot or n
        socket.slot = slot
        if type(GetActionTexture) == "function" then texture = GetActionTexture(slot) end
        if Secret(texture) then texture = nil end
        crop = true
    elseif action and action ~= "" then
        texture = NATIVE[action] or "Interface\\Icons\\INV_Misc_QuestionMark"
        crop = texture:find("Interface\\Icons\\", 1, true) ~= nil
    end
    socket.empty = not texture
    socket:SetAlpha(socket.empty and 0.5 or 1)
    if texture then
        socket.icon:SetTexture(texture)
        if crop then socket.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else socket.icon:SetTexCoord(0, 1, 0, 1) end
        socket.icon:Show()
    else
        socket.icon:Hide()
    end
    Cooldown(socket)
    Usable(socket)
end

local function StopFlip(socket)
    local playing = socket.flipOut:IsPlaying() or socket.flipIn:IsPlaying() or socket.calm:IsPlaying()
    socket.flipOut:Stop()
    socket.flipIn:Stop()
    socket.calm:Stop()
    socket.icon:SetAlpha(1)
    return playing
end

local function BuildSocket(info, index)
    local small = info[5]
    local size, iconSize = small and 46 or 66, small and 32 or 48
    local socket = CreateFrame("Frame", nil, HUD)
    socket:SetSize(size, size)
    Place(socket, HUD, info[3], info[4])
    socket.key = info[1]
    Picture(socket, "sign_socket", size, size, "BACKGROUND")
    socket.icon = Picture(socket, nil, iconSize, iconSize)
    local mask = socket:CreateMaskTexture()
    mask:SetSize(iconSize, iconSize)
    mask:SetPoint("CENTER")
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    socket.icon:AddMaskTexture(mask)
    local shade = Picture(socket, "socket_shade", iconSize, iconSize, "ARTWORK", 1)
    shade:AddMaskTexture(mask)
    local cd = CreateFrame("Cooldown", nil, socket, "CooldownFrameTemplate")
    cd:SetSize(iconSize, iconSize)
    cd:SetPoint("CENTER")
    for method, args in pairs({ SetSwipeTexture = { MEDIA .. "circle_white.tga" },
        SetSwipeColor = { 0.03, 0.02, 0.01, 0.66 }, SetDrawEdge = { false }, SetHideCountdownNumbers = { true } }) do
        if type(cd[method]) == "function" then cd[method](cd, unpack(args)) end
    end
    socket.cooldown = cd
    -- Child frames draw above textures, so the rim gets its own higher frame.
    local trim = CreateFrame("Frame", nil, socket)
    trim:SetAllPoints()
    trim:SetFrameLevel(cd:GetFrameLevel() + 1)
    Picture(trim, "ring", size + 10, size + 10)
    socket.rim = Picture(trim, "ring_thin", size + 10, size + 10, "OVERLAY")
    socket.rim:SetVertexColor(1, 0.84, 0.44)
    socket.rim:SetAlpha(0)
    local gem = CreateFrame("Frame", nil, trim)
    gem:SetSize(24, 24)
    gem:SetPoint("CENTER", socket, "CENTER", size * 0.38, -size * 0.38)
    Picture(gem, "gem", 24, 24)
    local color = COLORS[info[2]]
    if color or small then
        local label = Text(gem, info[2], small and 8 or 12, 12, 12)
        label:SetTextColor(unpack(color or { 0.96, 0.91, 0.78 }))
    else
        local arrow = Picture(gem, "glyph_" .. info[2], 12, 12, "OVERLAY")
        arrow:SetVertexColor(0.96, 0.91, 0.78)
    end
    socket.flipOut = Scale(socket.icon, 1, 1, 0.01, 1, 0.09, "IN", (index - 1) * 0.015)
    socket.flipIn = Scale(socket.icon, 0.01, 1, 1, 1, 0.13, "OUT")
    socket.flipOut:SetScript("OnFinished", function() Paint(socket); socket.flipIn:Play() end)
    socket.calm = Alpha(socket.icon, 0.2, 1, 0.14)
    socket.press = Scale(socket, 0.93, 0.93, 1, 1, 0.15, "OUT")
    socket.flash = Alpha(socket.rim, 0.75, 0, 0.26)
    sockets[index], byKey[socket.key] = socket, socket
end

-- ---------------------------------------------------------------
-- The carved strip, sign, tabs, medallion and progress line.
-- ---------------------------------------------------------------
local function BuildInlay()
    -- Middle piece: vertical wood gradient. End pieces: a see-through horizontal gradient
    -- so the strip fades softly into the clusters (masks can't carry gradients).
    for _, piece in ipairs({ { 150, 90, 0, 1 }, { 240, 340, 1, 1 }, { 580, 90, 1, 0 } }) do
        local body = Picture(HUD, nil, piece[2], 28, "BACKGROUND", -6)
        Place(body, HUD, piece[1] + piece[2] / 2, 150)
        body:SetColorTexture(1, 1, 1)
        if piece[3] == piece[4] then
            Gradient(body, "VERTICAL", { 0.14, 0.09, 0.04, 1 }, { 0.23, 0.15, 0.08, 1 })
        else
            Gradient(body, "HORIZONTAL", { 0.19, 0.12, 0.06, piece[3] }, { 0.19, 0.12, 0.06, piece[4] })
        end
        for _, edge in ipairs({ { 136, 0.55 }, { 164, 0.35 } }) do
            local line = Picture(HUD, nil, piece[2], 1, "BACKGROUND", -5)
            Place(line, HUD, piece[1] + piece[2] / 2, edge[1])
            line:SetColorTexture(1, 1, 1)
            Gradient(line, "HORIZONTAL", { 0.73, 0.55, 0.31, edge[2] * piece[3] },
                { 0.73, 0.55, 0.31, edge[2] * piece[4] })
        end
    end
end

local function BuildTab(x, right)
    local tab = CreateFrame("Frame", nil, HUD)
    tab:SetSize(140, 50)
    tab:SetPoint("TOPLEFT", HUD, "TOPLEFT", x, 0)
    tab.glow = Picture(tab, "glow_round", 160, 70, "BACKGROUND")
    tab.glow:SetVertexColor(1, 0.84, 0.44)
    tab.glow:SetAlpha(0)
    local chip = Picture(tab, "chip", 140, 50)
    if right then chip:SetTexCoord(1, 0, 0, 1) end
    local glyph = Text(tab, right and "RT" or "LT", 11, right and 115 or 25, 25)
    glyph:SetTextColor(1, 0.84, 0.44)
    tab.label = Text(tab, right and "TARGET" or "FIGHT SET", 10.5, right and 45 or 95, 25)
    local flash = Picture(tab, "glow_round", 160, 70, "OVERLAY")
    flash:SetVertexColor(1, 0.84, 0.44)
    flash:SetAlpha(0)
    tab.flash = Alpha(flash, 0.35, 0, 0.26)
    return tab
end

local function BuildCenter()
    HUD.lt, HUD.rt = BuildTab(22, false), BuildTab(658, true)
    HUD.halos = {}
    for i, color in ipairs({ { 0.84, 0.89, 1 }, { 1, 0.59, 0.24 } }) do
        local halo = Picture(HUD, "glow_round", 102, 102, "BACKGROUND")
        Place(halo, HUD, 410, 112)
        halo:SetVertexColor(unpack(color))
        halo:SetAlpha(0)
        HUD.halos[i] = halo
    end
    Place(Picture(HUD, "socket", 78, 78), HUD, 410, 112)
    Place(Picture(HUD, "ring", 88, 88, "ARTWORK", 1), HUD, 410, 112)
    HUD.medal = Picture(HUD, nil, 48, 48, "ARTWORK", 2)
    Place(HUD.medal, HUD, 410, 112)
    local sign = Picture(HUD, "sign", 240, 52, "BACKGROUND", 1)
    Place(sign, HUD, 410, 168)
    sign:SetVertexColor(0.82, 0.82, 0.82)
    HUD.name = Text(HUD, "", 20, 410, 168)
    HUD.name:SetFont(MEDIA .. "Fonts\\MelonHoney.ttf", 20, "")
    HUD.name:SetTextColor(0.95, 0.71, 0.27)
    HUD.name:SetShadowColor(0.42, 0.24, 0.07, 1)
    HUD.name:SetShadowOffset(0, -2)
    HUD.pips = {}
    for i, name in ipairs({ "CALM", "FIGHT" }) do
        local dot = Picture(HUD, "ring_thin", 12, 12)
        Place(dot, HUD, i == 1 and 333 or 429, 212)
        local label = Text(HUD, name, 12, i == 1 and 371 or 471, 212)
        HUD.pips[i] = { dot = dot, label = label }
    end
end

local function BuildXP()
    local xp = CreateFrame("Frame", nil, HUD)
    xp:SetSize(420, 5)
    xp:SetPoint("TOPLEFT", HUD, "TOPLEFT", 200, -240)
    local border = Picture(xp, nil, 422, 7, "BACKGROUND")
    border:SetColorTexture(0.73, 0.55, 0.31, 0.35)
    local track = Picture(xp, nil, 420, 5, "ARTWORK")
    track:SetColorTexture(0.08, 0.05, 0.02, 0.8)
    xp.fill = Picture(xp, nil, 420, 5, "ARTWORK", 1)
    xp.fill:ClearAllPoints()
    xp.fill:SetPoint("LEFT")
    xp.fill:SetColorTexture(1, 1, 1)
    Gradient(xp.fill, "HORIZONTAL", { 0.54, 0.35, 0.13, 1 }, { 0.94, 0.72, 0.24, 1 })
    HUD.xp = xp
end

function HUD:UpdateXP()
    self.xp:Hide()
    if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then return end
    local value, maximum = UnitXP("player"), UnitXPMax("player")
    if Secret(value) or Secret(maximum) then return end
    if type(value) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return end
    if type(UnitLevel) == "function" and type(GetMaxPlayerLevel) == "function" then
        local level, cap = UnitLevel("player"), GetMaxPlayerLevel()
        if Secret(level) or Secret(cap) then return end
        if type(level) == "number" and type(cap) == "number" and level >= cap then return end
    end
    local width = 420 * math.max(0, math.min(1, value / maximum))
    self.xp.fill:SetWidth(math.max(0.001, width))
    self.xp.fill:SetAlpha(width > 0 and 1 or 0)
    self.xp:Show()
end

function HUD:Decorate()
    local vibe = ns.Vibes[ns.db.activePreset or 1] or ns.Vibes[1]
    local fight = (vibe.top == "fight") ~= self.shift
    self.name:SetText(vibe.name)
    self.medal:SetTexture(MEDIA .. (fight and "icon_sword" or vibe.icon) .. ".tga")
    self.lt.label:SetText(vibe.top == "fight" and "CALM SET" or "FIGHT SET")
    self.lt.label:SetTextColor(unpack(self.shift and { 1, 0.84, 0.44 } or { 0.72, 0.66, 0.53 }))
    Fade(self.lt.glow, self.shift and 0.35 or 0, 0.22)
    Fade(self.halos[1], fight and 0 or 0.28, 0.22)
    Fade(self.halos[2], fight and 0.42 or 0, 0.22)
    for i, pip in ipairs(self.pips) do
        local on = (i == 2) == fight
        pip.dot:SetTexture(MEDIA .. (on and "circle_white" or "ring_thin") .. ".tga")
        pip.dot:SetVertexColor(unpack(on and { 0.94, 0.72, 0.24 } or { 0.73, 0.55, 0.31 }))
        pip.label:SetTextColor(unpack(on and { 1, 0.84, 0.44 } or { 0.72, 0.66, 0.53 }))
    end
end

-- ---------------------------------------------------------------
-- Input, motion and visibility never change protected button behavior.
-- ---------------------------------------------------------------
function HUD:Wake()
    idle = 0
    if self.idled or self:GetAlpha() < 1 then
        self.idled = false
        Fade(self, 1, 0.15)
    end
end

function HUD:CheckShift()
    local held = Shift()
    if held == self.shift then return end
    self.shift = held
    self:Wake()
    for _, socket in ipairs(sockets) do
        local interrupted = StopFlip(socket)
        if interrupted or ns.db.calmMotion then
            Paint(socket)
            if ns.db.calmMotion then socket.calm:Play() end
        else
            socket.flipOut:Play()
        end
    end
    self:Decorate()
end

function HUD:Refresh()
    -- Hidden (mouse mode): skip; SetActive(true) refreshes when the bar comes back.
    if not self.ready or not self:IsShown() then return end
    self.shift = Shift()
    for _, socket in ipairs(sockets) do StopFlip(socket); Paint(socket) end
    self:Decorate()
    self:UpdateXP()
end

function HUD:Press(button)
    if not self.ready then return end
    self:Wake()
    local tab = button == "PADLTRIGGER" and self.lt or button == "PADRTRIGGER" and self.rt
    if tab then tab.flash:Stop(); tab.flash:Play() end
    local socket = byKey[button]
    if not socket or socket.empty then return end
    socket.press:Stop()
    socket.flash:Stop()
    socket.press:Play()
    socket.flash:Play()
end

function HUD:OnVibeChanged()
    if not self.ready then return end
    self:Wake()
    self.deal:Stop()
    self.deal:Play()
end

function HUD:SetActive(isGamepad)
    if not self.ready then return end
    -- ConsolePort draws its own bars and owns the pad; stay out of its way entirely.
    if ConsolePort ~= nil then self:Hide(); return end
    if isGamepad then self:Show(); self:Refresh() else self:Hide() end
    local alpha = isGamepad and ns.db.hideKeyboardBars ~= false and 0 or 1
    for _, name in ipairs(BARS) do
        local bar = _G[name]
        if bar and type(bar.SetAlpha) == "function" then bar:SetAlpha(alpha) end
    end
end

function HUD:Setup()
    if self.ready then return end
    self:SetSize(820, 252)
    self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
    self:SetFrameStrata("MEDIUM")
    self:SetScale(ns.db.hudScale or 1)
    BuildInlay()
    for _, x in ipairs({ 150, 670 }) do
        Place(Picture(self, "base_disc", 212, 212, "BACKGROUND", -7), self, x, 150)
    end
    for i, info in ipairs(SOCKETS) do BuildSocket(info, i) end
    BuildCenter()
    BuildXP()
    self.deal = Alpha(self, 0.5, 1, 0.22)
    local move = self.deal:CreateAnimation("Translation")
    move:SetOffset(0, 6)
    move:SetDuration(0.22)
    move:SetSmoothing("OUT")
    self.deal:SetScript("OnPlay", function() self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 12) end)
    local function EndDeal()
        self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 18)
        self:Refresh()
    end
    self.deal:SetScript("OnFinished", EndDeal)
    self.deal:SetScript("OnStop", EndDeal)
    self:SetScript("OnUpdate", function(_, elapsed)
        elapsedShift, elapsedRange, idle = elapsedShift + elapsed, elapsedRange + elapsed, idle + elapsed
        if elapsedShift >= 0.05 then elapsedShift = 0; self:CheckShift() end
        if elapsedRange >= 0.2 then
            elapsedRange = 0
            for _, socket in ipairs(sockets) do Usable(socket) end
        end
        if idle >= 8 and not self.idled and not self.shift and not InCombatLockdown() then
            self.idled = true
            Fade(self, 0.45, 0.6)
        end
    end)
    self:SetScript("OnEvent", function(_, event)
        if event == "MODIFIER_STATE_CHANGED" then
            self:CheckShift()
        elseif event == "PLAYER_REGEN_DISABLED" then
            self:Wake()
        elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
            self:UpdateXP()
        elseif event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
            for _, socket in ipairs(sockets) do Cooldown(socket) end
        elseif event == "ACTIONBAR_UPDATE_USABLE" or event == "SPELL_UPDATE_USABLE" then
            for _, socket in ipairs(sockets) do Usable(socket) end
        elseif event == "PLAYER_ENTERING_WORLD" then
            self:SetActive(ns.mode == "gamepad")
        else
            self:Refresh()
        end
    end)
    for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_BINDINGS",
        "PLAYER_ENTERING_WORLD", "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_USABLE",
        "SPELL_UPDATE_USABLE", "MODIFIER_STATE_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP" }) do
        pcall(self.RegisterEvent, self, event)
    end
    self.ready = true
    self:Refresh()
    self:SetActive(ns.mode == "gamepad")
end
