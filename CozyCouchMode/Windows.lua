-- ===============================================================
-- Windows.lua - parchment conversations, quests, and shops for the couch.
-- Blizzard keeps the real interaction open; we only fade its window.
-- Our buttons and cursor settings are borrowed until this window closes.
-- Core calls Setup once at login, after the menu has made ns.Toast.
-- ===============================================================

local _, ns = ...
local Windows = CreateFrame("Frame", "CozyCouchWindow", UIParent)
ns.Windows = Windows
Windows:Hide()
local MEDIA = "Interface\\AddOns\\CozyCouchMode\\Media\\"
local LABEL = "Fonts\\FRIZQT__.TTF"
local DISPLAY = MEDIA .. "Fonts\\MelonHoney.ttf"
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local INK, SOFT = { 0.23, 0.14, 0.06 }, { 0.36, 0.26, 0.16 }
local COLORS = { A = { 0.49, 0.88, 0.56 }, B = { 0.95, 0.48, 0.43 },
    X = { 0.47, 0.68, 0.96 }, Y = { 0.95, 0.83, 0.38 } }
local KEYS = {
    PADDUP = "UP", PADDDOWN = "DOWN", PADDLEFT = "LEFT", PADDRIGHT = "RIGHT",
    PAD1 = "A", PAD2 = "B", PAD3 = "X", PAD4 = "Y", PADLSHOULDER = "LB", PADRSHOULDER = "RB",
}
local owner = CreateFrame("Frame")
local nav = CreateFrame("Button", "CozyCouchWindowNav")
local needsRelease, savedCursor, cursorStored = false, nil, false
local generation, pending, ready = 0, nil, false
local hooked = {}

-- ---------------------------------------------------------------
-- Small guards keep secret values out of comparisons and arithmetic.
-- ---------------------------------------------------------------
local function Secret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Number(value, fallback)
    if not Secret(value) and type(value) == "number" then return value end
    return fallback or 0
end

local function String(value)
    if not Secret(value) and type(value) == "string" then return value end
    return ""
end

local function Coins(value)
    return GetCoinTextureString(Number(value))
end

local function Toast(message)
    if ns.Toast then ns.Toast(message) else ns.Print(message) end
end

local function Blizzard(kind)
    if kind == "talk" then return GossipFrame end
    if kind == "shop" then return MerchantFrame end
    return QuestFrame
end

local function MerchantOpen()
    return MerchantFrame and MerchantFrame:IsShown()
end

local function Release()
    if InCombatLockdown() then needsRelease = true; return end
    ClearOverrideBindings(owner)
    needsRelease = false
end

local function Take()
    if InCombatLockdown() then return false end
    for key, action in pairs(KEYS) do
        SetOverrideBindingClick(owner, true, key, "CozyCouchWindowNav", action)
        SetOverrideBindingClick(owner, true, "SHIFT-" .. key, "CozyCouchWindowNav", action)
    end
    return true
end

local function CursorCVar(value)
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    setter("GamePadCursorAutoEnable", value)
end

local function QuietCursor()
    if not cursorStored then
        local getter = C_CVar and C_CVar.GetCVar or GetCVar
        savedCursor = getter("GamePadCursorAutoEnable")
        cursorStored = savedCursor ~= nil
    end
    CursorCVar("0")
    if type(SetGamePadCursorControl) == "function" then SetGamePadCursorControl(false) end
end

local function RestoreCursor()
    if cursorStored then
        CursorCVar(savedCursor)
        cursorStored, savedCursor = false, nil
    end
end

local function CancelPending()
    generation, pending = generation + 1, nil
end

function Windows:IsOpen()
    return self.kind ~= nil and self:IsShown()
end

function Windows:Close(reason)
    CancelPending()
    -- Release here as well as OnHide: a hidden UIParent can suppress OnHide.
    Release()
    if self.source then self.source:SetAlpha(1) end
    RestoreCursor()
    if self.animation then self.animation:Stop() end
    if self.kind then ns.Log("windows: close", self.kind, reason or "closed") end
    self.kind, self.source, self.junkPasses = nil, nil, nil
    self:Hide()
end

local function Safe(callback, ...)
    local ok, message = pcall(callback, ...)
    if not ok then
        ns.Log("windows: ERROR " .. tostring(message))
        -- Hand control back even when refreshing or acting fails halfway through.
        local closed, closeError = pcall(Windows.Close, Windows, "error")
        if not closed then ns.Log("windows: ERROR " .. tostring(closeError)) end
        Toast("Something went wrong — try the regular window.")
    end
    return ok
