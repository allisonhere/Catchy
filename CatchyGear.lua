-- Catchy Gear: the visual editor for Catchy's own equipment manager.
-- A paperdoll with glowing slots, set tabs, and a live readiness meter.
-- Logic and storage live in CatchyGearManager.lua.
local addonName, FBI = ...
local Settings = FBI.Settings
if not (Settings and FBI.Gear) then return end

local Gear = FBI.Gear
local K = Settings.Kit
local Tex, Text, Border, FlatButton, C, AC = K.Tex, K.Text, K.Border, K.FlatButton, K.C, K.AC

local WIDTH = K.COL_W * 2 + K.COL_GAP
local ICON, GAP, PAD = 38, 7, 12
local PANEL_H = PAD * 2 + 8 * ICON + 7 * GAP
local CHIP_W, CHIP_H, CHIP_GAP = 138, 40, 8
local CHIPS_H = (CHIP_H + CHIP_GAP) * 2
local BAR_H = 34
local TOTAL_H = CHIPS_H + PANEL_H + 12 + BAR_H

local LEFT = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local RIGHT = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local WEAPONS = { "MainHandSlot", "SecondaryHandSlot" }

local SHORT = {
    HeadSlot = "HEAD", NeckSlot = "NECK", ShoulderSlot = "SHLD", BackSlot = "BACK", ChestSlot = "CHST",
    ShirtSlot = "SHRT", TabardSlot = "TABD", WristSlot = "WRST", HandsSlot = "HAND", WaistSlot = "WAIST",
    LegsSlot = "LEGS", FeetSlot = "FEET", Finger0Slot = "RING", Finger1Slot = "RING", Trinket0Slot = "TRNK",
    Trinket1Slot = "TRNK", MainHandSlot = "MAIN", SecondaryHandSlot = "OFF",
}

local STATE = {
    worn = { 0.27, 0.87, 0.56, "Equipped" },
    bag = { 1.00, 0.72, 0.22, "In your bags" },
    missing = { 0.92, 0.28, 0.30, "Not found" },
}

local function QualityColor(link)
    local hex = link and string.match(link, "|c%x%x(%x%x%x%x%x%x)")
    if not hex then return 0.6, 0.64, 0.72 end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function Message(text)
    if FBI.Print then FBI:Print("%s", text) end
end

