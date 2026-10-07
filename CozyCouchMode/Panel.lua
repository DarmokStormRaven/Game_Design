-- ===============================================================
-- Panel.lua — the minimalist on-screen controller panel.
--
-- Right now it shows the 4 face buttons (A B X Y) as soft glowing
-- circles in a diamond shape. The whole panel fades in when you pick up
-- the controller, and each circle "pops" when you press its button.
--
-- Key idea: a "Frame" is a rectangle on screen that can hold
-- "Textures" (images/colors) and "FontStrings" (text). Frames can also
-- have "AnimationGroups" — WoW's built-in, smooth, cheap animations.
-- ===============================================================

local _, ns = ...

-- The main panel frame. UIParent = the whole game screen.
local Panel = CreateFrame("Frame", "CozyCouchPanel", UIParent)
ns.Panel = Panel

-- WoW's names for controller buttons -> where to draw them and what color.
-- PAD1..PAD4 are the face buttons (A/B/X/Y on Xbox, Cross/Circle/Square/Triangle on PlayStation).
local FACE_BUTTONS = {
    { key = "PAD1", label = "A", x =   0, y = -34, color = { 0.45, 0.85, 0.55 } },  -- bottom, green
    { key = "PAD2", label = "B", x =  34, y =   0, color = { 0.95, 0.45, 0.45 } },  -- right, red
    { key = "PAD3", label = "X", x = -34, y =   0, color = { 0.45, 0.65, 0.95 } },  -- left, blue
    { key = "PAD4", label = "Y", x =   0, y =  34, color = { 0.95, 0.85, 0.40 } },  -- top, yellow
}

local ORB_SIZE = 30
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"  -- a built-in round cutout

-- Lookup table so a button press can find its orb quickly: orbs["PAD1"] -> orb frame
local orbs = {}

-- ---------------------------------------------------------------
-- Build one round "orb" for a face button.
-- ---------------------------------------------------------------
local function CreateOrb(info)
    local orb = CreateFrame("Frame", nil, Panel)
    orb:SetSize(ORB_SIZE, ORB_SIZE)
    orb:SetPoint("CENTER", Panel, "CENTER", info.x, info.y)

    -- The mask turns square textures into circles.
    local mask = orb:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    -- Dark, see-through base circle.
    local bg = orb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.08, 0.55)
    bg:AddMaskTexture(mask)

    -- Colored glow that lights up on press (starts faint).
    local glow = orb:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints()
    glow:SetColorTexture(info.color[1], info.color[2], info.color[3], 1)
    glow:SetAlpha(0.18)
    glow:AddMaskTexture(mask)
    orb.glow = glow

    -- The letter in the middle.
    local text = orb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(info.label)

    -- "Pop" animation: grow a little, then settle back. Order 1 plays, then order 2.
    local pop = orb:CreateAnimationGroup()
    local grow = pop:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(1.2, 1.2)
    grow:SetDuration(0.08)
    grow:SetSmoothing("OUT")      -- starts fast, eases to a stop = feels snappy
    grow:SetOrder(1)
    local shrink = pop:CreateAnimation("Scale")
    shrink:SetScaleFrom(1.2, 1.2)
    shrink:SetScaleTo(1, 1)
    shrink:SetDuration(0.18)
    shrink:SetSmoothing("IN_OUT")
    shrink:SetOrder(2)
    orb.pop = pop

    orbs[info.key] = orb
end

-- ---------------------------------------------------------------
-- Press / release feedback
-- ---------------------------------------------------------------
local function OnButtonDown(button)
    ns.SetMode("gamepad")               -- any controller press = gamepad mode
    ns.NoteButton(button)
    if ns.HUD then ns.HUD:Press(button) end
    if ns.Menu and ns.Menu:IsShown() and ns.Menu.OnPadButton then ns.Menu:OnPadButton(button) end
    local orb = orbs[button]
    if not orb then return end          -- a button we don't draw (yet)
    orb.glow:SetAlpha(0.9)
    orb.pop:Stop()                      -- restart cleanly if pressed rapidly
    orb.pop:Play()