end

function Windows:CloseAll(reason)
    Safe(function()
        self:Close(reason)
        if GossipFrame and GossipFrame:IsShown() then
            ns.Log("windows: talk goodbye")
            if C_GossipInfo and C_GossipInfo.CloseGossip then C_GossipInfo.CloseGossip() else CloseGossip() end
        end
        if QuestFrame and QuestFrame:IsShown() then ns.Log("windows: quest close"); CloseQuest() end
        if MerchantOpen() then ns.Log("windows: shop close"); CloseMerchant() end
    end)
end

-- ---------------------------------------------------------------
-- Drawing helpers and one-time construction. Refresh reuses every region.
-- ---------------------------------------------------------------
local function Text(parent, size, color, font)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetFont(font or LABEL, size, "")
    text:SetTextColor(unpack(color or INK))
    return text
end

local function Picture(parent, file, width, height, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetTexture(MEDIA .. file .. ".tga")
    if width then
        texture:SetSize(width, height)
        texture:SetPoint("CENTER")
    else
        texture:SetAllPoints(parent)
    end
    return texture
end

local function MaskIcon(parent, size)
    local icon = parent:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    return icon
end

local function Build(self)
    self:SetSize(600, 540)
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    self:SetFrameStrata("DIALOG")
    Picture(self, "parchment", nil, nil, "BACKGROUND")
    self.who = Text(self, 12, SOFT)
    self.who:SetPoint("TOP", 0, -38)
    self.who:SetWidth(500)
    self.title = Text(self, 32, INK, DISPLAY)
    self.title:SetPoint("TOP", 0, -56)
    self.title:SetSize(500, 44)
    local line = self:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.36, 0.23, 0.10, 0.6)
    line:SetSize(260, 2)
    line:SetPoint("TOP", 0, -104)
    local stud = Picture(self, "gem", 11, 11)
    stud:ClearAllPoints()
    stud:SetPoint("CENTER", line, "CENTER")
    self.bodyClip = CreateFrame("Frame", nil, self)
    self.bodyClip:SetSize(476, 180)
    self.bodyClip:SetPoint("TOP", 0, -120)
    self.bodyClip:SetClipsChildren(true)
    self.bodyContent = CreateFrame("Frame", nil, self.bodyClip)
    self.bodyContent:SetSize(476, 180)
    self.body = Text(self.bodyContent, 15)
    self.body:SetWidth(476)
    self.body:SetPoint("TOPLEFT")
    self.body:SetJustifyH("LEFT")
    self.objective = Text(self.bodyContent, 15, SOFT)
    self.objective:SetWidth(476)
    self.objective:SetPoint("TOPLEFT", self.body, "BOTTOMLEFT", 0, -15)
    self.objective:SetJustifyH("LEFT")
    self.rows = {}
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, self)
        row:SetSize(488, 40)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1)
        row.highlight:SetGradient("HORIZONTAL", CreateColor(0.94, 0.72, 0.24, 0.38), CreateColor(0.94, 0.72, 0.24, 0.10))
        local socket = CreateFrame("Frame", nil, row)
        socket:SetSize(32, 32)
        socket:SetPoint("LEFT", 8, 0)
        Picture(socket, "socket")
        row.icon = MaskIcon(socket, 28)
        row.glyph = Text(socket, 25, { 1, 0.82, 0.25 })
        row.glyph:SetPoint("CENTER")
        row.name = Text(row, 15.5)
        row.name:SetPoint("LEFT", 48, 0)
        row.name:SetSize(278, 36)
        row.name:SetJustifyH("LEFT")
        row.sub = Text(row, 13, SOFT)
        row.sub:SetPoint("RIGHT", -8, 0)
        row.sub:SetSize(148, 36)
        row.sub:SetJustifyH("RIGHT")
        self.rows[i] = row
    end
    self.rewardLabel = Text(self, 12, SOFT)
    self.rewardLabel:SetPoint("TOP", 0, -302)
    self.sockets = {}
    for i = 1, 4 do
        local socket = CreateFrame("Frame", nil, self)
        socket:SetSize(58, 58)
        Picture(socket, "sign_socket", nil, nil, "BACKGROUND")
        socket.icon = MaskIcon(socket, 42)
        Picture(socket, "ring", 68, 68, "OVERLAY")
        socket.focus = Picture(socket, "ring_thin", 76, 76, "OVERLAY")
        socket.focus:SetVertexColor(1, 0.82, 0.25)
        socket.name = Text(socket, 13)
        socket.name:SetPoint("TOP", socket, "BOTTOM", 0, -8)
        socket.name:SetSize(120, 34)
        self.sockets[i] = socket
    end
    self.money = Text(self, 13, SOFT)
    self.money:SetPoint("TOP", 0, -426)
    self.money:SetWidth(500)
    self.purse = Text(self, 14, SOFT)
    self.purse:SetPoint("BOTTOM", 0, 98)
    self.purse:SetWidth(500)
    self.tabs = {}
    for i, name in ipairs({ "Buy", "Sell", "Buyback" }) do
        local tab = CreateFrame("Frame", nil, self)
        tab:SetSize(92, 28)
        tab:SetPoint("TOP", (i - 2) * 98, -112)
        tab.background = tab:CreateTexture(nil, "BACKGROUND")
        tab.background:SetAllPoints()
        tab.label = Text(tab, 11, SOFT)
        tab.label:SetPoint("CENTER")
        tab.label:SetText(string.upper(name))
        self.tabs[i] = tab
    end
    self.shoulders = Text(self, 11, SOFT)
    self.shoulders:SetPoint("TOP", 0, -120)
    self.shoulders:SetText("LB                                              RB")
    self.chips = {}
    for i = 1, 4 do
        local chip = CreateFrame("Frame", nil, self)
        chip:SetSize(124, 50)
        Picture(chip, "chip", nil, nil, "BACKGROUND")
        chip.glyph = Picture(chip, "gem", 26, 26)
        chip.glyph:ClearAllPoints()
        chip.glyph:SetPoint("LEFT", 12, 0)
        chip.letter = Text(chip, 12)
        chip.letter:SetPoint("CENTER", chip.glyph, "CENTER")
        chip.label = Text(chip, 11, { 0.96, 0.91, 0.78 })
        chip.label:SetPoint("CENTER", 19, 0)
        chip.label:SetWidth(80)
        self.chips[i] = chip
    end
    self.animation = self:CreateAnimationGroup()
    local alpha = self.animation:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.22)
    alpha:SetSmoothing("OUT")
    self.animation:SetToFinalAlpha(true)
    local slide = self.animation:CreateAnimation("Translation")
    slide:SetOffset(0, 10)
    slide:SetDuration(0.26)
    slide:SetSmoothing("OUT")
    -- The base point starts ten pixels lower; finishing restores the resting point.
    self.animation:SetScript("OnFinished", function()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    end)
