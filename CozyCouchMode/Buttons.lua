-- ===============================================================
-- Buttons.lua - choose spells, items, and handy actions from the couch.
-- The left side reads your real bindings; the parchment offers choices.
-- Only out-of-combat cursor APIs edit slots. Binder owns handy bindings.
-- ===============================================================

local _, ns = ...
local Buttons = { set = "calm", focus = "UP" }
ns.Buttons = Buttons
local MEDIA = "Interface\\AddOns\\CozyCouchMode\\Media\\"
local DISPLAY = MEDIA .. "Fonts\\MelonHoney.ttf"
local LABEL = "Fonts\\FRIZQT__.TTF"
local MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ICONS = "Interface\\Icons\\"
local LIGHT, DIM = { 0.96, 0.91, 0.78 }, { 0.72, 0.66, 0.53 }
local GOLD, INK, SOFT = { 1, 0.84, 0.44 }, { 0.23, 0.14, 0.06 }, { 0.36, 0.26, 0.16 }
local COLORS = {
    A = { 0.49, 0.88, 0.56 }, B = { 0.95, 0.48, 0.43 },
    X = { 0.47, 0.68, 0.96 }, Y = { 0.95, 0.83, 0.38 },
}
local SOCKETS = {
    { key = "UP", chord = "PADDUP", name = "D-pad Up", x = 110, y = 96 },
    { key = "RIGHT", chord = "PADDRIGHT", name = "D-pad Right", x = 164, y = 150 },
    { key = "DOWN", chord = "PADDDOWN", name = "D-pad Down", x = 110, y = 204 },
    { key = "LEFT", chord = "PADDLEFT", name = "D-pad Left", x = 56, y = 150 },
    { key = "LB", chord = "PADLSHOULDER", name = "LB", x = 178, y = 70, small = true },
    { key = "RB", chord = "PADRSHOULDER", name = "RB", x = 274, y = 70, small = true, locked = "Interact" },
    { key = "Y", chord = "PAD4", name = "Y", x = 342, y = 96 },
    { key = "B", chord = "PAD2", name = "B", x = 396, y = 150 },
    { key = "A", chord = "PAD1", name = "A", x = 342, y = 204, locked = "Jump" },
    { key = "X", chord = "PAD3", name = "X", x = 288, y = 150 },
}
local NAV = {
    UP = { right = "LB", down = "LEFT", left = "LEFT" },
    LEFT = { up = "UP", right = "DOWN", down = "DOWN" },
    DOWN = { up = "LEFT", right = "RIGHT", left = "LEFT" },
    RIGHT = { up = "UP", left = "DOWN", right = "X", down = "DOWN" },
    LB = { left = "UP", right = "RB", down = "RIGHT" },
    RB = { left = "LB", right = "Y", down = "X" },
    Y = { left = "RB", down = "X", right = "B" },
    X = { up = "Y", left = "RIGHT", right = "A", down = "A" },
    B = { up = "Y", left = "A", down = "A" },
    A = { up = "X", left = "X", right = "B" },
}
local HANDY = {
    { action = "OPENALLBAGS", name = "Bags", icon = ICONS .. "INV_Misc_Bag_08" },
    { action = "TOGGLEWORLDMAP", name = "Map", icon = ICONS .. "INV_Misc_Map_01" },
    { action = "TOGGLEQUESTLOG", name = "Quest log", icon = ICONS .. "INV_Misc_Book_09" },
    { action = "TOGGLECHARACTER0", name = "Character", icon = ICONS .. "INV_Chest_Cloth_17" },
    { action = "TOGGLESPELLBOOK", name = "Spellbook", icon = ICONS .. "INV_Misc_Book_11" },
    { action = "TOGGLETALENTS", name = "Talents", icon = ICONS .. "Ability_Marksmanship" },
    { action = "SITORSTAND", name = "Sit / stand", icon = ICONS .. "Spell_Nature_Sleep" },
    { action = "TOGGLEGAMEMENU", name = "Close / game menu", icon = ICONS .. "INV_Misc_Gear_01" },
    { action = "TOGGLESOCIAL", name = "Friends", icon = ICONS .. "INV_Letter_15" },
    { action = "TOGGLEAUTORUN", name = "Auto-run", icon = ICONS .. "Ability_Rogue_Sprint" },
}
local handyByAction, cache = {}, {}
for _, entry in ipairs(HANDY) do entry.kind = "handy"; handyByAction[entry.action] = entry end

