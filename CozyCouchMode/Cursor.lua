-- ===============================================================
-- Cursor.lua - use the controller on Blizzard's own menu buttons.
-- We only read their frames; a secure Cozy button forwards clicks.
-- Scanning and navigation are independent Cozy code, not ConsolePortNode.
-- ===============================================================
local _, ns = ...
local Cursor = CreateFrame("Frame", "CozyCouchCursor", WorldFrame)
ns.Cursor = Cursor
local MEDIA = "Interface\\AddOns\\CozyCouchMode\\Media\\"
local nodes, windows, seen, order = {}, {}, {}, {}
local serial, poll, scanAge = 0, 0, 0
local names, sorted, present = {}, {}, {}
local namesUntil = 0
local fixedWindows = { "ContainerFrameCombinedBags", "LootFrame", "StackSplitFrame", "OpenMailFrame", "GameMenuFrame" }
local NAV = { PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PADLSHOULDER = "PREV", PADRSHOULDER = "NEXT", PAD4 = "PICK" }
local directions = { UP = { 0, 1 }, DOWN = { 0, -1 }, LEFT = { -1, 0 }, RIGHT = { 1, 0 } }

-- ---------------------------------------------------------------
-- Geometry is measured in screen pixels, never with secret values.
-- ---------------------------------------------------------------
local function Number(value)
    return not (type(issecretvalue) == "function" and issecretvalue(value)) and type(value) == "number"
end

