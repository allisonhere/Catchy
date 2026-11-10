-- Catchy: Outfits page
-- Pick the outfit manager, see the fishing outfit and what it is worth, and switch to it.
-- The swap logic stays in FishingOutfitManager / FishingOutfitFrame; this only shows it.
-- Choosing which items go in the outfit is still done in the classic window.
local addonName, FBI = ...
local FBConstants = FBI.FBConstants
local Settings = FBI.Settings
if not Settings then return end

local K = Settings.Kit
local Tex, Text, Border, FlatButton, W, C, AC =
    K.Tex, K.Text, K.Border, K.FlatButton, K.W, K.C, K.AC

local SLOT_ORDER = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
}
local ICON, GAP, PER_ROW = 38, 8, 12
local WIDTH = K.COL_W * 2 + K.COL_GAP

local function EquipmentSetsPanel()
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(WIDTH, 250)
    local heading = Text(f, 12, C.text)
    heading:SetPoint("TOPLEFT", 0, 0)
    heading:SetText("BLIZZARD EQUIPMENT SETS")
    local note = Text(f, 11, C.muted)
    note:SetPoint("TOPLEFT", 0, -20)
    note:SetText("Equip a set directly, or save what you are wearing as Catchy.")

    local rows = {}
    for i = 1, 6 do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(WIDTH, 30)
        row:SetPoint("TOPLEFT", 0, -45 - (i - 1) * 33)
        row.bg = Tex(row, "BACKGROUND", C.card); row.bg:SetAllPoints()
        row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(22, 22); row.icon:SetPoint("LEFT", 5, 0)
        row.name = Text(row, 12); row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
        row.status = Text(row, 10, C.muted); row.status:SetPoint("RIGHT", -82, 0)
        row.use = FlatButton(row, "EQUIP", 68, 22, function()
            if row.data and FBI.GearSets:Equip(row.data.id) then
                C_Timer.After(0.4, function() if f.Refresh then f:Refresh() end end)
            end
        end)
        row.use:SetPoint("RIGHT", -4, 0)
        rows[i] = row
    end

    function f:Refresh()
        local sets = FBI.GearSets and FBI.GearSets:List() or {}
        for i, row in ipairs(rows) do
            local data = sets[i]
            row.data = data
            row:SetShown(data ~= nil)
            if data then
                row.icon:SetTexture(data.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText(data.name or "Unnamed set")
                row.status:SetText(data.equipped and "|cff45df8fEQUIPPED|r" or string.format("%d/%d", data.worn, data.total))
                row.use:SetShown(not data.equipped)
            end
        end
    end
    f:Refresh()
    return f
end

local function Manager() return FBEnvironment and FBEnvironment.OutfitManager end

local function ManagerNames()
    local names = {}
    for name in pairs(FBEnvironment and FBEnvironment.OutfitManagers or {}) do names[#names + 1] = name end
    table.sort(names)
    return names
end

local function SlotTitle(slot)
    return _G[string.upper(slot)] or slot
end

local function Tip(button, slot, info)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if info.link then
        GameTooltip:SetHyperlink(info.link)
    elseif info.item then
        GameTooltip:SetHyperlink("item:" .. info.item)
    else
        GameTooltip:SetText(SlotTitle(slot))
    end
    local frame = _G.FB_OutfitFrame
    if frame and frame.GetInfo and info.item then
        local _, _, id, enchant = string.find(info.item, "^(%d+):(%d+)")
        local points = FBEnvironment.OutfitManager.ItemStylePoints(id, enchant)
        if points and points > 0 and frame.ItemStyleString then
            GameTooltip:AddLine(frame.ItemStyleString(true, points))
        end
    end
    GameTooltip:Show()
end

-- The outfit as a grid of item icons.
local function OutfitGrid(outfit)
    local slots = {}
    local seen = {}
    for _, slot in ipairs(SLOT_ORDER) do
        local info = outfit and outfit[slot]
        if info and info.item then slots[#slots + 1] = slot; seen[slot] = true end
    end
    for slot, info in pairs(outfit or {}) do
        if not seen[slot] and info.item then slots[#slots + 1] = slot end
    end

    local f = CreateFrame("Frame", nil, nil)
    local rows = math.max(1, math.ceil(#slots / PER_ROW))
    f:SetSize(WIDTH, rows * (ICON + GAP))
    if #slots == 0 then
        local empty = Text(f, 12, C.muted)
        empty:SetPoint("TOPLEFT", 0, -4)
        empty:SetText("No fishing outfit yet. Equip a fishing pole and your best fishing gear, then open this page again.")
        empty:SetWidth(WIDTH)
        function f:Refresh() end
        return f, 30
    end
    for i, slot in ipairs(slots) do
        local info = outfit[slot]
        local b = CreateFrame("Button", nil, f)
        b:SetSize(ICON, ICON)
        b:SetPoint("TOPLEFT", ((i - 1) % PER_ROW) * (ICON + GAP), -math.floor((i - 1) / PER_ROW) * (ICON + GAP))
        Tex(b, "BACKGROUND", C.field):SetAllPoints()
        local border = Border(b, { 1, 1, 1, 0.12 })
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexture(info.texture)
        b:SetScript("OnEnter", function(self)
            border:SetColor(AC[1], AC[2], AC[3], 0.9)
            Tip(self, slot, info)
        end)
        b:SetScript("OnLeave", function()
            border:SetColor(1, 1, 1, 0.12)
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function()
            if IsShiftKeyDown() and info.link and ChatEdit_InsertLink then ChatEdit_InsertLink(info.link) end
        end)
    end
    function f:Refresh() end
    return f, rows * (ICON + GAP)
end

local function BuildOutfits(p)
    p:Section("Outfits", "Swap between your normal gear and your fishing outfit.")

    local names = ManagerNames()
    local manager = Manager()
    if #names == 0 or not manager then
        p:Paragraph("No outfit manager is available.", 0, { 1, 0.45, 0.45 })
        return
    end

    if #names == 1 then
        p:Paragraph("Outfit manager: " .. names[1], 0, C.text)
    else
        local items = {}
        for _, name in ipairs(names) do items[#items + 1] = { value = name, label = name } end
        p:Add(W.Dropdown((FBConstants.OUTFITS or "Outfits") .. " manager", items,
            function() return manager.CurrentManager() end,
            function(value)
                manager.ChooseManager(value)
                Settings:Open("outfits")
            end,
            "Which addon manages your fishing outfit."), 48)
        p:Newline()
    end

    p:Button(FB_ODFConstants and FB_ODFConstants.SWITCHOUTFIT or "Switch outfit", function()
        manager.Switch()
    end, FB_ODFConstants and FB_ODFConstants.SWITCHOUTFIT_INFO, 160)

    local frame = _G.FB_OutfitFrame
    if manager.CurrentManager() == EQUIPMENT_MANAGER and FBI.GearSets then
        p:Section("Equipment Manager", "Use Blizzard equipment sets without leaving Catchy.")
        p:Button("Save current gear as Catchy", function()
            if FBI.GearSets:SaveCatchy() then Settings:Open("outfits") end
        end, "Overwrite or create the Catchy equipment set from everything you are currently wearing.", 220)
        p:Newline()
        p:Add(EquipmentSetsPanel(), 250, true)
    end
    if frame and frame.GetInfo and manager.CurrentManager() == "OutfitDisplayFrame" then
        local outfit, skill, style = frame.GetInfo()
        p:Section("Fishing outfit")
        local grid, height = OutfitGrid(outfit)
        p:Add(grid, height, true)
        local consts = FB_ODFConstants or {}
        local bonus = skill >= 0 and ("+" .. skill) or tostring(skill)
        p:Paragraph((consts.CONFIG_SKILL_TEXT or "Fishing skill: ") .. bonus
            .. "     " .. (consts.CONFIG_STYLISH_TEXT or "Style: ") .. style, 0, C.text)
        p:Button("Edit outfit in the classic window", function()
            if FBI.ToggleCatchyFrameClassic then FBI:ToggleCatchyFrameClassic("FishingOutfitFrame") end
            Settings:Close()
        end, "Choose which items go in the outfit.", 220)
        p:Newline()
        p:Section("Outfit options")
        p:Options({ option = "OutfitDisplay" })
    end
end

Settings:SetPage({ section = "fishing", key = "outfits", label = FBConstants.OUTFITS or "Outfits", order = 2,
    build = BuildOutfits })
