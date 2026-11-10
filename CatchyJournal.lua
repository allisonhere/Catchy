-- Catchy Fishing Journal
-- A compact, modern summary of session, daily and lifetime fishing history.

local _, FBStorage = ...
local FBI = FBStorage

local Journal = {}
FBI.Journal = Journal

local GOLD = { 1.00, 0.78, 0.22 }
local AQUA = { 0.22, 0.84, 0.92 }
local MUTED = { 0.58, 0.62, 0.68 }

local function SetColor(font, color)
    font:SetTextColor(color[1], color[2], color[3])
end

local function FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    if seconds >= 3600 then
        return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
    end
    return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
end

local function FormatMoney(copper)
    copper = math.floor(copper or 0)
    return string.format("%dg %02ds", math.floor(copper / 10000), math.floor(copper % 10000 / 100))
end

local function Rate(data)
    if not data or not data.casts or data.casts == 0 then return 0 end
    return (data.catches or 0) * 100 / data.casts
end

local function FishName(id)
    local name = select(6, FBI:GetFishie(id))
    if name then return name end
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) or ("Item " .. id) end
    return "Item " .. id
end

local function SortedRows(source, valueField)
    local rows = {}
    for key, value in pairs(source or {}) do
        local amount = type(value) == "table" and (value[valueField] or 0) or value
        rows[#rows + 1] = { key = key, value = amount, data = value }
    end
    table.sort(rows, function(a, b) return a.value > b.value end)
    return rows
end

local frame = CreateFrame("Frame", "CatchyJournalFrame", UIParent, "BackdropTemplate")
frame:SetSize(720, 520)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 25)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
if frame.SetBackdrop then
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.025, 0.035, 0.055, 0.97)
    frame:SetBackdropBorderColor(0.95, 0.72, 0.18, 0.95)
end

local wash = frame:CreateTexture(nil, "BACKGROUND")
wash:SetPoint("TOPLEFT", 1, -1)
wash:SetPoint("TOPRIGHT", -1, -1)
wash:SetHeight(92)
wash:SetColorTexture(0.06, 0.18, 0.22, 0.72)

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(46, 46)
icon:SetPoint("TOPLEFT", 22, -20)
icon:SetTexture("Interface\\Icons\\Trade_Fishing")

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, -2)
title:SetText("FISHING JOURNAL")
SetColor(title, GOLD)

local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -5)
subtitle:SetText("Your catches, rhythm, and favorite waters")
SetColor(subtitle, MUTED)

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)

