-- ===============================================================
-- Vibes.lua - the two controller sets for each cozy activity.
-- This is only layout data; Binder is responsible for writing it.
-- ===============================================================

local _, ns = ...
local ALWAYS = {
    PAD1 = "JUMP", PADRSHOULDER = "INTERACTTARGET", PADRTRIGGER = "TARGETNEARESTENEMY",
    PADLSTICK = "TOGGLEAUTORUN", PADFORWARD = "TOGGLEGAMEMENU", PADBACK = "COZYCOUCH_TOGGLEMENU",
}
local FIGHT = {
    PAD2 = "ACTIONBUTTON1", PAD3 = "ACTIONBUTTON2", PAD4 = "ACTIONBUTTON3", PADDUP = "ACTIONBUTTON4",
    PADDRIGHT = "ACTIONBUTTON5", PADDDOWN = "ACTIONBUTTON6", PADDLEFT = "ACTIONBUTTON7", PADLSHOULDER = "ACTIONBUTTON8",
}
local FARMING = {
    PAD2 = "TOGGLEGAMEMENU", PAD3 = "OPENALLBAGS", PAD4 = "TOGGLEWORLDMAP", PADDUP = "ACTIONBUTTON9",
    PADDRIGHT = "ACTIONBUTTON10", PADDDOWN = "SITORSTAND", PADDLEFT = "ACTIONBUTTON11", PADLSHOULDER = "ACTIONBUTTON12",
}
local QUESTING = {
    PAD2 = "TOGGLEGAMEMENU", PAD3 = "OPENALLBAGS", PAD4 = "TOGGLEQUESTLOG", PADDUP = "ACTIONBUTTON9",
    PADDRIGHT = "ACTIONBUTTON10", PADDDOWN = "ACTIONBUTTON11", PADDLEFT = "TOGGLEWORLDMAP", PADLSHOULDER = "ACTIONBUTTON12",
}
ns.Vibes = {
    { name = "Vibe Farming", top = "calm", calm = FARMING, icon = "icon_gather",
      labels = { A = "Jump", B = "Close", X = "Bags", Y = "Map" } },
    { name = "Questing", top = "calm", calm = QUESTING, icon = "icon_book",
      labels = { A = "Jump", B = "Close", X = "Bags", Y = "Quest log" } },
    { name = "Combat", top = "fight", calm = QUESTING, icon = "icon_sword",
      labels = { A = "Jump", B = "Slot 1", X = "Slot 2", Y = "Slot 3" } },
}

-- ---------------------------------------------------------------
-- LT is native Shift, so both sets work without combat-time rewiring.
-- ---------------------------------------------------------------
function ns.Vibes:BuildBindings(index)
    local vibe = self[index] or self[1]
    local wanted = {}
    for chord, action in pairs(ALWAYS) do
        wanted[chord], wanted["SHIFT-" .. chord] = action, action
    end
    local top = vibe.top == "fight" and FIGHT or vibe.calm
    local other = vibe.top == "fight" and vibe.calm or FIGHT
    for chord, action in pairs(top) do wanted[chord] = action end
    for chord, action in pairs(other) do wanted["SHIFT-" .. chord] = action end
    return wanted
end