end

local function Hints(self, hints)
    for i, chip in ipairs(self.chips) do
        local hint = hints[i]
        chip:SetShown(hint ~= nil)
        if hint then
            chip:ClearAllPoints()
            chip:SetPoint("TOP", (i - (#hints + 1) / 2) * 132, -454)
            chip.glyph:SetTexture(MEDIA .. (hint[1] == "DPAD" and "glyph_dpad" or "gem") .. ".tga")
            chip.letter:SetText(hint[1] == "DPAD" and "" or hint[1])
            chip.letter:SetTextColor(unpack(COLORS[hint[1]] or INK))
            chip.label:SetText(hint[2])
        end
    end
end

local function Body(self, text, objective, height)
    self.bodyClip:SetHeight(height or 180)
    self.body:SetText(String(text))
    self.objective:SetText(String(objective))
    self.bodyHeight = self.body:GetStringHeight()
    if String(objective) ~= "" then self.bodyHeight = self.bodyHeight + 15 + self.objective:GetStringHeight() end
    self.bodyContent:SetHeight(math.max(1, self.bodyHeight))
    self.scroll = math.max(0, math.min(self.scroll or 0, self.bodyHeight - self.bodyClip:GetHeight()))
    self.bodyContent:ClearAllPoints()
    self.bodyContent:SetPoint("TOPLEFT", self.bodyClip, "TOPLEFT", 0, self.scroll)
end

local function Scroll(self, delta)
    local before = self.scroll
    self.scroll = math.max(0, math.min(self.scroll + delta, self.bodyHeight - self.bodyClip:GetHeight()))
    self.bodyContent:ClearAllPoints()
    self.bodyContent:SetPoint("TOPLEFT", self.bodyClip, "TOPLEFT", 0, self.scroll)
    return self.scroll ~= before
end

local function Rows(self, top, count)
    self.selection = math.max(1, math.min(self.selection, #self.items))
    self.offset = math.max(0, math.min(self.offset or 0, #self.items - count))
    if self.selection <= self.offset then self.offset = self.selection - 1 end
    if self.selection > self.offset + count then self.offset = self.selection - count end
    for i, row in ipairs(self.rows) do
        local index = self.offset + i
        local item = i <= count and self.items[index]
        row:SetShown(not not item)
        if item then
            row:ClearAllPoints()
            row:SetPoint("TOP", 0, -top - (i - 1) * 40)
            row.highlight:SetShown(index == self.selection)
            row.icon:SetShown(not item.glyph)
            row.icon:SetTexture(item.icon)
            row.glyph:SetText(item.glyph or "")
            row.glyph:SetTextColor(unpack(item.incomplete and { 0.55, 0.55, 0.55 } or { 1, 0.82, 0.25 }))
            row.name:SetText(item.name)
            row.name:SetTextColor(unpack(item.grey and { 0.49, 0.45, 0.41 } or INK))
            row.sub:SetText(item.sub or "")
        end
    end
end

-- ---------------------------------------------------------------
-- Talk and greeting data retain IDs (or legacy indices) for selection.
-- ---------------------------------------------------------------
local function TalkItems(greeting)
    local items = {}
    if greeting then
        for i = 1, GetNumAvailableQuests() do
            local title = GetAvailableTitle(i)
            items[#items + 1] = { name = title, glyph = "!", action = "available", id = i }
        end
        for i = 1, GetNumActiveQuests() do
            local title, complete = GetActiveTitle(i)
            items[#items + 1] = { name = title, glyph = "?", incomplete = not complete, action = "active", id = i }
        end
        return items
    end
    for _, quest in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
        items[#items + 1] = { name = quest.title, glyph = "!", action = "available", id = quest.questID }
    end
    for _, quest in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
        items[#items + 1] = { name = quest.title, glyph = "?", incomplete = not quest.isComplete,
            action = "active", id = quest.questID }
    end
    local options = C_GossipInfo.GetOptions() or {}
    table.sort(options, function(a, b) return Number(a.orderIndex) < Number(b.orderIndex) end)
    for _, option in ipairs(options) do
        local icon = option.overrideIconID
        if Secret(icon) or type(icon) ~= "number" then icon = option.icon end
        if Secret(icon) or type(icon) ~= "number" then icon = "Interface\\GossipFrame\\GossipGossipIcon" end
        items[#items + 1] = { name = option.name, icon = icon, action = "option",
            id = option.gossipOptionID, order = option.orderIndex }
    end
    return items
end

local function Rewards(self)
    local choices = self.kind ~= "progress" and Number(GetNumQuestChoices()) or 0
    self.choices = choices
    local rewardType = self.kind == "progress" and "required" or (choices > 0 and "choice" or "reward")
    local count = self.kind == "progress" and Number(GetNumQuestItems()) or
        (choices > 0 and choices or Number(GetNumQuestRewards()))
    self.rewardCount = count
    self.choice = math.max(1, math.min(self.choice, count))
    -- Four sockets at a time, retaining the real reward index on later pages.
    local start = math.floor((self.choice - 1) / 4) * 4
    local visible = math.min(4, count - start)
    self.rewardLabel:SetText(self.kind == "progress" and "" or
        (choices > 0 and "Choose one reward" or (count > 0 and "You will receive" or "")))
    for i, socket in ipairs(self.sockets) do
        socket:SetShown(i <= visible)
        if i <= visible then
            local index = start + i
            local name, texture, quantity = GetQuestItemInfo(rewardType, index)
            local selected = choices > 0 and index == self.choice
            socket:ClearAllPoints()
            socket:SetPoint("TOP", (i - (visible + 1) / 2) * 126, -322 + (selected and 4 or 0))
            socket.icon:SetTexture(texture)
            socket.focus:SetShown(selected)
            local showCount = rewardType == "required" or Number(quantity) > 1
            local suffix = showCount and (" x" .. Number(quantity, 1)) or ""
            socket.name:SetText((String(name) ~= "" and name or "Loading item…") .. suffix)
        end
    end
    local money, xp = GetRewardMoney(), GetRewardXP()
    local parts = {}
    if not Secret(money) and Number(money) > 0 then parts[#parts + 1] = Coins(money) end
    if not Secret(xp) and Number(xp) > 0 then parts[#parts + 1] = Number(xp) .. " XP" end
    self.money:SetText(table.concat(parts, " · "))
end

-- ---------------------------------------------------------------
-- Shop snapshots are rebuilt after inventory changes, never kept as bag truth.
-- ---------------------------------------------------------------
local function BagItems(junkOnly)
    local items = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and not Secret(info.hasNoValue) and not info.hasNoValue and not Secret(info.quality) then
                local junk = info.quality == 0
                if not junkOnly or junk then
                    local name, price
                    if C_Item and C_Item.GetItemInfo and not Secret(info.hyperlink) and info.hyperlink then
                        name = C_Item.GetItemInfo(info.hyperlink)
                        price = select(11, C_Item.GetItemInfo(info.hyperlink))
                    end
                    local count = Number(info.stackCount, 1)
                    local sub = junk and "junk" or ""
                    if Number(price) > 0 then sub = sub .. (junk and " · " or "") .. Coins(Number(price) * count) end
                    items[#items + 1] = { bag = bag, slot = slot, junk = junk, icon = info.iconFileID,
                        name = (String(info.itemName or name or info.hyperlink)) .. (count > 1 and (" x" .. count) or ""),
                        sub = sub, id = info.itemID, hyperlink = info.hyperlink }
                end
            end
        end
    end
    table.sort(items, function(a, b)
        if a.junk ~= b.junk then return a.junk end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return items
end

local function MerchantInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then return C_MerchantFrame.GetItemInfo(index) end
    if GetMerchantItemInfo then
        local name, texture, price, quantity, available, purchasable, usable, extended = GetMerchantItemInfo(index)
        return { name = name, texture = texture, price = price, stackCount = quantity, numAvailable = available,
            isPurchasable = purchasable, isUsable = usable, hasExtendedCost = extended }
    end
end

local function ShopItems(tab)
    if tab == 2 then return BagItems(false) end
    local items = {}
    local count = tab == 1 and GetMerchantNumItems() or GetNumBuybackItems()
    for i = 1, Number(count) do
        if tab == 1 then
            local info = MerchantInfo(i)
            if info then
                items[#items + 1] = { id = i, name = info.name, icon = info.texture,
                    sub = info.hasExtendedCost and "special price" or Coins(info.price),
                    extended = info.hasExtendedCost, grey = not info.isUsable or not info.isPurchasable,
                    purchasable = info.isPurchasable, available = info.numAvailable }
            end
        else
            local name, icon, price, quantity = GetBuybackItemInfo(i)
            items[#items + 1] = { id = i, name = String(name) .. (Number(quantity) > 1 and (" x" .. quantity) or ""),
                icon = icon, sub = Coins(price) }
        end
    end
    return items
end

function Windows:Refresh()
    local shop = self.kind == "shop"
    local talk = self.kind == "talk" or self.kind == "greeting"
    self.bodyClip:SetShown(not shop)
    self.purse:SetShown(shop)
    self.shoulders:SetShown(shop)
    self.rewardLabel:SetText("")
    self.money:SetText("")
    for _, row in ipairs(self.rows) do row:Hide() end
    for _, socket in ipairs(self.sockets) do socket:Hide() end
    for i, tab in ipairs(self.tabs) do
        tab:SetShown(shop)
        tab.background:SetColorTexture(0.30, 0.17, 0.08, self.tab == i and 1 or 0.1)
        tab.label:SetTextColor(unpack(self.tab == i and { 0.96, 0.91, 0.78 } or SOFT))
    end
    if shop then
        self.title:SetText("Fine Wares")
        self.items = ShopItems(self.tab)
        Rows(self, 152, 6)
        local purse = "Your purse: " .. Coins(GetMoney())
        if CanMerchantRepair() then
            local cost = GetRepairAllCost()
            if Number(cost) > 0 then purse = purse .. " · Repair all: " .. Coins(cost) end
        end
        self.purse:SetText(purse)
        Hints(self, { { "A", ({ "BUY ONE", "SELL ONE", "BUY BACK" })[self.tab] },
            { "X", "SELL JUNK" }, { "Y", "REPAIR ALL" }, { "B", "CLOSE" } })
    elseif talk then
        self.title:SetText("Well met, traveler")
        self.items = TalkItems(self.kind == "greeting")
        local count = math.min(6, #self.items)
        local top = math.min(300, 440 - count * 40)
        Body(self, self.kind == "greeting" and GetGreetingText() or C_GossipInfo.GetText(), "", math.min(180, top - 132))
        Rows(self, top, math.max(1, count))
        Hints(self, { { "DPAD", "CHOOSE" }, { "A", "SELECT" }, { "B", "GOODBYE" } })
    else
        self.title:SetText(GetTitleText())
        if self.kind == "detail" then Body(self, GetQuestText(), GetObjectiveText())
        elseif self.kind == "progress" then Body(self, GetProgressText())
        else Body(self, GetRewardText()) end
        Rewards(self)
        local hints = {}
        if self.choices > 0 then hints[#hints + 1] = { "DPAD", "REWARD" }
        elseif self.bodyHeight > 180 or self.rewardCount > 4 then hints[#hints + 1] = { "DPAD", "SCROLL" } end
        hints[#hints + 1] = { "A", self.kind == "detail" and "ACCEPT" or (self.kind == "progress" and "CONTINUE" or "COMPLETE") }
        hints[#hints + 1] = { "B", self.kind == "detail" and "DECLINE" or "CLOSE" }
        Hints(self, hints)
    end
end

-- ---------------------------------------------------------------
-- Actions run in the protected handler below, with a diary entry per press.
-- ---------------------------------------------------------------
local function Handoff(self)
    ns.Log("windows: quest regular window")
    self:Close("confirmation needed")
    Toast("This one needs the regular window.")
end

local function SelectTalk(self)
    local item = self.items[self.selection]
    if not item then return end
    ns.Log("windows:", self.kind, "select", item.action, item.id or item.order)
    if self.kind == "greeting" then
        if item.action == "available" then SelectAvailableQuest(item.id) else SelectActiveQuest(item.id) end
    elseif item.action == "available" then C_GossipInfo.SelectAvailableQuest(item.id)
    elseif item.action == "active" then C_GossipInfo.SelectActiveQuest(item.id)
    elseif C_GossipInfo.SelectOptionByIndex and item.order then C_GossipInfo.SelectOptionByIndex(item.order)
    else C_GossipInfo.SelectOption(item.id) end
end

local function QuestAction(self)
    if self.kind == "detail" then
        ns.Log("windows: quest accept")
        if QuestFlagsPVP and QuestFlagsPVP() then Handoff(self); return end
        if QuestGetAutoAccept and QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else AcceptQuest() end
        Toast("Quest accepted. Good luck out there.")
    elseif self.kind == "progress" then
        ns.Log("windows: quest continue")
        if IsQuestCompletable() then CompleteQuest() else Toast("Not quite done yet.") end
    elseif self.kind == "reward" then
        ns.Log("windows: quest reward", self.choices > 0 and self.choice or 0)
        local cost = GetQuestMoneyToGet and GetQuestMoneyToGet()
        if Secret(cost) or Number(cost) > 0 then Handoff(self); return end
        GetQuestReward(self.choices > 0 and self.choice or 0)
        Toast("Quest complete!")
    end
end

local function Sell(item, junkOnly)
    -- Re-read the slot: a bag update may have moved the displayed item.
    local info = C_Container.GetContainerItemInfo(item.bag, item.slot)
    if not info or Secret(info.hasNoValue) or info.hasNoValue or info.isLocked then return false end
    if Secret(info.itemID) or Secret(info.hyperlink) then return false end
    if info.itemID ~= item.id or info.hyperlink ~= item.hyperlink then return false end
    if junkOnly and (Secret(info.quality) or info.quality ~= 0) then return false end
    -- This must be the last check before UseContainerItem: otherwise it equips/uses.
    if not MerchantFrame or not MerchantFrame:IsShown() then return false end
    C_Container.UseContainerItem(item.bag, item.slot)
    return true
end

local function SellJunk(self, retry)
    if not MerchantOpen() then self.junkPasses = nil; return end
    local junk = BagItems(true)
    if #junk == 0 then
        self.junkPasses = nil
        if not retry then Toast("No junk to sell.") end
        ns.Log("windows: shop sell junk 0")
        return
    end
    if not retry then self.junkPasses = 0 end
    self.junkPasses = self.junkPasses + 1
    local sold = 0
    if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems and C_MerchantFrame.IsSellAllJunkEnabled
        and C_MerchantFrame.IsSellAllJunkEnabled() then
        if MerchantOpen() then C_MerchantFrame.SellAllJunkItems(); sold = #junk end
    else
        for _, item in ipairs(junk) do
            if Sell(item, true) then sold = sold + 1 end
        end
    end
    ns.Log("windows: shop sell junk", sold, "pass", self.junkPasses)
    if not retry then Toast("Sold your junk.") end
    if self.junkPasses >= 3 then self.junkPasses = nil end
end

local function ShopAction(self)
    if not MerchantOpen() then self:Close("merchant gone"); return end
    local item = self.items[self.selection]
    if not item then return end
    if self.tab == 1 then
        local info = MerchantInfo(item.id)
        if not info or info.hasExtendedCost then Toast("This one needs the regular window."); return end
        if not info.isPurchasable or Number(info.numAvailable, -1) == 0 then Toast("That is not available right now."); return end
        ns.Log("windows: shop buy", item.id)
        BuyMerchantItem(item.id, 1)
        Toast("Bought " .. String(info.name) .. ".")
    elseif self.tab == 2 then
        ns.Log("windows: shop sell", item.bag, item.slot)
        if Sell(item, false) then Toast("Sold " .. item.name .. ".") else Toast("That item has changed. Try again.") end
    else
        ns.Log("windows: shop buyback", item.id)
        BuybackItem(item.id)
        Toast("Bought back " .. item.name .. ".")
    end
end

local function Repair()
    if not MerchantOpen() then return end
    ns.Log("windows: shop repair all")
    if not CanMerchantRepair() then Toast("This merchant cannot repair your gear."); return end
    local cost, canRepair = GetRepairAllCost()
    if Number(cost) > 0 and not Secret(canRepair) and canRepair then
        RepairAllItems()
        Toast("All repaired for " .. Coins(cost) .. ".")
    else
        Toast("No repairs available right now.")
    end
end

function Windows:Nav(action)
    if not self:IsOpen() then return end
    if InCombatLockdown() or ns.mode ~= "gamepad" then self:Close("input mode or combat"); return end
    if GetTime() - self.openedAt < 0.4 then return end
    if action == "A" and self.kind == "reward" and GetTime() - self.openedAt < 0.7 then return end
    if not self.source or not self.source:IsShown() then self:Close("interaction gone"); return end
    ns.Log("windows:", self.kind, "input", action)
    if action == "B" then self:CloseAll("B button"); return end
    if action == "A" then
        if self.kind == "shop" then ShopAction(self)
        elseif self.kind == "talk" or self.kind == "greeting" then SelectTalk(self)
        else QuestAction(self) end
        return
    end
    if self.kind == "shop" then
        if action == "X" then SellJunk(self, false)
        elseif action == "Y" then Repair()
        elseif action == "LB" or action == "RB" then
            self.tab = (self.tab - 1 + (action == "LB" and -1 or 1)) % 3 + 1
            self.selection, self.offset = 1, 0
        elseif action == "UP" or action == "DOWN" then
            self.selection = self.selection + (action == "UP" and -1 or 1)
        end
    elseif self.kind == "talk" or self.kind == "greeting" then
        -- At either list end, keep moving to read the rest of a long greeting.
        if action == "UP" then
            if self.selection > 1 then self.selection = self.selection - 1 else Scroll(self, -40) end
        elseif action == "DOWN" then
            if self.selection < #self.items then self.selection = self.selection + 1 else Scroll(self, 40) end
        end
    else
        if action == "UP" or action == "DOWN" then Scroll(self, action == "UP" and -40 or 40)
        elseif action == "LEFT" or action == "RIGHT" then
            self.choice = math.max(1, math.min(self.rewardCount, self.choice + (action == "LEFT" and -1 or 1)))
        end
    end
    if self:IsOpen() then self:Refresh() end
end

-- ---------------------------------------------------------------
-- Delayed opens follow Blizzard, including auto-selected gossip options.
-- A generation prevents yesterday's timer from reopening a closed window.
-- ---------------------------------------------------------------
local function Open(self, kind)
    -- Stay out of the way when ConsolePort runs the pad, or after /cozy reset.
    if ConsolePort ~= nil or (ns.db and ns.db.spikeDisabled) then return end
    local source = Blizzard(kind)
    if ns.mode ~= "gamepad" or InCombatLockdown() or not source or not source:IsShown() then return end
    if ns.Menu and ns.Menu:IsShown() then ns.Menu:Close("NPC interaction") end
    self:Close("new page")
    self.kind, self.source = kind, source
    self.selection, self.choice, self.offset, self.scroll, self.tab = 1, 1, 0, 0, 1
    self.openedAt = GetTime()
    self.who:SetText(string.upper(String(UnitName("npc"))))
    self:Refresh()
    if not Take() then self:Close("combat started"); return end
    QuietCursor()
    source:SetAlpha(0)
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    self:Show()
    self.animation:Play()
    ns.Log("windows: open", kind)
end

local function Queue(kind)
    generation = generation + 1
    local ticket = generation
    pending = kind
    C_Timer.After(0, function()
        if ticket ~= generation then return end
        pending = nil
        Safe(Open, Windows, kind)
    end)
end

local function HookFrames()
    for _, kind in ipairs({ "talk", "detail", "shop" }) do
        local source = Blizzard(kind)
        if source and not hooked[source] then
            hooked[source] = true
            source:HookScript("OnShow", function()
                Safe(function()
                    if Windows:IsOpen() and Windows.source == source then
                        if ns.mode == "gamepad" and not InCombatLockdown() then source:SetAlpha(0)
                        else Windows:Close("input mode or combat") end
                    elseif kind == "shop" then Queue("shop") end
                end)
            end)
        end
    end
end

local OPEN_EVENTS = {
    GOSSIP_SHOW = "talk", QUEST_GREETING = "greeting", QUEST_DETAIL = "detail",
    QUEST_PROGRESS = "progress", QUEST_COMPLETE = "reward",
}

local function Event(self, event)
    -- Logging out with a window open must still put the game's cursor setting back.
    if event == "PLAYER_LOGOUT" then self:Close("logout")
    elseif event == "PLAYER_REGEN_DISABLED" then self:Close("combat started")
    elseif event == "PLAYER_REGEN_ENABLED" then
        if needsRelease then Release() end
    elseif event == "ADDON_LOADED" or event == "MERCHANT_SHOW" then
        -- Blizzard may load these frames on demand after our login Setup.
        HookFrames()
        if event == "MERCHANT_SHOW" and MerchantOpen() then Queue("shop") end
    elseif OPEN_EVENTS[event] then
        HookFrames()
        Queue(OPEN_EVENTS[event])
    elseif event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" or event == "MERCHANT_CLOSED" then
        local closedKind = event == "GOSSIP_CLOSED" and "talk" or (event == "MERCHANT_CLOSED" and "shop" or "detail")
        local source = Blizzard(closedKind)
        if self.source and self.source == source then
            -- A gossip close may follow the quest/shop show event in the same frame.
            local nextKind = pending and Blizzard(pending) ~= source and pending
            self:Close(event)
            if nextKind then Queue(nextKind) end
        elseif pending and Blizzard(pending) == source then CancelPending() end
    elseif self.kind == "shop" and (event == "MERCHANT_UPDATE" or event == "BAG_UPDATE_DELAYED") then
        if not MerchantOpen() then self:Close("merchant gone"); return end
        if event == "BAG_UPDATE_DELAYED" and self.junkPasses then SellJunk(self, true) end
        self:Refresh()
    elseif self:IsOpen() and event == "QUEST_ITEM_UPDATE" then
        self:Refresh()
    end
end

function Windows:Setup()
    if ready then return end
    ready = true
    Build(self)
    nav:RegisterForClicks("AnyDown")
    nav:SetScript("OnClick", function(_, action, down)
        if down == false then return end
        Safe(self.Nav, self, action)
    end)
    self:SetScript("OnHide", function()
        Release()
        Safe(self.Close, self, "hidden")
    end)
    self:SetScript("OnUpdate", function()
        if self.kind and (ns.mode ~= "gamepad" or InCombatLockdown()) then Safe(self.Close, self, "input mode or combat") end
    end)
    self:SetScript("OnEvent", function(_, event) Safe(Event, self, event) end)
    for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
        "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ITEM_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED", "MERCHANT_UPDATE",
        "BAG_UPDATE_DELAYED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_LOADED", "PLAYER_LOGOUT" }) do
        self:RegisterEvent(event)
    end
    HookFrames()
    ns.Log("windows: ready")
end