local tabs = {}
local activePeriod = "session"
local tabNames = { {"session", "SESSION"}, {"today", "TODAY"}, {"lifetime", "LIFETIME"} }
for index, info in ipairs(tabNames) do
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(108, 28)
    button:SetPoint("TOPRIGHT", -48 - ((#tabNames - index) * 114), -52)
    if button.SetBackdrop then
        button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    end
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetText(info[2])
    button.period = info[1]
    button:SetScript("OnClick", function(self)
        activePeriod = self.period
        Journal:Refresh()
    end)
    tabs[#tabs + 1] = button
end

local cards = {}
local cardDefs = {
    { "casts", "CASTS" }, { "catches", "CATCHES" }, { "rate", "CATCH RATE" },
    { "speed", "AVG BITE" }, { "cadence", "CADENCE" }, { "gold", "GOLD" },
}
for index, info in ipairs(cardDefs) do
    local card = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    card:SetSize(103, 68)
    card:SetPoint("TOPLEFT", 22 + ((index - 1) * 113), -109)
    if card.SetBackdrop then
        card:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        card:SetBackdropColor(0.055, 0.075, 0.105, 0.92)
        card:SetBackdropBorderColor(0.13, 0.23, 0.29, 1)
    end
    card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.label:SetPoint("TOPLEFT", 10, -10)
    card.label:SetText(info[2])
    SetColor(card.label, MUTED)
    card.value = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.value:SetPoint("BOTTOMLEFT", 10, 9)
    SetColor(card.value, index == 4 and AQUA or GOLD)
    cards[info[1]] = card
end

local function Header(text, x, y)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetText(text)
    SetColor(label, GOLD)
    return label
end

Header("RECENT FORM", 24, -202)
Header("TOP CATCHES", 24, -282)
Header("FAVORITE WATERS", 375, -202)
Header("PERFORMANCE", 375, -344)

local outcomeDots = {}
for i = 1, 20 do
    local dot = frame:CreateTexture(nil, "ARTWORK")
    dot:SetSize(25, 12)
    dot:SetPoint("TOPLEFT", 24 + ((i - 1) * 16), -230)
    outcomeDots[i] = dot
end

local fishRows, zoneRows = {}, {}
for i = 1, 6 do
    local fish = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fish:SetPoint("TOPLEFT", 26, -306 - ((i - 1) * 25))
    fish:SetWidth(305)
    fish:SetJustifyH("LEFT")
    fishRows[i] = fish

    local zone = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zone:SetPoint("TOPLEFT", 377, -228 - ((i - 1) * 21))
    zone:SetWidth(305)
    zone:SetJustifyH("LEFT")
    zoneRows[i] = zone
end

local analytics = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
analytics:SetPoint("TOPLEFT", 377, -371)
analytics:SetWidth(305)
analytics:SetJustifyH("LEFT")
analytics:SetSpacing(7)

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
footer:SetPoint("BOTTOMLEFT", 24, 16)
footer:SetText("/ca journal  •  Last 20 outcomes are shown newest on the right")
SetColor(footer, MUTED)

local function PeriodData()
    local db, session = FBI.Stats:GetDatabase()
    if activePeriod == "session" then return session, session, db end
    if activePeriod == "today" then
        local key = date("%Y-%m-%d")
        return db.daily[key] or {}, session, db
    end
    return db.lifetime or {}, session, db
end

function Journal:Refresh()
    if not FBI.Stats then return end
    local data, session = PeriodData()
    for _, tab in ipairs(tabs) do
        local active = tab.period == activePeriod
        tab:SetBackdropColor(active and 0.11 or 0.04, active and 0.34 or 0.08, active and 0.40 or 0.10, 0.95)
        tab.text:SetTextColor(active and GOLD[1] or MUTED[1], active and GOLD[2] or MUTED[2], active and GOLD[3] or MUTED[3])
    end

    cards.casts.value:SetText(tostring(data.casts or 0))
    cards.catches.value:SetText(tostring(data.catches or 0))
    cards.rate.value:SetText(string.format("%.1f%%", Rate(data)))
    local hookCount = data.hookCount or 0
    cards.speed.value:SetText(hookCount > 0 and string.format("%.1fs", (data.hookTotal or 0) / hookCount) or "--")
    local intervalCount = data.intervalCount or 0
    cards.cadence.value:SetText(intervalCount > 0 and string.format("%.1fs", (data.intervalTotal or 0) / intervalCount) or (activePeriod == "session" and string.format("%.1fs", FBI.Stats:AverageCastInterval()) or "--"))
    cards.gold.value:SetText(FormatMoney(data.gold or 0))

    local outcomes = session.outcomes or {}
    for i, dot in ipairs(outcomeDots) do
        local outcome = outcomes[i]
        if outcome == 1 then dot:SetColorTexture(0.18, 0.85, 0.54, 0.95)
        elseif outcome == 0 then dot:SetColorTexture(0.88, 0.24, 0.25, 0.90)
        else dot:SetColorTexture(0.13, 0.17, 0.22, 0.85) end
    end

    local fish = SortedRows(data.perFish)
    for i, row in ipairs(fishRows) do
        if fish[i] then
            row:SetText(string.format("|cff49dce8%02d|r  %s  |cffffc738× %d|r", i, FishName(fish[i].key), fish[i].value))
        else row:SetText("|cff4b5563—|r") end
    end

    local zones = SortedRows(data.zones, "catches")
    for i, row in ipairs(zoneRows) do
        if zones[i] then
            local name = zones[i].data.name or ("Map " .. zones[i].key)
            row:SetText(string.format("|cff49dce8%02d|r  %s  |cffffc738%d|r", i, name, zones[i].value))
        else row:SetText("|cff4b5563—|r") end
    end

    analytics:SetText(string.format(
        "|cff9aa3adSession length|r  %s\n|cff9aa3adRolling catch rate|r  |cff49dce8%.1f%%|r\n|cff9aa3adUnlooted casts|r  %d\n|cff9aa3adInterrupted casts|r  %d\n|cff9aa3adBest streak|r  |cffffc738%d|r",
        FormatTime(FBI.Stats:Elapsed()), FBI.Stats:RollingRate(), session.unresolved or 0,
        session.interrupted or 0, session.best or 0))
end

function Journal:Open()
    if FBI.Settings and FBI.Settings.Close then FBI.Settings:Close() end
    self:Refresh()
    frame:Show()
    if frame.Raise then frame:Raise() end
end

function Journal:Toggle()
    if frame:IsShown() then frame:Hide() else self:Open() end
end

frame:SetScript("OnShow", function() Journal:Refresh() end)
table.insert(UISpecialFrames, "CatchyJournalFrame")

local function TopRow(source, valueField)
    local rows = SortedRows(source, valueField)
    return rows[1]
end

local function BuildJournalOverview(page)
    local K = FBI.Settings and FBI.Settings.Kit
    if not K then return end

    local function Card(label, getValue, color)
        local card = CreateFrame("Frame", nil, nil)
        card:SetSize(K.COL_W, 62)
        local background = K.Tex(card, "BACKGROUND", K.C.card)
        background:SetAllPoints()
        K.Border(card, { 1, 1, 1, 0.10 })
        local heading = K.Text(card, 10, K.C.muted)
        heading:SetPoint("TOPLEFT", 12, -10)
        heading:SetText(label:upper())
        local value = K.Text(card, 20, color or K.AC, "OUTLINE")
        value:SetPoint("BOTTOMLEFT", 12, 9)
        function card:Refresh() value:SetText(getValue()) end
        card.searchLabel = label
        return card
    end

    local function Session()
        local db, current = FBI.Stats:GetDatabase()
        return db or {}, current or {}
    end

    page:Add(Card("Session catches", function()
        local _, current = Session(); return tostring(current.catches or 0)
    end), 62)
    page:Add(Card("Lifetime catches", function()
        local db = Session(); return tostring((db.lifetime and db.lifetime.catches) or 0)
    end), 62)
    page:Add(Card("Session catch rate", function()
        return string.format("%.1f%%", FBI.Stats:CatchRate())
    end), 62)
    page:Add(Card("Catches per hour", function()
        return string.format("%.1f", FBI.Stats.CatchesPerHour and FBI.Stats:CatchesPerHour() or 0)
    end), 62)
    page:Add(Card("Best streak", function()
        local _, current = Session(); return tostring(current.best or 0)
    end), 62)
    page:Add(Card("Session time", function()
        return FormatTime(FBI.Stats:Elapsed())
    end), 62)

    page:Section("Highlights", "Your strongest lifetime patterns and today's progress.")
    local panel = CreateFrame("Frame", nil, nil)
    panel:SetSize(K.COL_W * 2 + K.COL_GAP, 112)
    K.Tex(panel, "BACKGROUND", K.C.card):SetAllPoints()
    K.Border(panel, { 1, 1, 1, 0.10 })
    local fish = K.Text(panel, 12, K.C.text)
    fish:SetPoint("TOPLEFT", 14, -14)
    fish:SetWidth(K.COL_W - 20)
    local water = K.Text(panel, 12, K.C.text)
    water:SetPoint("TOPLEFT", K.COL_W + K.COL_GAP, -14)
    water:SetWidth(K.COL_W - 20)
    local today = K.Text(panel, 12, K.C.text)
    today:SetPoint("TOPLEFT", 14, -67)
    today:SetWidth(K.COL_W - 20)
    local recent = K.Text(panel, 12, K.C.text)
    recent:SetPoint("TOPLEFT", K.COL_W + K.COL_GAP, -67)
    recent:SetWidth(K.COL_W - 20)
    function panel:Refresh()
        local db, current = Session()
        local lifetime = db.lifetime or {}
        local topFish = TopRow(lifetime.perFish)
        fish:SetText("|cff8b95a5TOP CATCH|r\n" .. (topFish and (FishName(topFish.key) .. "  |cffffc738× " .. topFish.value .. "|r") or "No catches yet"))
        local topWater = TopRow(lifetime.zones, "catches")
        water:SetText("|cff8b95a5FAVORITE WATER|r\n" .. (topWater and ((topWater.data.name or ("Map " .. topWater.key)) .. "  |cffffc738" .. topWater.value .. "|r") or "No locations yet"))
        local day = (db.daily or {})[date("%Y-%m-%d")] or {}
        today:SetText(string.format("|cff8b95a5TODAY|r\n%d catches from %d casts", day.catches or 0, day.casts or 0))
        local wins = 0
        for _, outcome in ipairs(current.outcomes or {}) do wins = wins + (outcome == 1 and 1 or 0) end
        recent:SetText(string.format("|cff8b95a5RECENT FORM|r\n%d catches in the last %d outcomes", wins, #(current.outcomes or {})))
    end
    panel.searchLabel = "Top catch favorite water today recent form"
    page:Add(panel, 112, true)
end

if FBI.Settings and FBI.Settings.SetPage then
    FBI.Settings:SetPage({
        section = "fishing", key = "journal", label = "Journal", order = 3,
        build = function(page)
            page:Section("Fishing Journal", "Session, daily and lifetime fishing performance.")
            BuildJournalOverview(page)
            page:Section("Full Journal", "Open the complete Session, Today and Lifetime views with detailed rankings and analytics.")
            page:Button("Open Fishing Journal", function() Journal:Open() end,
                "Open the full visual journal with top catches, favorite waters and rhythm analytics.", 210)
        end,
    })
end

FBI.JournalFrame = frame