end

local function OnButtonUp(button)
    local orb = orbs[button]
    if orb then orb.glow:SetAlpha(0.18) end
end

-- ---------------------------------------------------------------
-- The "listener": an invisible frame that hears controller presses.
--
-- IMPORTANT SAFETY DETAIL: a frame that listens for controller input
-- normally *swallows* it, so your character wouldn't jump when you press A!
-- SetPropagateKeyboardInput(true) means "listen, but pass it along to the
-- game too". WoW only allows changing that setting OUT of combat, so if
-- you /reload mid-fight, we wait until combat ends before turning it on.
-- ---------------------------------------------------------------
local listener = CreateFrame("Frame", nil, UIParent)
listener:SetSize(1, 1)   -- invisible (no textures) and doesn't block the mouse

local function StartListening()
    listener:SetPropagateKeyboardInput(true)   -- must happen FIRST (see above)
    listener:EnableGamePadButton(true)
    listener:SetScript("OnGamePadButtonDown", function(_, button) OnButtonDown(button) end)
    listener:SetScript("OnGamePadButtonUp",   function(_, button) OnButtonUp(button) end)
    ns.Debug("listening for controller presses")
end

listener:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then    -- "regen enabled" = combat just ended
        self:UnregisterEvent(event)
        StartListening()
    end
end)

-- ---------------------------------------------------------------
-- Panel fade in / fade out
-- ---------------------------------------------------------------
local function BuildFadeAnimations()
    -- Fade in: from invisible + slightly small to fully visible + normal size.
    Panel.fadeIn = Panel:CreateAnimationGroup()
    local alphaIn = Panel.fadeIn:CreateAnimation("Alpha")
    alphaIn:SetFromAlpha(0)
    alphaIn:SetToAlpha(1)
    alphaIn:SetDuration(0.25)
    alphaIn:SetSmoothing("OUT")
    Panel.fadeIn:SetToFinalAlpha(true)   -- keep the end result (fully visible)
    local scaleIn = Panel.fadeIn:CreateAnimation("Scale")
    scaleIn:SetScaleFrom(0.92, 0.92)
    scaleIn:SetScaleTo(1, 1)
    scaleIn:SetDuration(0.25)
    scaleIn:SetSmoothing("OUT")

    -- Fade out: to invisible, then actually hide when finished.
    Panel.fadeOut = Panel:CreateAnimationGroup()
    local alphaOut = Panel.fadeOut:CreateAnimation("Alpha")
    alphaOut:SetFromAlpha(1)
    alphaOut:SetToAlpha(0)
    alphaOut:SetDuration(0.2)
    alphaOut:SetSmoothing("IN")
    Panel.fadeOut:SetToFinalAlpha(true)  -- stay invisible (no flicker) until hidden
    Panel.fadeOut:SetScript("OnFinished", function() Panel:Hide() end)
end

-- Our own show/hide that animates instead of popping instantly.
function Panel:SetVisible(visible)
    if visible then
        self.fadeOut:Stop()
        if not self:IsShown() then
            self:Show()
            self.fadeIn:Play()
        end
    elseif self:IsShown() and not self.fadeOut:IsPlaying() then
        self.fadeIn:Stop()
        self.fadeOut:Play()
    end
end

-- ---------------------------------------------------------------
-- Setup: called once from Core.lua after login.
-- ---------------------------------------------------------------
function Panel:Setup()
    self:SetSize(110, 110)
    self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 140)
    self:Hide()                 -- start hidden; appears on controller use

    for _, info in ipairs(FACE_BUTTONS) do
        CreateOrb(info)
    end
    BuildFadeAnimations()

    if InCombatLockdown() then
        listener:RegisterEvent("PLAYER_REGEN_ENABLED")
        ns.Debug("in combat — will start listening after combat")
    else
        StartListening()
    end
end
