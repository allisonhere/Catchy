-- Catchy Fishing Journal
-- A compact, modern summary of session, daily and lifetime fishing history.

local _, FBStorage = ...
local FBI = FBStorage
local FL = LibStub("LibFishing-1.0")

local Journal = {}
FBI.Journal = Journal

local function FormatTime(seconds)
    seconds = math.floor(seconds or 0)
    if seconds >= 3600 then
        return string.format("%dh %02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60))
    end
    return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
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

-- Locations stores every fish by location, but has no dates. Show that
-- existing history separately from the Journal's dated session statistics.
local function RecordedData()
    local data = { catches = 0, perFish = {}, zones = {} }
    local holes = Catchy_Info and Catchy_Info["FishingHoles"] or {}
    for marker, fish in pairs(holes) do
        local mapId = FBI:ZoneMarkerEx(marker)
        local zone = data.zones[mapId]
        if not zone then
            local name = FL:GetLocZone(mapId)
            zone = { name = name or ("Map " .. mapId), catches = 0 }
            data.zones[mapId] = zone
        end
        for id, quantity in pairs(fish) do
            if type(quantity) == "number" and quantity > 0 then
                data.catches = data.catches + quantity
                data.perFish[id] = (data.perFish[id] or 0) + quantity
                zone.catches = zone.catches + quantity
            end
        end
    end
    return data
end
Journal.RecordedData = RecordedData

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
    page:Add(Card("Recorded items", function()
        return tostring(RecordedData().catches)
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
        local recorded = RecordedData()
        local topFish = TopRow(recorded.perFish)
        fish:SetText("|cff8b95a5TOP CATCH|r\n" .. (topFish and (FishName(topFish.key) .. "  |cffffc738× " .. topFish.value .. "|r") or "No catches yet"))
        local topWater = TopRow(recorded.zones, "catches")
        water:SetText("|cff8b95a5FAVORITE WATER|r\n" .. (topWater and ((topWater.data.name or ("Map " .. topWater.key)) .. "  |cffffc738" .. topWater.value .. "|r") or "No locations yet"))
        local day = (db.daily or {})[date("%Y-%m-%d")] or {}
        today:SetText(string.format("|cff8b95a5TODAY|r\n%d catches from %d casts", day.catches or 0, day.casts or 0))
        local wins = 0
        for _, outcome in ipairs(current.outcomes or {}) do wins = wins + (outcome == 1 and 1 or 0) end
        recent:SetText(string.format("|cff8b95a5RECENT FORM|r\n%d catches in the last %d outcomes", wins, #(current.outcomes or {})))
    end
    panel.searchLabel = "Top catch favorite water today recent form"
    page:Add(panel, 112, true)

    page:Section("Last 14 days", "Catches per day over casts. Hover a day for details.")
    local DAYS, PLOT_W, PLOT_H = 14, K.COL_W * 2 + K.COL_GAP - 62, 104
    local chart = CreateFrame("Frame", nil, nil)
    chart:SetSize(K.COL_W * 2 + K.COL_GAP, 188)
    K.Tex(chart, "BACKGROUND", K.C.card):SetAllPoints()
    K.Border(chart, { 1, 1, 1, 0.10 })
    local glow = K.Tex(chart, "BACKGROUND", { 1, 1, 1, 1 }, 1)
    glow:SetPoint("TOPLEFT", 0, 0)
    glow:SetPoint("TOPRIGHT", 0, 0)
    glow:SetHeight(70)
    local headline = K.Text(chart, 20, K.AC, "OUTLINE")
    headline:SetPoint("TOPLEFT", 16, -12)
    local subline = K.Text(chart, 11, K.C.muted)
    subline:SetPoint("TOPLEFT", 16, -36)
    local legend = K.Text(chart, 10, K.C.muted)
    legend:SetPoint("TOPRIGHT", -16, -14)
    legend:SetJustifyH("RIGHT")
    legend:SetText("|cff49dce8■|r catches   |cff3a4558■|r casts")
    local ORIGIN_X, ORIGIN_Y = 40, 30
    local grid = {}
    for i = 0, 4 do
        local line = K.Tex(chart, "BACKGROUND", { 1, 1, 1, i == 0 and 0.16 or 0.055 }, 2)
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", ORIGIN_X, ORIGIN_Y + (PLOT_H * i / 4))
        line:SetPoint("BOTTOMRIGHT", -16, ORIGIN_Y + (PLOT_H * i / 4))
        local label = K.Text(chart, 9, K.C.muted)
        label:SetPoint("BOTTOMRIGHT", chart, "BOTTOMLEFT", ORIGIN_X - 8, ORIGIN_Y + (PLOT_H * i / 4) - 5)
        label:SetJustifyH("RIGHT")
        grid[i] = label
    end
    local pitch = PLOT_W / DAYS
    local columns = {}
    for i = 1, DAYS do
        local col = CreateFrame("Frame", nil, chart)
        col:SetSize(pitch, PLOT_H + 24)
        col:SetPoint("BOTTOMLEFT", ORIGIN_X + (i - 1) * pitch, ORIGIN_Y - 22)
        col:EnableMouse(true)
        col.hover = K.Tex(col, "BACKGROUND", { 1, 1, 1, 0.045 }, 3)
        col.hover:SetAllPoints()
        col.hover:Hide()
        col.ghost = K.Tex(col, "ARTWORK", { 0.23, 0.27, 0.35, 0.55 }, 1)
        col.ghost:SetWidth(math.floor(pitch * 0.62))
        col.ghost:SetPoint("BOTTOM", col, "BOTTOM", 0, 22)
        col.bar = K.Tex(col, "ARTWORK", { 1, 1, 1, 1 }, 2)
        col.bar:SetWidth(math.floor(pitch * 0.62) - 8)
        col.bar:SetPoint("BOTTOM", col, "BOTTOM", 0, 22)
        col.cap = K.Tex(col, "OVERLAY", { 1, 1, 1, 0.9 }, 3)
        col.cap:SetHeight(2)
        col.cap:SetWidth(math.floor(pitch * 0.62) - 8)
        col.value = K.Text(col, 10, K.C.text, "OUTLINE")
        col.value:SetJustifyH("CENTER")
        col.day = K.Text(col, 9, K.C.muted)
        col.day:SetPoint("BOTTOM", col, "BOTTOM", 0, 8)
        col.day:SetJustifyH("CENTER")
        col:SetScript("OnEnter", function(self)
            self.hover:Show()
            if not GameTooltip or not self.info then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.info.title, 1, 1, 1)
            GameTooltip:AddDoubleLine("Catches", tostring(self.info.catches), 0.6, 0.65, 0.72, 1, 0.78, 0.22)
            GameTooltip:AddDoubleLine("Casts", tostring(self.info.casts), 0.6, 0.65, 0.72, 1, 1, 1)
            GameTooltip:AddDoubleLine("Catch rate", self.info.rate, 0.6, 0.65, 0.72, 0.29, 0.86, 0.91)
            GameTooltip:Show()
        end)
        col:SetScript("OnLeave", function(self)
            self.hover:Hide()
            if GameTooltip then GameTooltip:Hide() end
        end)
        columns[i] = col
    end
    function chart:Refresh()
        local db = Session()
        local daily = db.daily or {}
        local now = time()
        local data, peak, total, totalCasts, best, bestKey = {}, 4, 0, 0, 0, nil
        for i = 1, DAYS do
            local stamp = now - (DAYS - i) * 86400
            local day = daily[date("%Y-%m-%d", stamp)] or {}
            local casts, catches = day.casts or 0, day.catches or 0
            data[i] = { stamp = stamp, casts = casts, catches = catches }
            peak = math.max(peak, casts, catches)
            total, totalCasts = total + catches, totalCasts + casts
            if catches > best then best, bestKey = catches, i end
        end
        local step = math.ceil(peak / 4)
        local top = step * 4
        for i = 0, 4 do grid[i]:SetText(tostring(step * i)) end
        local r, g, b = K.AC[1], K.AC[2], K.AC[3]
        for i, col in ipairs(columns) do
            local d = data[i]
            local width = math.floor(pitch * 0.62)
            col.ghost:SetShown(d.casts > 0)
            col.ghost:SetHeight(math.max(2, PLOT_H * d.casts / top))
            col.bar:SetShown(d.catches > 0)
            col.bar:SetHeight(math.max(2, PLOT_H * d.catches / top))
            local isToday = i == DAYS
            K.SetGradient(col.bar, "VERTICAL", r * 0.35, g * 0.35, b * 0.35, 0.95, r, g, b, 1)
            col.cap:ClearAllPoints()
            col.cap:SetPoint("BOTTOM", col.bar, "TOP", 0, -2)
            col.cap:SetShown(d.catches > 0)
            col.cap:SetVertexColor(1, 1, 1, isToday and 1 or 0.7)
            col.value:ClearAllPoints()
            col.value:SetPoint("BOTTOM", col.bar, "TOP", 0, 3)
            col.value:SetText(d.catches > 0 and tostring(d.catches) or "")
            col.day:SetText(isToday and "|cffffc738" .. date("%d", d.stamp) .. "|r" or date("%d", d.stamp))
            col.info = {
                title = date("%A, %b %d", d.stamp), casts = d.casts, catches = d.catches,
                rate = d.casts > 0 and string.format("%.1f%%", d.catches * 100 / d.casts) or "--",
            }
        end
        headline:SetText(string.format("%d catches", total))
        subline:SetText(string.format("%.1f per day  •  %s  •  %s",
            total / DAYS,
            bestKey and ("best day " .. best .. " on " .. date("%b %d", data[bestKey].stamp)) or "no catches in this window",
            totalCasts > 0 and string.format("%.1f%% catch rate", total * 100 / totalCasts) or "no casts yet"))
        K.SetGradient(glow, "VERTICAL", r, g, b, 0, r, g, b, 0.10)
    end
    chart.searchLabel = "Last 14 days chart catches casts per day"
    page:Add(chart, 188, true)

    page:Section("Recent form", "Your last 20 casts this session, newest on the right.")
    local form = CreateFrame("Frame", nil, nil)
    form:SetSize(K.COL_W * 2 + K.COL_GAP, 36)
    K.Tex(form, "BACKGROUND", K.C.card):SetAllPoints()
    K.Border(form, { 1, 1, 1, 0.10 })
    local dots = {}
    for i = 1, 20 do
        local dot = K.Tex(form, "ARTWORK", { 0.13, 0.17, 0.22, 0.85 })
        dot:SetSize(25, 12)
        dot:SetPoint("LEFT", 14 + ((i - 1) * 30), 0)
        dots[i] = dot
    end
    function form:Refresh()
        local _, current = Session()
        local outcomes = current.outcomes or {}
        for i, dot in ipairs(dots) do
            local outcome = outcomes[i]
            if outcome == 1 then dot:SetColorTexture(0.18, 0.85, 0.54, 0.95)
            elseif outcome == 0 then dot:SetColorTexture(0.88, 0.24, 0.25, 0.90)
            else dot:SetColorTexture(0.13, 0.17, 0.22, 0.85) end
        end
    end
    form.searchLabel = "Recent form outcomes"
    page:Add(form, 36, true)

    page:Section("Catch map", "Every catch is remembered by place. Pick a fish, step through your zones, and see where the fish were caught.")
    local MapView = FBI.CatchMapView
    local ZONE_ROWS = 8
    local zoneFish = 0 -- 0 = all fish
    page:Add(K.W.Dropdown("Show fish", function()
        local items = { { value = 0, label = "All fish" } }
        if MapView then
            for _, fish in ipairs(MapView:FishChoices()) do
                items[#items + 1] = { value = fish.id, label = string.format("%s  (%d)", fish.name, fish.count) }
            end
        end
        return items
    end, function() return zoneFish end, function(value)
        zoneFish = value
        if MapView then MapView.filter.fish = value ~= 0 and value or nil end
    end, "Which fish the map shows."), 48)
    if MapView then
        page:Add(MapView:BuildShowcase(K, K.COL_W * 2 + K.COL_GAP, 400), 400, true)
    end

    local zones = CreateFrame("Frame", nil, nil)
    local zonesHeight = 38 + ZONE_ROWS * 30
    zones:SetSize(K.COL_W * 2 + K.COL_GAP, zonesHeight)
    K.Tex(zones, "BACKGROUND", K.C.card):SetAllPoints()
    K.Border(zones, { 1, 1, 1, 0.10 })
    local zoneHeading = K.Text(zones, 10, K.C.muted)
    zoneHeading:SetPoint("TOPLEFT", 14, -12)
    zoneHeading:SetText("ZONES WITH RECORDED CATCHES")
    local zoneEmpty = K.Text(zones, 12, K.C.muted)
    zoneEmpty:SetPoint("TOPLEFT", 14, -42)
    zoneEmpty:SetText("No catch locations yet. Go fishing and your spots will appear here.")
    local ZONE_W = K.COL_W * 2 + K.COL_GAP - 28
    local zoneRows = {}
    for i = 1, ZONE_ROWS do
        local row = {}
        local y = -32 - (i - 1) * 30
        row.track = K.Tex(zones, "ARTWORK", { 1, 1, 1, 0.045 }, 1)
        row.track:SetSize(ZONE_W, 24)
        row.track:SetPoint("TOPLEFT", 14, y)
        row.fill = K.Tex(zones, "ARTWORK", { 1, 1, 1, 1 }, 2)
        row.fill:SetHeight(24)
        row.fill:SetPoint("TOPLEFT", 14, y)
        row.name = K.Text(zones, 12, K.C.text, "OUTLINE")
        row.name:SetPoint("TOPLEFT", 24, y - 5)
        row.name:SetWidth(260)
        row.name:SetJustifyH("LEFT")
        row.stats = K.Text(zones, 11, K.C.muted)
        row.stats:SetPoint("TOPRIGHT", zones, "TOPLEFT", 14 + ZONE_W - 86, y - 6)
        row.stats:SetJustifyH("RIGHT")
        row.view = K.FlatButton(zones, "SHOW", 72, 20, function()
            if row.mapId and MapView then
                MapView.selected = row.mapId
                page:Refresh()
            end
        end)
        row.view:SetPoint("TOPRIGHT", zones, "TOPLEFT", 14 + ZONE_W - 4, y - 2)
        zoneRows[i] = row
    end
    function zones:Refresh()
        local list = MapView and MapView:Zones() or {}
        zoneEmpty:SetShown(#list == 0)
        local peak = list[1] and list[1].total or 1
        local r, g, b = K.AC[1], K.AC[2], K.AC[3]
        for i, row in ipairs(zoneRows) do
            local zone = list[i]
            row.mapId = zone and zone.mapId
            row.track:SetShown(zone ~= nil)
            row.fill:SetShown(zone ~= nil)
            row.name:SetShown(zone ~= nil)
            row.stats:SetShown(zone ~= nil)
            row.view:SetShown(zone ~= nil)
            if zone then
                row.fill:SetWidth(math.max(3, ZONE_W * zone.total / peak))
                K.SetGradient(row.fill, "HORIZONTAL", r * 0.3, g * 0.3, b * 0.3, 0.9, r * 0.85, g * 0.85, b * 0.85, 0.7)
                row.name:SetText(zone.name)
                row.stats:SetText(string.format("|cffffc738%d|r catches  •  %d spots", zone.total, zone.spots))
            end
        end
    end
    zones.searchLabel = "Catch map zones where fish were caught"
    page:Add(zones, zonesHeight, true)

    page:Section("Rankings", "Top catches and favorite waters from your recorded history.")
    local ROWS, BAR_W = 6, K.COL_W - 28
    local function RankingPanel(title, build)
        local height = 38 + ROWS * 26
        local panel = CreateFrame("Frame", nil, nil)
        panel:SetSize(K.COL_W, height)
        K.Tex(panel, "BACKGROUND", K.C.card):SetAllPoints()
        K.Border(panel, { 1, 1, 1, 0.10 })
        local heading = K.Text(panel, 10, K.C.muted)
        heading:SetPoint("TOPLEFT", 14, -12)
        heading:SetText(title)
        local rows = {}
        for i = 1, ROWS do
            local row = {}
            local y = -32 - (i - 1) * 26
            row.track = K.Tex(panel, "ARTWORK", { 1, 1, 1, 0.045 }, 1)
            row.track:SetSize(BAR_W, 20)
            row.track:SetPoint("TOPLEFT", 14, y)
            row.fill = K.Tex(panel, "ARTWORK", { 1, 1, 1, 1 }, 2)
            row.fill:SetHeight(20)
            row.fill:SetPoint("TOPLEFT", 14, y)
            row.rank = K.Text(panel, 10, K.C.muted, "OUTLINE")
            row.rank:SetPoint("TOPLEFT", 20, y - 5)
            row.name = K.Text(panel, 11, K.C.text, "OUTLINE")
            row.name:SetPoint("TOPLEFT", 38, y - 4)
            row.name:SetWidth(BAR_W - 74)
            row.name:SetJustifyH("LEFT")
            row.value = K.Text(panel, 11, { 1, 0.78, 0.22 }, "OUTLINE")
            row.value:SetPoint("TOPRIGHT", panel, "TOPLEFT", 14 + BAR_W - 6, y - 4)
            row.value:SetJustifyH("RIGHT")
            rows[i] = row
        end
        function panel:Refresh()
            local list = build()
            local peak = list[1] and list[1].value or 1
            local r, g, b = K.AC[1], K.AC[2], K.AC[3]
            for i, row in ipairs(rows) do
                local item = list[i]
                row.fill:SetShown(item ~= nil)
                if item then
                    row.fill:SetWidth(math.max(3, BAR_W * item.value / math.max(peak, 1)))
                    K.SetGradient(row.fill, "HORIZONTAL", r * 0.3, g * 0.3, b * 0.3, 0.9, r * 0.85, g * 0.85, b * 0.85, 0.75)
                    row.rank:SetText(string.format("%02d", i))
                    row.name:SetText(item.label)
                    row.value:SetText(tostring(item.value))
                else
                    row.rank:SetText("")
                    row.name:SetText("|cff4b5563—|r")
                    row.value:SetText("")
                end
            end
        end
        panel.searchLabel = title
        return panel, height
    end
    page:Add(RankingPanel("TOP CATCHES", function()
        local list = SortedRows(RecordedData().perFish)
        for _, row in ipairs(list) do row.label = FishName(row.key) end
        return list
    end))
    page:Add(RankingPanel("FAVORITE WATERS", function()
        local list = SortedRows(RecordedData().zones, "catches")
        for _, row in ipairs(list) do row.label = row.data.name or ("Map " .. row.key) end
        return list
    end))

    page:Section("Performance", "Session rhythm and reliability.")
    local perf
    local perfPanel = CreateFrame("Frame", nil, nil)
    perfPanel:SetSize(K.COL_W * 2 + K.COL_GAP, 100)
    K.Tex(perfPanel, "BACKGROUND", K.C.card):SetAllPoints()
    K.Border(perfPanel, { 1, 1, 1, 0.10 })
    perf = K.Text(perfPanel, 12, K.C.text)
    perf:SetPoint("TOPLEFT", 14, -12)
    perf:SetWidth(K.COL_W * 2 + K.COL_GAP - 28)
    perf:SetJustifyH("LEFT")
    perf:SetSpacing(6)
    function perfPanel:Refresh()
        local db, current = Session()
        local day = (db.daily or {})[date("%Y-%m-%d")] or {}
        local hookCount = (db.lifetime and db.lifetime.hookCount) or 0
        perf:SetText(string.format(
            "|cff9aa3adRolling catch rate|r  |cff49dce8%.1f%%|r\n|cff9aa3adAverage bite|r  %s\n|cff9aa3adUnlooted casts|r  %d\n|cff9aa3adInterrupted casts|r  %d\n|cff9aa3adToday|r  %d catches / %d casts",
            FBI.Stats:RollingRate(),
            hookCount > 0 and string.format("%.1fs", (db.lifetime.hookTotal or 0) / hookCount) or "--",
            current.unresolved or 0, current.interrupted or 0, day.catches or 0, day.casts or 0))
    end
    perfPanel.searchLabel = "Performance rolling catch rate unlocked interrupted"
    page:Add(perfPanel, 100, true)
end

if FBI.Settings and FBI.Settings.SetPage then
    FBI.Settings:SetPage({
        section = "fishing", key = "journal", label = "Journal", order = 3,
        build = function(page)
            page:Section("Fishing Journal", "Session, daily and lifetime fishing performance.")
            BuildJournalOverview(page)
        end,
    })
end