-- ---------------------------------------------------------------
-- Read live slots without letting secret values enter comparisons.
-- ---------------------------------------------------------------
local function Safe(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return value
end

local function ValidSlot(slot)
    slot = Safe(slot)
    return type(slot) == "number" and slot >= 1 and slot <= 180 and slot == math.floor(slot)
end

local function Context()
    local index = ns.db.activePreset or 1
    local vibe = ns.Vibes[index] or ns.Vibes[1]
    return index, Buttons.set == vibe.top and "" or "SHIFT-"
end

local function HandyName(action)
    local entry = handyByAction[action]
    return entry and entry.name or Safe(_G["BINDING_NAME_" .. action]) or action,
        entry and entry.icon or ICONS .. "INV_Misc_QuestionMark"
end

local function ReadSocket(info)
    local _, prefix = Context()
    local action = Safe(GetBindingAction(prefix .. info.chord)) or ""
    local number = action:match("^ACTIONBUTTON(%d+)$")
    if info.locked then
        return { kind = "locked", name = info.locked,
            icon = info.key == "A" and ICONS .. "Ability_Rogue_Sprint" or "Interface\\CURSOR\\Interact" }
    end
    if not number then
        local name, icon = HandyName(action)
        return { kind = "handy", name = name, icon = icon, action = action }
    end
    local button = _G["ActionButton" .. number]
    local slot = Safe(button and button.action)
    if not ValidSlot(slot) then slot = tonumber(number) end
    local state = { kind = "slot", slot = slot, name = "Slot " .. number }
    if not ValidSlot(slot) then return state end
    state.icon = Safe(GetActionTexture(slot))
    local kind, id = GetActionInfo(slot)
    kind, id = Safe(kind), Safe(id)
    if not kind then state.name = "Empty"; state.empty = true; return state end
    local name
    if kind == "spell" and id and C_Spell and type(C_Spell.GetSpellName) == "function" then
        name = Safe(C_Spell.GetSpellName(id))
    elseif kind == "item" and id and C_Item and type(C_Item.GetItemNameByID) == "function" then
        name = Safe(C_Item.GetItemNameByID(id))
    elseif type(GetActionText) == "function" then
        name = Safe(GetActionText(slot))
    end
    if name and name ~= "" then state.name = name end
    return state
end

-- ---------------------------------------------------------------
-- Picker lists are built on demand, and forgotten when game data changes.
-- ---------------------------------------------------------------
local function Spells()
    local entries, positions = {}, {}
    if not C_SpellBook or type(C_SpellBook.GetNumSpellBookSkillLines) ~= "function" then
        ns.Log("buttons: no C_SpellBook")
        return { { name = "Spellbook not available" } }
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for i = 1, Safe(C_SpellBook.GetNumSpellBookSkillLines()) or 0 do
        local line = Safe(C_SpellBook.GetSpellBookSkillLineInfo(i))
        if line and not Safe(line.shouldHide) and (not Safe(line.offSpecID) or Safe(line.offSpecID) == 0) then
            local offset, count = Safe(line.itemIndexOffset) or 0, Safe(line.numSpellBookItems) or 0
            for slot = offset + 1, offset + count do
                local info = Safe(C_SpellBook.GetSpellBookItemInfo(slot, bank))
                if info and not Safe(info.isPassive) and Safe(info.itemType) == spellType and Safe(info.name) then
                    local entry = { kind = "spell", name = info.name, sub = Safe(info.subName), icon = Safe(info.iconID),
                        bookSlot = slot, bank = bank, spellID = Safe(info.spellID) }
                    -- Later book entries carry the highest rank of the same spell.
                    local position = positions[entry.name] or (#entries + 1)
                    entries[position], positions[entry.name] = entry, position
                end
            end
        end
    end
    return entries
end

local function Items()
    local entries, seen = {}, {}
    if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function"
        or type(C_Container.GetContainerItemInfo) ~= "function" or not C_Item
        or type(C_Item.GetItemSpell) ~= "function" then return entries end
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = Safe(C_Container.GetContainerItemInfo(bag, slot))
            local id = info and Safe(info.itemID)
            if id and not seen[id] and Safe(C_Item.GetItemSpell(id)) then
                local name = Safe(info.itemName)
                if not name and type(C_Item.GetItemNameByID) == "function" then name = Safe(C_Item.GetItemNameByID(id)) end
                local link = Safe(info.hyperlink)
                name = name or (link and link:match("%[(.-)%]"))
                entries[#entries + 1] = { kind = "item", name = name or ("Item " .. id), icon = Safe(info.iconFileID), itemID = id }
                seen[id] = true
            end
        end
    end
    return entries
end

local function List(category)
    if category == "Handy actions" then return HANDY end
    if not cache[category] then cache[category] = category == "Spells" and Spells() or Items() end
    return cache[category]
end

-- ---------------------------------------------------------------
-- Drawing helpers only create and change Cozy-owned regions.
-- ---------------------------------------------------------------
local function At(region, parent, x, y)
    region:ClearAllPoints()
    region:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
end

local function Frame(parent, width, height, x, y)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, height)
    At(frame, parent, x, y)
    return frame
end

local function Picture(parent, file, width, height, layer, sublevel)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
    texture:SetSize(width, height)
    texture:SetPoint("CENTER")
    if file then texture:SetTexture(MEDIA .. file .. ".tga") end
    return texture
end

local function Text(parent, text, size, color, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont(font or LABEL, size, "")
    label:SetTextColor(unpack(color))
    label:SetText(text)
    At(label, parent, x, y)
    return label
end

local function Mask(parent, texture)
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(texture)
    mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    texture:AddMaskTexture(mask)
    return mask
end

local function Gradient(texture, direction, first, last)
    texture:SetColorTexture(1, 1, 1)
    texture:SetGradient(direction, CreateColor(unpack(first)), CreateColor(unpack(last)))
end

-- Round ends and a straight middle keep the pill's corners round at any width.
local function Capsule(parent, width, height, first, last, layer)
    local pieces = {}
    for i = 1, 3 do
        local texture = Picture(parent, nil, i == 2 and width - height or height, height, layer)
        texture:SetPoint("CENTER", parent, "CENTER", (i - 2) * (width - height) / 2, 0)
        Gradient(texture, "VERTICAL", first, last or first)
        if i ~= 2 then Mask(parent, texture) end
        pieces[i] = texture
    end
    function pieces:SetShown(shown)
        for _, texture in ipairs(self) do texture:SetShown(shown) end
    end
    return pieces
end

local function Gem(parent, key, size, x, y)
    local gem = Frame(parent, size, size, x, y)
    Picture(gem, "gem", size, size, "BACKGROUND")
    if COLORS[key] or key == "LB" or key == "RB" then
        Text(gem, key, #key > 1 and 8 or 11, COLORS[key] or LIGHT, size / 2, size / 2)
    else
        Picture(gem, "glyph_" .. key:lower(), 12, 12, "OVERLAY")
    end
    return gem
end

local function BuildSocket(parent, info)
    local size, iconSize = info.small and 42 or 58, info.small and 32 or 46
    local socket = Frame(parent, size, size, info.x, info.y)
    socket.info = info
    socket.glow = Picture(socket, "glow_round", size + 40, size + 40, "BACKGROUND", -1)
    socket.glow:SetVertexColor(1, 0.78, 0.35, 0.45)
    Picture(socket, "sign_socket", size, size, "BACKGROUND")
    socket.icon = Picture(socket, nil, iconSize, iconSize)
    socket.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = Mask(socket, socket.icon)
    Picture(socket, "socket_shade", iconSize, iconSize, "ARTWORK", 1):AddMaskTexture(mask)
    Picture(socket, "ring", size + 10, size + 10, "OVERLAY")
    socket.rim = Picture(socket, "ring_thin", size + 18, size + 18, "OVERLAY", 1)
    socket.rim:SetVertexColor(1, 0.84, 0.44, 0.95)
    socket.empty = Text(socket, "+", 22, LIGHT, size / 2, size / 2)
    socket.empty:SetAlpha(0.35)
    Gem(socket, info.key, 22, size - 4, size - 4)
    socket:SetAlpha(info.locked and 0.55 or 1)
    -- Build once; LT only stops and replays this group.
    socket.fade = socket:CreateAnimationGroup()
    local alpha = socket.fade:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0.3)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.14)
    return socket
end

local function BuildSwitch(self)
    local pill = Frame(self.layout, 224, 32, 226, 16)
    Capsule(pill, 224, 32, { 0.42, 0.31, 0.18, 1 }, nil, "BACKGROUND")
    Capsule(pill, 222, 30, { 0.10, 0.07, 0.04, 1 }, nil, "BORDER")
    Text(pill, "LT", 10.5, GOLD, 20, 16)
    self.setChips = {}
    for i, name in ipairs({ "CALM", "FIGHT" }) do
        local chip = Frame(pill, 86, 26, 83 + (i - 1) * 88, 16)
        chip.fill = Capsule(chip, 86, 26, { 0.23, 0.14, 0.07, 1 }, { 0.35, 0.23, 0.11, 1 }, "BACKGROUND")
        chip.label = Text(chip, name, 11.5, DIM, 43, 13)
        self.setChips[i] = chip
    end
end

local function BuildCard(self)
    local card = Frame(self.frame, 380, 312, 700, 386)
    Picture(card, "parchment", 380, 312, "BACKGROUND")
    self.help = Frame(card, 380, 312, 190, 156)
    Text(self.help, "Your buttons", 26, INK, 190, 52, DISPLAY)
    for i, words in ipairs({
        "Pick a button with the D-pad, then press A to choose what it does.",
        "Fight buttons hold your spells: they're your action bar, shared by every vibe.",
        "Calm buttons hold handy things: your mount, hearthstone, food, bags and map.",
    }) do
        local label = Text(self.help, words, 14, SOFT, 190, 104 + (i - 1) * 68)
        label:SetWidth(312)
        label:SetJustifyH("CENTER")
    end
    self.picker = Frame(card, 380, 312, 190, 156)
    self.pickTitle = Text(self.picker, "", 22, INK, 190, 34, DISPLAY)
    self.categories = {}
    self.lb = Text(self.picker, "LB", 10.5, SOFT, 55, 70)
    self.rb = Text(self.picker, "RB", 10.5, SOFT, 325, 70)
    for i = 1, 2 do
        local chip = Frame(self.picker, 114, 26, 129 + (i - 1) * 122, 70)
        chip.fill = Picture(chip, nil, 114, 26, "BACKGROUND")
        chip.label = Text(chip, "", 10.5, SOFT, 57, 13)
        self.categories[i] = chip
    end
    self.rows = {}
    for i = 1, 6 do
        local row = Frame(self.picker, 322, 34, 185, 96 + (i - 1) * 34 + 17)
        row.highlight = Picture(row, nil, 322, 34, "BACKGROUND")
        Gradient(row.highlight, "HORIZONTAL", { 0.94, 0.72, 0.24, 0.38 }, { 0.94, 0.72, 0.24, 0.10 })
        row.icon = Picture(row, nil, 26, 26)
        At(row.icon, row, 23, 17)
        Mask(row, row.icon)
        row.name = Text(row, "", 15, INK, 137, 17)
        row.name:SetWidth(178)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.sub = Text(row, "", 12.5, SOFT, 272, 17)
        row.sub:SetWidth(80)
        row.sub:SetJustifyH("RIGHT")
        row.sub:SetWordWrap(false)
        self.rows[i] = row
    end
    self.track = Frame(self.picker, 4, 204, 355, 198)
    Picture(self.track, nil, 4, 204, "BACKGROUND"):SetColorTexture(0.36, 0.26, 0.16, 0.18)
    self.thumb = Picture(self.track, nil, 4, 204)
    self.thumb:SetColorTexture(0.36, 0.26, 0.16, 0.6)
end

local function BuildHints(self)
    self.hints = {}
    for i = 1, 4 do
        local chip = Frame(self.frame, 130, 52, 460 + (i - 2.5) * 146, 574)
        Picture(chip, "chip", 130, 52, "BACKGROUND")
        chip.label = Text(chip, "", 11, LIGHT, 86, 26)
        if i == 1 then
            At(Picture(chip, "glyph_dpad", 24, 24), chip, 26, 26)
        else
            chip.gem = Gem(chip, i == 2 and "A" or i == 3 and "X" or "B", 28, 26, 26)
            if i == 3 then chip.shoulders = Text(chip, "LB RB", 9, GOLD, 26, 26) end
        end
        self.hints[i] = chip
    end
end

function Buttons:Build(menu)
    if self.frame then return end
    self.frame = CreateFrame("Frame", nil, menu)
    self.frame:SetAllPoints(menu)
    self.frame:SetFrameLevel(menu:GetFrameLevel() + 3)
    self.frame:Hide()
    self.layout = Frame(self.frame, 452, 310, 260, 389)
    for _, x in ipairs({ 110, 342 }) do At(Picture(self.layout, "base_disc", 178, 178, "BACKGROUND"), self.layout, x, 150) end
    self.sockets = {}
    for _, info in ipairs(SOCKETS) do self.sockets[info.key] = BuildSocket(self.layout, info) end
    BuildSwitch(self)
    self.what = Text(self.layout, "", 17, LIGHT, 226, 268)
    self.where = Text(self.layout, "", 13.5, DIM, 226, 290)
    BuildCard(self)
    BuildHints(self)
    self.frame:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" or event == "BAG_UPDATE_DELAYED" then
            cache = {}
            -- Redraw an open picker now, so A always places the row the player can see.
            if self.picking and self.frame:IsShown() then self:Refresh() end
        elseif self.frame:IsShown() then
            self:Refresh()
        end
    end)
    for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "SPELLS_CHANGED", "BAG_UPDATE_DELAYED" }) do
        pcall(self.frame.RegisterEvent, self.frame, event)
    end
    self.ready = true  -- only a fully built editor is ever shown or driven