local function Allowed(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
    local name = frame:GetName() or ""
    return name ~= "WorldMapFrame" and not name:match("^CozyCouch")
end

local function Rect(frame)
    local x, y = frame:GetCenter()
    local w, h = frame:GetSize()
    local scale = frame:GetEffectiveScale()
    if not Number(x) or not Number(y) or not Number(w) or not Number(h) or not Number(scale) then return end
    return x * scale, y * scale, w * scale, h * scale
end

local function Node(frame, root)
    if not Allowed(frame) or not frame:IsVisible() or not frame:IsMouseEnabled() then return end
    if not (frame:IsObjectType("Button") or frame:IsObjectType("CheckButton")) then return end
    if frame.IsEnabled and not frame:IsEnabled() then return end
    local x, y, w, h = Rect(frame)
    if not x or w < 6 or h < 6 then return end
    local _, _, sw, sh = Rect(UIParent)
    if not sw or x < 0 or y < 0 or x > sw or y > sh then return end
    local ancestor = frame:GetParent()
    while ancestor do
        if not Allowed(ancestor) then return end
        if ancestor:IsObjectType("ScrollFrame") or (ancestor.DoesClipChildren and ancestor:DoesClipChildren()) then
            local ax, ay, aw, ah = Rect(ancestor)
            if not ax or math.abs(x - ax) > aw / 2 or math.abs(y - ay) > ah / 2 then return end
        end
        ancestor = ancestor:GetParent()
    end
    return { frame = frame, root = root, x = x, y = y, w = w, h = h }
end

local function NewestFirst(a, b)
    return order[a] > order[b]
end

local function Watch()
    if GetTime() >= namesUntil then
        wipe(names)
        wipe(sorted)
        if UIPanelWindows then for name in pairs(UIPanelWindows) do names[name] = true end end
        if UISpecialFrames then for _, name in ipairs(UISpecialFrames) do names[name] = true end end
        for i = 1, 13 do names["ContainerFrame" .. i] = true end
        for i = 1, 4 do names["StaticPopup" .. i] = true end
        for _, name in ipairs(fixedWindows) do names[name] = true end
        for name in pairs(names) do sorted[#sorted + 1] = name end
        table.sort(sorted)
        namesUntil = GetTime() + 5
    end
    wipe(windows)
    wipe(present)
    for _, name in ipairs(sorted) do
        local frame = _G[name]
        if Allowed(frame) and frame:IsVisible() and not present[frame] then
            present[frame] = true
            if not seen[frame] then serial = serial + 1; order[frame] = serial end
            windows[#windows + 1] = frame
        end
    end
    seen, present = present, seen
    table.sort(windows, NewestFirst)
end

local function Find(frame)
    for _, node in ipairs(nodes) do if node.frame == frame then return node end end
end

local function Nearest(x, y, actions)
    local best, distance
    for _, node in ipairs(nodes) do
        if not actions or node.extra then
            local d = (node.x - x)^2 + (node.y - y)^2
            if not distance or d < distance then best, distance = node, d end
        end
    end
    return best
end

-- ---------------------------------------------------------------
-- Hover scripts on spells, talents and actions can taint the bars.
-- ---------------------------------------------------------------
local function Spell(node)
    -- Modern spellbook icons store the spell data on their item parent.
    local item = node
    for _ = 1, 2 do
        if item and Number(item.slotIndex) and Number(item.spellBank) then
            local info = item.spellBookItemInfo
            return item.slotIndex, item.spellBank, type(info) == "table" and info.spellID or nil
        end
        item = item and item:GetParent()
    end
    if type(node.GetSpellBookItemInfo) == "function" then
        local info = node:GetSpellBookItemInfo()
        if type(info) == "table" then return info.spellBookItemSlotIndex, info.spellBookItemBank, info.spellID end
    end
    if Number(node.spellBookItemSlotIndex) then return node.spellBookItemSlotIndex, node.spellBookItemBank, node.spellID end
    if (node:GetName() or ""):match("^SpellButton") and type(SpellBook_GetSpellBookSlot) == "function" then
        return SpellBook_GetSpellBookSlot(node), _G.SpellBookFrame and _G.SpellBookFrame.bookType
    end
    return nil, nil, node.spellID
end

local function SafeHover(node)
    if Number(node.action) or Number(node.spellBookItemSlotIndex) then return false end
    local name = node:GetName() or ""
    for _, prefix in ipairs({ "ActionButton", "MultiBar", "PetActionButton", "StanceButton", "SpellButton" }) do
        if name:sub(1, #prefix) == prefix then return false end
    end
    while node do
        name = node:GetName() or ""
        if name == "PlayerSpellsFrame" or name == "SpellBookFrame" or name:find("Talent") then return false end
        node = node:GetParent()
    end
    return true
end

local function Tooltip(method, ...)
    if GameTooltip and type(GameTooltip[method]) == "function" then pcall(GameTooltip[method], GameTooltip, ...) end
end

local function Leave(node)
    if node and Allowed(node.frame) and SafeHover(node.frame) then
        local script = node.frame:GetScript("OnLeave")
        if type(script) == "function" then pcall(script, node.frame) end
    end
    Tooltip("Hide")
end

local function Enter(node)
    local frame = node.frame
    if SafeHover(frame) then
        local script = frame:GetScript("OnEnter")
        if type(script) == "function" then pcall(script, frame) end
        return
    end
    Tooltip("SetOwner", frame, "ANCHOR_RIGHT")
    if Number(frame.action) then Tooltip("SetAction", frame.action)
    elseif type(frame.GetBagID) == "function" then Tooltip("SetBagItem", frame:GetBagID(), frame:GetID())
    else
        local slot, bank = Spell(frame)
        if Number(slot) and bank ~= nil then Tooltip("SetSpellBookItem", slot, bank) end
    end
end

-- ---------------------------------------------------------------
-- Gold border and a small row of hints belong entirely to Cozy.
-- ---------------------------------------------------------------
function Cursor:BuildArt()
    local border = CreateFrame("Frame", nil, UIParent)
    border:SetFrameStrata("TOOLTIP")
    border:SetFrameLevel(1000)
    border:Hide()
    self.border = border
    -- The highlight is the GM panel's own gold item-slot frame (slot_frame.tga), drawn as a
    -- 9-slice so its rounded corners stay crisp at any button size, over a soft warm glow.
    local glow = border:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "glow_round.tga")
    glow:SetPoint("TOPLEFT", border, "TOPLEFT", -14, 14)
    glow:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 14, -14)
    glow:SetVertexColor(1, 0.78, 0.35, 0.35)
    local EDGE = 14
    local coords, points = { 0, 44 / 256, 212 / 256, 1 }, { "LEFT", "", "RIGHT" }
    for row = 1, 3 do
        for col = 1, 3 do
            if row ~= 2 or col ~= 2 then
                local texture = border:CreateTexture(nil, "OVERLAY")
                texture:SetTexture(MEDIA .. "slot_frame.tga")
                texture:SetTexCoord(coords[col], coords[col + 1], coords[row], coords[row + 1])
                local vertical = row == 1 and "TOP" or row == 3 and "BOTTOM" or ""
                if row == 2 then
                    texture:SetWidth(EDGE)
                    texture:SetPoint("TOP" .. points[col], border, "TOP" .. points[col], 0, -EDGE)
                    texture:SetPoint("BOTTOM" .. points[col], border, "BOTTOM" .. points[col], 0, EDGE)
                elseif col == 2 then
                    texture:SetHeight(EDGE)
                    texture:SetPoint(vertical .. "LEFT", border, vertical .. "LEFT", EDGE, 0)
                    texture:SetPoint(vertical .. "RIGHT", border, vertical .. "RIGHT", -EDGE, 0)
                else
                    texture:SetSize(EDGE, EDGE)
                    texture:SetPoint(vertical .. points[col])
                end
            end
        end
    end
    local hints = CreateFrame("Frame", nil, UIParent)
    hints:SetSize(480, 32)
    hints:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 290)
    hints:SetFrameStrata("TOOLTIP")
    hints:SetAlpha(0)
    self.hints, self.chips = hints, {}
    for i = 1, 4 do
        local chip = CreateFrame("Frame", nil, hints)
        chip:SetSize(116, 32)
        local bg = chip:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture(MEDIA .. "chip.tga")
        local gem = chip:CreateTexture(nil, "ARTWORK")
        gem:SetSize(22, 22); gem:SetPoint("LEFT", 7, 0); gem:SetTexture(MEDIA .. "gem.tga")
        chip.key = chip:CreateFontString(nil, "OVERLAY")
        chip.key:SetPoint("CENTER", gem)
        chip.label = chip:CreateFontString(nil, "OVERLAY")
        chip.label:SetPoint("LEFT", 33, 0)
        for _, text in ipairs({ chip.key, chip.label }) do
            text:SetFont("Fonts\\FRIZQT__.TTF", 10.5, "")
            text:SetTextColor(0.96, 0.91, 0.78)
        end
        self.chips[i] = chip
    end
    self.fade = hints:CreateAnimationGroup()
    self.fade:SetToFinalAlpha(true)
    self.fadeAlpha = self.fade:CreateAnimation("Alpha")
    self.fadeAlpha:SetDuration(0.15)
end

function Cursor:Hints(on)
    if not self.hints then return end
    local labels = self.holding and { { "A", "Place" }, { "Y", "Drop" }, { "B", "Close" } }
        or { { "A", "Select" }, { "X", "Use / Sell" }, { "Y", "Pick up" }, { "B", "Close" } }
    for i, chip in ipairs(self.chips) do
        chip:Hide()
        if labels[i] then
            chip:ClearAllPoints(); chip:SetPoint("CENTER", self.hints, "CENTER", (i - (#labels + 1) / 2) * 120, 0)
            chip.key:SetText(labels[i][1]); chip.label:SetText(labels[i][2]); chip:Show()
        end
    end
    local alpha = self.hints:GetAlpha()
    self.fade:Stop()
    self.fadeAlpha:SetFromAlpha(alpha); self.fadeAlpha:SetToAlpha(on and 1 or 0); self.fade:Play()
end

function Cursor:Focus(node)
    if InCombatLockdown() then return end
    local changed = not self.current or not node or self.current.frame ~= node.frame
    if changed then Leave(self.current) end
    self.current = node
    self.click:SetAttribute("clickbutton", node and node.frame or nil)
    if not node then self.border:Hide(); return end
    self.lastX, self.lastY = node.x, node.y
    if not node.extra then self.windowNode = node.frame end
    local scale = UIParent:GetEffectiveScale()
    local target = { node.x / scale, node.y / scale, node.w / scale + 24, node.h / scale + 24 }
    -- Start from a copy of where the frame is drawn now (the drawn table is reused every frame).
    local from = self.drawn and { self.drawn[1], self.drawn[2], self.drawn[3], self.drawn[4] } or target
    self.from, self.target, self.travel = from, target, 0
    self.border:Show()
    if changed then Enter(node) end
end

-- ---------------------------------------------------------------
-- Bounded scans retain focus when buttons are rebuilt or moved.
-- ---------------------------------------------------------------
function Cursor:Scan(initial)
    nodes = {}
    local visited = {}
    local function Walk(frame, root, depth)
        if #nodes >= 300 or depth > 12 or visited[frame] or not Allowed(frame) or not frame:IsVisible() then return end
        visited[frame] = true
        local node = Node(frame, root)
        if node then nodes[#nodes + 1] = node end
        for _, child in ipairs({ frame:GetChildren() }) do Walk(child, root, depth + 1) end
    end
    -- Reserve room for placement buttons even in a crowded spellbook.
    if self.holding then
        for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton" }) do
            for i = 1, 12 do
                local frame = _G[prefix .. i]
                local node = frame and Node(frame)
                if node then node.extra = true; nodes[#nodes + 1] = node; visited[frame] = true end
            end
        end
    end
    for _, root in ipairs(windows) do Walk(root, root, 0) end
    local chosen = self.current and Find(self.current.frame)
    if initial then
        chosen = nil
        for i = 1, 4 do
            local popup = _G["StaticPopup" .. i]
            if popup and popup:IsVisible() then chosen = Find(popup.button1); if chosen then break end end
        end
        for _, name in ipairs({ "QuestFrameAcceptButton", "QuestFrameCompleteButton", "QuestFrameCompleteQuestButton" }) do
            chosen = chosen or Find(_G[name])
        end
        if not chosen then
            for _, node in ipairs(nodes) do
                if node.root == windows[1] and (not chosen or node.y > chosen.y or (node.y == chosen.y and node.x < chosen.x)) then
                    chosen = node
                end
            end
        end
    end
    self:Focus(chosen or Nearest(self.lastX or 0, self.lastY or 0))
    scanAge = 0
end

function Cursor:Move(direction)
    if scanAge >= 0.25 then self:Scan() end
    local current, vector = self.current, directions[direction]
    if not current then return end
    local best, score
    for _, node in ipairs(nodes) do
        local dx, dy = node.x - current.x, node.y - current.y
        local along = dx * vector[1] + dy * vector[2]
        local value = along + 2.5 * math.abs(dx * vector[2] - dy * vector[1])
        if along > 2 and (not score or value < score) then best, score = node, value end
    end
    if best then self:Focus(best) end
end

function Cursor:Jump(delta)
    Watch(); self:Scan()
    if #windows == 0 then return end
    local index = 1
    for i, root in ipairs(windows) do if self.current and self.current.root == root then index = i end end
    local root = windows[(index - 1 + delta) % #windows + 1]
    local first
    for _, node in ipairs(nodes) do
        if node.root == root and (not first or node.y > first.y or (node.y == first.y and node.x < first.x)) then first = node end
    end
    if first then self:Focus(first) end
end

function Cursor:Pickup()
    if InCombatLockdown() then return end
    if GetCursorInfo() then ClearCursor(); ns.Log("cursor: drop"); return end
    local frame = self.current and self.current.frame
    if not frame or not Node(frame) then return end
    local slot, bank, spellID = Spell(frame)
    if type(frame.GetBagID) == "function" and C_Container and type(C_Container.PickupContainerItem) == "function" then
        C_Container.PickupContainerItem(frame:GetBagID(), frame:GetID())
    elseif Number(slot) and bank ~= nil and C_SpellBook and type(C_SpellBook.PickupSpellBookItem) == "function" then
        C_SpellBook.PickupSpellBookItem(slot, bank)
    elseif Number(spellID) and C_Spell and type(C_Spell.PickupSpell) == "function" then C_Spell.PickupSpell(spellID)
    elseif Number(frame.action) then PickupAction(frame.action)
    else ns.Toast("Nothing to pick up here."); return end
    ns.Log("cursor: pick up " .. (frame:GetName() or frame:GetObjectType()))
end

-- ---------------------------------------------------------------
-- Every exit releases input first, even if drawing or tooltips fail.
-- ---------------------------------------------------------------
function Cursor:Deactivate(reason)
    local wasActive = self.active
    if not wasActive and not self.bound and self.savedCVar == nil then return end
    self.active, self.held, self.afterClick = false, nil, nil
    if self.bound and not InCombatLockdown() then
        local ok = pcall(ClearOverrideBindings, self.click)
        if ok then self.bound = false end
        if self.click then pcall(self.click.SetAttribute, self.click, "clickbutton", nil) end
    end
    if self.savedCVar ~= nil and not InCombatLockdown() then
        local ok = pcall(SetCVar, "GamePadCursorAutoEnable", self.savedCVar)
        if ok then self.savedCVar = nil; ns.db.cursorSavedCVar = nil end
    end
    if self.border then self.border:Hide() end
    if InCombatLockdown() then Tooltip("Hide") else pcall(Leave, self.current) end
    self.current, self.holding, self.windowNode = nil, false, nil
    if ns.HUD then pcall(ns.HUD.SetKeyboardBarsForced, ns.HUD, false) end
    pcall(self.Hints, self, false)
    if wasActive then ns.Log("cursor: off " .. tostring(reason)) end
end

function Cursor:Guard(fn, ...)
    local ok, err = pcall(fn, self, ...)
    if not ok then
        if GetTime() >= (self.snagUntil or 0) then
            ns.Log("cursor: ERROR " .. tostring(err))
            ns.Toast("The controller cursor hit a snag.")
        end
        self.snagUntil = GetTime() + 10
        self:Deactivate("error")
    end
    return ok
end

function Cursor:Eligible()
    return GetTime() >= (self.snagUntil or 0) and ns.mode == "gamepad" and not InCombatLockdown() and not self.combat and ConsolePort == nil
        and ns.db and not ns.db.spikeDisabled and not (ns.Menu and ns.Menu:IsShown())
end

function Cursor:Activate()
    if not self:Eligible() then return end
    self.active = true
    self.savedCVar = self.savedCVar or GetCVar("GamePadCursorAutoEnable")
    ns.db.cursorSavedCVar = self.savedCVar
    SetCVar("GamePadCursorAutoEnable", "0")
    if type(SetGamePadCursorControl) == "function" then SetGamePadCursorControl(false) end
    -- Mark bound first, so even a half-finished bind is released on the next deactivate.
    self.bound = true
    for _, prefix in ipairs({ "", "SHIFT-" }) do
        for key, action in pairs(NAV) do SetOverrideBindingClick(self.click, true, prefix .. key, "CozyCouchCursorNav", action) end
        SetOverrideBindingClick(self.click, true, prefix .. "PAD1", "CozyCouchCursorClick", "LeftButton")
        SetOverrideBindingClick(self.click, true, prefix .. "PAD3", "CozyCouchCursorClick", "RightButton")
        SetOverrideBinding(self.click, true, prefix .. "PAD2", "TOGGLEGAMEMENU")
    end
    self:Scan(true)
    self:Hints(true)
    -- Name the windows that woke the cursor, so any surprise activation shows up in the diary.
    local windowNames = {}
    for i = 1, math.min(3, #windows) do windowNames[i] = windows[i]:GetName() or "?" end
    ns.Log("cursor: on " .. #nodes .. " nodes (" .. table.concat(windowNames, ", ") .. ")")
end

function Cursor:Poll()
    if not self:Eligible() then
        if self.active or ((self.bound or self.savedCVar ~= nil) and not InCombatLockdown()) then self:Deactivate("unavailable") end
        return
    end
    Watch()
    local holding = GetCursorInfo() ~= nil
    if #windows == 0 and not holding then
        if self.active or self.bound or self.savedCVar ~= nil then self:Deactivate("windows closed") end
        return
    end
    if not self.active then self:Activate() end
    if holding ~= self.holding then
        local returnFrame = self.windowNode
        self.holding = holding
        ns.HUD:SetKeyboardBarsForced(holding)
        self:Scan()
        if holding then
            local _, _, width = Rect(UIParent)
            self:Focus(Nearest(width / 2, 0, true) or self.current)
        else self:Focus(Find(returnFrame) or self.current) end
        self:Hints(true)
    end
end

function Cursor:Update(elapsed)
    poll = poll + elapsed
    if poll >= 0.15 then poll = 0; self:Poll() end
    if not self.active then return end
    if not self:Eligible() then self:Deactivate("unavailable"); return end
    scanAge = scanAge + elapsed
    if self.afterClick then self.afterClick = self.afterClick - elapsed end
    if scanAge >= 0.5 or (self.afterClick and self.afterClick <= 0) then
        self.afterClick = nil; Watch(); self:Scan()
    end
    if self.held then
        self.repeatIn = self.repeatIn - elapsed
        if self.repeatIn <= 0 then self.repeatIn = 0.09; self:Move(self.held) end
    end
    if self.target then
        self.travel = math.min(0.09, self.travel + elapsed)
        local fraction = 1 - (1 - self.travel / 0.09)^2
        -- Reuse one table, and stop animating once the frame has arrived (no per-frame work at rest).
        self.drawn = self.drawn or {}
        local drawn = self.drawn
        for i = 1, 4 do drawn[i] = self.from[i] + (self.target[i] - self.from[i]) * fraction end
        self.border:ClearAllPoints()
        self.border:SetPoint("CENTER", UIParent, "BOTTOMLEFT", drawn[1], drawn[2])
        self.border:SetSize(drawn[3], drawn[4])
        if self.travel >= 0.09 then self.target = nil end
    end
end

function Cursor:Setup()
    if self.ready then return end
    if ns.db and ns.db.cursorSavedCVar ~= nil and not InCombatLockdown() then
        local ok = pcall(SetCVar, "GamePadCursorAutoEnable", ns.db.cursorSavedCVar)
        if ok then
            ns.db.cursorSavedCVar = nil
            ns.Log("cursor: restored stick-cursor setting")
        end
    end
    self:BuildArt()
    self.click = CreateFrame("Button", "CozyCouchCursorClick", UIParent, "SecureHandlerStateTemplate, SecureActionButtonTemplate")
    self.click:SetAttribute("_onstate-cozycombat", [[
        if newstate == "combat" then
            self:ClearBindings()
            self:SetAttribute("clickbutton", nil)
        end
    ]])
    RegisterStateDriver(self.click, "cozycombat", "[combat] combat; nocombat")
    self.click:RegisterForClicks("AnyUp", "AnyDown")
    self.click:SetAttribute("pressAndHoldAction", true)
    self.click:SetAttribute("typerelease", "click")
    self.click:SetScript("PostClick", function(_, button, down)
        if down then return end
        self:Guard(function(cursor)
            if not cursor.active then return end
            local frame = cursor.current and cursor.current.frame
            ns.Log("cursor: " .. (button == "RightButton" and "X " or "A ") .. (frame and (frame:GetName() or frame:GetObjectType()) or "none"))
            cursor.afterClick = 0.1
        end)
    end)
    local nav = CreateFrame("Button", "CozyCouchCursorNav", UIParent)
    nav:RegisterForClicks("AnyUp", "AnyDown")
    nav:SetScript("OnClick", function(_, action, down)
        self:Guard(function(cursor)
            if not down then if cursor.held == action then cursor.held = nil end; return end
            if not cursor.active or not cursor:Eligible() then cursor:Deactivate("unavailable"); return end
            if directions[action] then cursor.held, cursor.repeatIn = action, 0.35; cursor:Move(action)
            elseif action == "PICK" then cursor:Pickup()
            else cursor:Jump(action == "PREV" and -1 or 1) end
        end)
    end)
    -- Wrap only our own menu entry: release before it takes its overrides.
    local open = ns.Menu.Open
    ns.Menu.Open = function(menu, ...)
        self:Deactivate("Cozy Menu")
        return open(menu, ...)
    end
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_LOGOUT", "CURSOR_CHANGED",
        "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "BAG_UPDATE_DELAYED", "MERCHANT_UPDATE", "QUEST_ITEM_UPDATE",
        "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "LOOT_OPENED", "SPELLS_CHANGED" }) do
        pcall(self.RegisterEvent, self, event)
    end
    self:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then self.combat = true; self:Deactivate("combat")
        elseif event == "PLAYER_LOGOUT" then self:Deactivate("logout")
        -- Load-on-demand windows (trainer, auction house...) register when they load: refresh the name list now.
        elseif event == "ADDON_LOADED" then namesUntil = 0
        elseif event == "PLAYER_REGEN_ENABLED" then self.combat = false; self:Deactivate("combat ended")
        else self:Guard(function(cursor) cursor:Poll(); if cursor.active then cursor:Scan() end end) end
    end)
    self:SetScript("OnUpdate", function(_, elapsed) self:Guard(self.Update, elapsed) end)
    self.ready = true
end