local function BuildStudio()
    local studio = CreateFrame("Frame", nil, nil)
    studio:SetSize(WIDTH, TOTAL_H)
    local selected -- the set being edited

    ------------------------------------------------------------------ set tabs
    local chips = {}
    for i = 1, Gear.MAX_SETS do
        local chip = CreateFrame("Button", nil, studio)
        chip:SetSize(CHIP_W, CHIP_H)
        chip:SetPoint("TOPLEFT", ((i - 1) % 4) * (CHIP_W + CHIP_GAP), -math.floor((i - 1) / 4) * (CHIP_H + CHIP_GAP))
        chip.bg = Tex(chip, "BACKGROUND", C.card)
        chip.bg:SetAllPoints()
        chip.glow = Tex(chip, "BORDER", { 1, 1, 1, 1 })
        chip.glow:SetAllPoints()
        chip.border = Border(chip, { 1, 1, 1, 0.10 })
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(26, 26)
        chip.icon:SetPoint("LEFT", 8, 0)
        chip.name = Text(chip, 12, C.text, "OUTLINE")
        chip.name:SetPoint("TOPLEFT", chip.icon, "TOPRIGHT", 8, -1)
        chip.name:SetWidth(CHIP_W - 54)
        chip.meta = Text(chip, 10, C.muted)
        chip.meta:SetPoint("BOTTOMLEFT", chip.icon, "BOTTOMRIGHT", 8, 0)
        chip:SetScript("OnClick", function(self)
            if self.setName then
                selected = self.setName
                Gear:SetActive(self.setName)
                studio:Refresh()
            end
        end)
        chips[i] = chip
    end

    ------------------------------------------------------------------ paperdoll panel
    local panel = CreateFrame("Frame", nil, studio)
    panel:SetSize(WIDTH, PANEL_H)
    panel:SetPoint("TOPLEFT", 0, -CHIPS_H)
    Tex(panel, "BACKGROUND", C.card):SetAllPoints()
    Border(panel, { 1, 1, 1, 0.10 })
    local wash = Tex(panel, "BACKGROUND", { 1, 1, 1, 1 }, 1)
    wash:SetAllPoints()

    local slotButtons = {}
    local function MakeSlot(slot, x, y)
        local b = CreateFrame("Button", nil, panel)
        b:SetSize(ICON, ICON)
        b:SetPoint("TOPLEFT", x, y)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.glow = Tex(b, "BACKGROUND", { 1, 1, 1, 0.0 }, 1)
        b.glow:SetPoint("TOPLEFT", -4, 4)
        b.glow:SetPoint("BOTTOMRIGHT", 4, -4)
        b.back = Tex(b, "BACKGROUND", C.field, 2)
        b.back:SetAllPoints()
        b.border = Border(b, { 1, 1, 1, 0.12 })
        b.label = Text(b, 9, C.muted)
        b.label:SetPoint("CENTER")
        b.label:SetJustifyH("CENTER")
        b.label:SetText(SHORT[slot])
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        b.dot = Tex(b, "OVERLAY", { 1, 1, 1, 1 })
        b.dot:SetSize(8, 8)
        b.dot:SetPoint("BOTTOMRIGHT", -2, 2)
        b.slot = slot
        b:SetScript("OnEnter", function(self)
            self.border:SetColor(AC[1], AC[2], AC[3], 0.95)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local set = selected and Gear:Get(selected)
            local info = set and set.slots[slot]
            if info and info.link then
                GameTooltip:SetHyperlink(info.link)
                local state = self.state and STATE[self.state]
                if state then GameTooltip:AddLine(state[4], state[1], state[2], state[3]) end
            else
                GameTooltip:SetText(_G[string.upper(slot)] or slot, 1, 1, 1)
                GameTooltip:AddLine("Empty in this set", 0.6, 0.65, 0.72)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Click: use what you are wearing here", 0.45, 0.88, 0.95)
            GameTooltip:AddLine("Right-click: remove from this set", 0.45, 0.88, 0.95)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self.border:SetColor(self.r or 1, self.g or 1, self.b or 1, self.a or 0.12)
            if GameTooltip then GameTooltip:Hide() end
        end)
        b:SetScript("OnClick", function(self, button)
            if not selected then return end
            if button == "RightButton" then
                Gear:SetSlot(selected, slot, nil)
            elseif IsShiftKeyDown and IsShiftKeyDown() and self.link and ChatEdit_InsertLink then
                ChatEdit_InsertLink(self.link)
                return
            else
                local worn = Gear.Capture(slot)
                if not worn then Message("Nothing is worn in that slot.") return end
                Gear:SetSlot(selected, slot, worn)
            end
            studio:Refresh()
        end)
        slotButtons[slot] = b
    end

    local colTop = -PAD
    for i, slot in ipairs(LEFT) do MakeSlot(slot, PAD, colTop - (i - 1) * (ICON + GAP)) end
    for i, slot in ipairs(RIGHT) do MakeSlot(slot, WIDTH - PAD - ICON, colTop - (i - 1) * (ICON + GAP)) end
    local centerX = WIDTH / 2
    MakeSlot(WEAPONS[1], centerX - ICON - 6, -PANEL_H + PAD + ICON)
    MakeSlot(WEAPONS[2], centerX + 6, -PANEL_H + PAD + ICON)

    ------------------------------------------------------------------ hero card (centre)
    local hero = CreateFrame("Frame", nil, panel)
    hero:SetSize(WIDTH - 2 * (PAD + ICON + 18), PANEL_H - 2 * PAD - ICON - 16)
    hero:SetPoint("TOP", panel, "TOP", 0, -PAD)
    local aura = Tex(hero, "BACKGROUND", { 1, 1, 1, 1 }, 2)
    aura:SetAllPoints()
    Border(hero, { 1, 1, 1, 0.06 })

    local heroIcon = hero:CreateTexture(nil, "ARTWORK")
    heroIcon:SetSize(76, 76)
    heroIcon:SetPoint("TOP", 0, -22)
    local ring = Tex(hero, "BORDER", { 1, 1, 1, 1 })
    ring:SetSize(86, 86)
    ring:SetPoint("CENTER", heroIcon, "CENTER")
    local heroName = Text(hero, 20, AC, "OUTLINE")
    heroName:SetPoint("TOP", heroIcon, "BOTTOM", 0, -14)
    heroName:SetWidth(hero:GetWidth() - 20)
    heroName:SetJustifyH("CENTER")
    local heroSub = Text(hero, 11, C.muted)
    heroSub:SetPoint("TOP", heroName, "BOTTOM", 0, -6)
    heroSub:SetWidth(hero:GetWidth() - 20)
    heroSub:SetJustifyH("CENTER")

    local function Stat(label, xOffset)
        local value = Text(hero, 22, C.text, "OUTLINE")
        value:SetPoint("TOP", heroSub, "BOTTOM", xOffset, -26)
        value:SetWidth(120)
        value:SetJustifyH("CENTER")
        local caption = Text(hero, 9, C.muted)
        caption:SetPoint("TOP", value, "BOTTOM", 0, -3)
        caption:SetWidth(120)
        caption:SetJustifyH("CENTER")
        caption:SetText(label)
        return value
    end
    local skillValue = Stat("FISHING SKILL", -70)
    local styleValue = Stat("STYLE POINTS", 70)

    local meter = Tex(hero, "ARTWORK", { 1, 1, 1, 0.07 })
    meter:SetSize(hero:GetWidth() - 60, 8)
    meter:SetPoint("BOTTOM", 0, 56)
    local meterFill = Tex(hero, "OVERLAY", { 1, 1, 1, 1 })
    meterFill:SetHeight(8)
    meterFill:SetPoint("BOTTOMLEFT", meter, "BOTTOMLEFT", 0, 0)
    local meterText = Text(hero, 10, C.muted)
    meterText:SetPoint("BOTTOM", 0, 34)
    meterText:SetWidth(hero:GetWidth() - 20)
    meterText:SetJustifyH("CENTER")

    local empty = Text(hero, 12, C.muted)
    empty:SetPoint("CENTER", 0, 10)
    empty:SetWidth(hero:GetWidth() - 60)
    empty:SetJustifyH("CENTER")
    empty:SetText("No gear sets yet.\nWear your fishing gear, name a set below and press NEW SET.")

    ------------------------------------------------------------------ action bar
    local bar = CreateFrame("Frame", nil, studio)
    bar:SetSize(WIDTH, BAR_H)
    bar:SetPoint("TOPLEFT", 0, -(CHIPS_H + PANEL_H + 12))

    local nameBox = K.StyledEditBox(bar, 164, 28)
    nameBox:SetPoint("LEFT", 0, 0)
    nameBox:SetMaxLetters(24)

    local function Act(label, width, onClick)
        return FlatButton(bar, label, width, 28, onClick)
    end
    local function NewSet()
        local name, err = Gear:Create(nameBox:GetText(), true)
        if not name then Message(err) return end
        selected = name
        nameBox:SetText("")
        nameBox:ClearFocus()
        studio:Refresh()
    end
    nameBox:SetScript("OnEnterPressed", NewSet)
    local newBtn = Act("NEW SET", 82, NewSet)
    newBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
    local saveBtn = Act("SAVE WORN GEAR", 126, function()
        if selected and Gear:SaveWorn(selected) then
            Message("Saved what you are wearing to " .. selected .. ".")
            studio:Refresh()
        end
    end)
    saveBtn:SetPoint("LEFT", newBtn, "RIGHT", 8, 0)
    local equipBtn = Act("EQUIP SET", 92, function()
        if not selected then return end
        local changed, err = Gear:Equip(selected)
        if not changed then Message(err) return end
        Message(string.format("%s: swapped %d item%s.", selected, changed, changed == 1 and "" or "s"))
        if C_Timer and C_Timer.After then C_Timer.After(0.6, function() studio:Refresh() end) end
        studio:Refresh()
    end)
    equipBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    equipBtn.bg:SetVertexColor(AC[1] * 0.5, AC[2] * 0.5, AC[3] * 0.5)
    local deleteBtn = Act("DELETE", 72, function()
        if selected and Gear:Delete(selected) then
            selected = Gear:Active()
            studio:Refresh()
        end
    end)
    deleteBtn:SetPoint("LEFT", equipBtn, "RIGHT", 8, 0)

    ------------------------------------------------------------------ refresh
    function studio:Refresh()
        local names = Gear:List()
        if not (selected and Gear:Get(selected)) then selected = Gear:Active() end
        local r, g, b = AC[1], AC[2], AC[3]

        for i, chip in ipairs(chips) do
            local name = names[i]
            chip.setName = name
            chip:SetShown(name ~= nil)
            if name then
                local set = Gear:Get(name)
                local main = set.slots.MainHandSlot
                chip.icon:SetTexture((main and main.texture) or "Interface\\Icons\\Trade_Fishing")
                chip.name:SetText(name)
                local _, totals = Gear:Status(name)
                chip.meta:SetText(string.format("%d item%s  •  %d%% ready", totals.total, totals.total == 1 and "" or "s",
                    totals.total > 0 and math.floor((totals.worn + totals.bag) * 100 / totals.total) or 0))
                local on = name == selected
                K.SetGradient(chip.glow, "HORIZONTAL", r, g, b, on and 0.30 or 0, r, g, b, 0)
                chip.border:SetColor(on and r or 1, on and g or 1, on and b or 1, on and 0.85 or 0.10)
            end
        end

        local set = selected and Gear:Get(selected)
        K.SetGradient(wash, "VERTICAL", r, g, b, 0, r, g, b, 0.07)
        K.SetGradient(aura, "VERTICAL", r, g, b, 0, r, g, b, 0.14)
        for _, b2 in pairs(slotButtons) do b2:SetShown(set ~= nil) end
        empty:SetShown(set == nil)
        heroIcon:SetShown(set ~= nil)
        ring:SetShown(set ~= nil)
        heroName:SetShown(set ~= nil)
        heroSub:SetShown(set ~= nil)
        skillValue:SetShown(set ~= nil)
        styleValue:SetShown(set ~= nil)
        meter:SetShown(set ~= nil)
        meterFill:SetShown(set ~= nil)
        meterText:SetShown(set ~= nil)
        saveBtn:SetShown(set ~= nil)
        equipBtn:SetShown(set ~= nil)
        deleteBtn:SetShown(set ~= nil)
        if not set then return end

        local states, totals = Gear:Status(selected)
        for slot, button in pairs(slotButtons) do
            local info = set.slots[slot]
            button.link = info and info.link
            button.state = states[slot]
            if info then
                local qr, qg, qb = QualityColor(info.link)
                button.icon:SetTexture(info.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
                button.icon:SetShown(true)
                button.icon:SetDesaturated(states[slot] == "missing")
                button.label:SetShown(false)
                button.glow:SetVertexColor(qr, qg, qb, 0.35)
                button.r, button.g, button.b, button.a = qr, qg, qb, 0.9
                local st = STATE[states[slot]]
                button.dot:SetVertexColor(st[1], st[2], st[3], 1)
                button.dot:SetShown(true)
            else
                button.icon:SetShown(false)
                button.label:SetShown(true)
                button.glow:SetVertexColor(1, 1, 1, 0)
                button.r, button.g, button.b, button.a = 1, 1, 1, 0.12
                button.dot:SetShown(false)
            end
            button.border:SetColor(button.r, button.g, button.b, button.a)
        end

        local main = set.slots.MainHandSlot
        heroIcon:SetTexture((main and main.texture) or "Interface\\Icons\\Trade_Fishing")
        K.SetGradient(ring, "VERTICAL", r, g, b, 0.05, r, g, b, 0.35)
        heroName:SetText(selected)
        local skill, style = Gear:Points(selected)
        skillValue:SetText((skill >= 0 and "+" or "") .. skill)
        skillValue:SetTextColor(0.27, 0.87, 0.56)
        styleValue:SetText(tostring(style))
        styleValue:SetTextColor(1, 0.78, 0.22)
        heroSub:SetText(selected == Gear:Active() and "Used by the fishing swap" or "")

        local ready = totals.total > 0 and (totals.worn + totals.bag) / totals.total or 0
        meterFill:SetWidth(math.max(1, (hero:GetWidth() - 60) * ready))
        K.SetGradient(meterFill, "HORIZONTAL", r * 0.5, g * 0.5, b * 0.5, 1, r, g, b, 1)
        meterText:SetText(totals.total == 0 and "Empty: click a slot to add what you are wearing"
            or string.format("|cff45df8f%d worn|r   |cffffb838%d in bags|r   |cffeb4750%d missing|r",
                totals.worn, totals.bag, totals.missing))
    end

    studio:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    studio:RegisterEvent("BAG_UPDATE_DELAYED")
    studio:SetScript("OnEvent", function(self)
        if self:IsVisible() then self:Refresh() end
    end)
    studio.searchLabel = "Gear sets equipment manager paperdoll slots"
    studio:Refresh()
    return studio
end

FBI.GearUI = {
    Build = function(page)
        page:Section("Catchy Gear", "Build gear sets on the paperdoll. Click a slot to use what you are wearing there.")
        page:Add(BuildStudio(), TOTAL_H, true)
    end,
}