end

-- ---------------------------------------------------------------
-- Refresh reads every socket; it never edits the player's action bar.
-- ---------------------------------------------------------------
local function RefreshPicker(self)
    local names = self.sockets[self.focus].state.kind == "slot" and { "Spells", "Items" } or { "Handy actions" }
    self.category = math.min(self.category or 1, #names)
    self.categoryNames = names
    local entries = List(names[self.category])
    self.row = math.max(1, math.min(self.row or 1, #entries))
    self.pickTitle:SetText("Choose for " .. self.sockets[self.focus].info.name)
    self.lb:SetShown(#names > 1)
    self.rb:SetShown(#names > 1)
    for i, chip in ipairs(self.categories) do
        chip:SetShown(names[i] ~= nil)
        At(chip, self.picker, #names == 1 and 190 or 129 + (i - 1) * 122, 70)
        chip.label:SetText(names[i] or "")
        chip.label:SetTextColor(unpack(i == self.category and LIGHT or SOFT))
        chip.fill:SetColorTexture(0.36, 0.23, 0.10, i == self.category and 1 or 0.10)
    end
    local start = math.max(0, math.min(self.row - 4, #entries - 6))
    for i, row in ipairs(self.rows) do
        local entry = entries[start + i]
        row:SetShown(entry ~= nil or (i == 1 and #entries == 0))
        row.highlight:SetShown(entry ~= nil and start + i == self.row)
        row.icon:SetTexture(entry and entry.icon)
        row.icon:SetShown(entry ~= nil and entry.icon ~= nil)
        row.name:SetText(entry and entry.name or "No choices available")
        row.name:SetWidth(entry and entry.sub and entry.sub ~= "" and 178 or 264)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", 48, 0)
        row.sub:SetText(entry and entry.sub or "")
    end
    self.thumb:SetShown(#entries > 6)
    if #entries > 6 then
        local height = math.max(20, 204 * 6 / #entries)
        self.thumb:SetHeight(height)
        At(self.thumb, self.track, 2, height / 2 + (204 - height) * start / (#entries - 6))
    end
end

function Buttons:Refresh()
    if not self.ready then return end
    for key, socket in pairs(self.sockets) do
        local state = ReadSocket(socket.info)
        socket.state = state
        socket.icon:SetTexture(state.icon)
        socket.icon:SetShown(state.icon ~= nil and not state.empty)
        socket.empty:SetShown(state.empty == true)
        socket.glow:SetShown(key == self.focus)
        socket.rim:SetShown(key == self.focus)
    end
    local socket = self.sockets[self.focus]
    local state, info = socket.state, socket.info
    self.what:SetText(info.name .. ": " .. state.name .. (info.locked and " (always)" or ""))
    local where = (self.set == "fight" and "Fight" or "Calm") .. " set · "
    if info.locked then
        where = "Locked so you can always jump and interact."
    elseif state.kind == "slot" then
        where = where .. "action bar slot " .. state.slot .. (self.set == "fight" and " (shared by every vibe)" or "")
    else
        where = where .. "handy action"
    end
    self.where:SetText(where)
    for i, chip in ipairs(self.setChips) do
        local on = (i == 1 and self.set == "calm") or (i == 2 and self.set == "fight")
        chip.fill:SetShown(on)
        chip.label:SetTextColor(unpack(on and GOLD or DIM))
    end
    self.help:SetShown(not self.picking)
    self.picker:SetShown(self.picking == true)
    if self.picking then RefreshPicker(self) end
    local hints = self.picking and { "BROWSE", "PLACE", "TABS", "BACK" } or { "MOVE", "CHANGE", "CLEAR", "CLOSE" }
    for i, chip in ipairs(self.hints) do chip.label:SetText(hints[i]) end
    self.hints[3].gem:SetShown(not self.picking)
    self.hints[3].shoulders:SetShown(self.picking == true)
end

function Buttons:Show()
    if not self.ready then return end
    self.frame:Show()
    self:Refresh()
end

function Buttons:Hide()
    self.picking = false
    if self.frame then self.frame:Hide() end
end

function Buttons:IsPicking() return self.picking == true end

function Buttons:ToggleSet()
    if not self.ready then return end
    self.set = self.set == "calm" and "fight" or "calm"
    self.picking = false
    self:Refresh()
    for _, socket in pairs(self.sockets) do socket.fade:Stop(); socket.fade:Play() end
end

-- ---------------------------------------------------------------
-- Mutations have their own combat guards, even if the menu is hidden.
-- ---------------------------------------------------------------
local function Locked(info)
    ns.Toast(info.name .. " stays " .. info.locked .. ", so you can't get stuck.")
end

local function Failed(reason)
    ns.Log("buttons: " .. tostring(reason))
    ns.Toast("Couldn't place that.")
end

local function Place(self)
    if InCombatLockdown() then ns.Toast("That can wait until after combat."); return end
    local socket = self.sockets[self.focus]
    local state, info = ReadSocket(socket.info), socket.info
    if info.locked then Locked(info); return end
    local entry = List(self.categoryNames[self.category])[self.row]
    if not entry or not entry.kind then return end
    if state.kind == "slot" then
        if not ValidSlot(state.slot) then
            Failed("invalid action slot")
        else
            ClearCursor()
            local placed = false
            local ok, err = pcall(function()
                if entry.kind == "spell" then
                    if C_SpellBook and type(C_SpellBook.PickupSpellBookItem) == "function" then
                        C_SpellBook.PickupSpellBookItem(entry.bookSlot, entry.bank)
                    elseif C_Spell and type(C_Spell.PickupSpell) == "function" then
                        C_Spell.PickupSpell(entry.spellID)
                    end
                elseif entry.kind == "item" then
                    if C_Item and type(C_Item.PickupItem) == "function" then C_Item.PickupItem(entry.itemID)
                    elseif type(PickupItem) == "function" then PickupItem(entry.itemID) end
                end
                if Safe(GetCursorInfo()) then PlaceAction(state.slot); placed = true end
            end)
            ClearCursor()
            local kind, id = GetActionInfo(state.slot)
            kind, id = Safe(kind), Safe(id)
            -- Spells may be stored under a related spell ID (ranks/overrides), so only items need an exact ID match.
            local idOk = entry.kind == "spell" or (id ~= nil and id == entry.itemID)
            if ok and placed and kind == entry.kind and idOk then
                ns.Toast(entry.name .. " is on " .. info.name .. ".")
            else
                Failed(err or "action read-back did not match the choice")
            end
        end
    elseif entry.kind == "handy" then
        local index, prefix = Context()
        ns.db.customBindings = ns.db.customBindings or {}
        ns.db.customBindings[index] = ns.db.customBindings[index] or {}
        ns.db.customBindings[index][prefix .. info.chord] = entry.action
        ns.Binder:Apply("buttons edit")
        -- The Binder can skip (ConsolePort on, after /cozy reset, or a key the player bound themselves).
        if GetBindingAction(prefix .. info.chord) == entry.action then
            ns.Toast(entry.name .. " is on " .. info.name .. ".")
        else
            Failed("binding not applied for " .. prefix .. info.chord)
        end
    end
    self.picking = false
    self:Refresh()
end

local function Clear(self)
    if InCombatLockdown() then ns.Toast("That can wait until after combat."); return end
    local info = self.sockets[self.focus].info
    if info.locked then Locked(info); return end
    local state = ReadSocket(info)
    if state.kind == "slot" then
        if not ValidSlot(state.slot) then Failed("invalid action slot"); return end
        local ok, err = pcall(PickupAction, state.slot)
        ClearCursor()
        if ok then ns.Toast(info.name .. " is empty now.") else Failed(err) end
    else
        local index, prefix = Context()
        local custom = ns.db.customBindings and ns.db.customBindings[index]
        if custom then custom[prefix .. info.chord] = nil end
        ns.Binder:Apply("buttons reset")
        local default = ns.Vibes:BuildBindings(index)[prefix .. info.chord] or ""
        local name = HandyName(default)
        ns.Toast(info.name .. " is back to " .. name .. ".")
    end
    self:Refresh()
end

function Buttons:HandleNav(action)
    if not self.ready then return false end
    if self.picking then
        -- Rebuild an invalidated list before using its selection.
        self:Refresh()
        if action == "UP" or action == "DOWN" then
            local count = #List(self.categoryNames[self.category])
            self.row = math.max(1, math.min(count, self.row + (action == "UP" and -1 or 1)))
        elseif action == "TABPREV" or action == "TABNEXT" then
            self.category = (self.category - 1 + (action == "TABPREV" and -1 or 1)) % #self.categoryNames + 1
            self.row = 1
        elseif action == "CHOOSE" then Place(self)
        elseif action == "CLOSE" then self.picking = false
        end
        self:Refresh()
        return true
    end
    if action == "LEFT" or action == "RIGHT" or action == "UP" or action == "DOWN" then
        self.focus = NAV[self.focus][action:lower()] or self.focus
    elseif action == "CHOOSE" then
        local info = self.sockets[self.focus].info
        if info.locked then Locked(info)
        else self.picking = true; self.category = 1; self.row = 1 end
    elseif action == "XBUTTON" then Clear(self)
    elseif action == "YBUTTON" then return true
    else return false end
    self:Refresh()
    return true
end
