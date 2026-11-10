-- Catchy: Locations page
-- The fish you have caught, by zone or by fish, in the new settings window. It reads the
-- same data the classic window does (FishingLocations) and keeps its row rules, but draws
-- plain rows instead of Blizzard list templates.
local addonName, FBI = ...
local FBConstants = FBI.FBConstants
local Settings = FBI.Settings
if not Settings then return end

local FL = LibStub("LibFishing-1.0")
local K = Settings.Kit
local Tex, Text, Border, FlatButton, Accent, W, C, AC = K.Tex, K.Text, K.Border, K.FlatButton, K.Accent, K.W, K.C, K.AC

local ROWS, ROW_H, INDENT = 16, 22, 16
local WIDTH = K.COL_W * 2 + K.COL_GAP
local HEAD_H = 40

local function zmex(...) return FBI:ZoneMarkerEx(...) end

-- One visible line as plain data (the logic of the classic window's row initializer).
local function LineData(index)
    local info = FishingLocations:GetVisible(index)
    if not info or info == 0 then return end
    local zid, fid, collapsible, expanded, level = FishingLocations:unpack(info)
    local white, green = FL.HEX_COLOR_WHITE, FL.HEX_COLOR_GREEN
    local fh, ft, bf = Catchy_Info["FishingHoles"], Catchy_Info["FishTotals"], FBI.ByFishie
    local d = {
        level = level, collapsible = collapsible == 1, expanded = expanded ~= 0, tooltip = {},
    }
    local totals = {}
    local lastfid, lastzid
    local percent
    local zidx, sidx

    if zid > 0 then
        lastzid = zid
        zidx, sidx = zmex(zid)
        if sidx > 0 then
            local sz = Catchy_Info["SubZones"][zid]
            local ztab = FBI.SubZoneMap[sz]
            if ztab then
                local count = 0
                for idx in pairs(ztab) do
                    local n = Catchy_Info["FishTotals"][idx]
                    if n then count = count + n end
                end
                totals[level] = count
            end
        else
            totals[level] = Catchy_Info["FishTotals"][zid]
        end
    elseif level == 0 then
        lastfid = fid
    end

    if zid > 0 or fid > 0 then
        if fid > 0 then
            local item, texture, _, _, _, text = FBI:GetFishie(fid, 1)
            d.item, d.texture, d.fishid, d.name, d.text = item, texture, fid, text, text
            if FBI:IsQuestFish(fid) then tinsert(d.tooltip, ITEM_BIND_QUEST) end
            if level > 0 then
                local sz = Catchy_Info["SubZones"][lastzid]
                local ztab = FBI.SubZoneMap[sz]
                local count = 0
                if ztab then
                    for idx in pairs(ztab) do
                        if fh[idx] and fh[idx][fid] then count = count + fh[idx][fid] end
                    end
                end
                if count > 0 then
                    d.count = count
                    tinsert(d.tooltip, { { FBConstants.CAUGHTTHISMANY, green }, { count, white } })
                    if totals[level - 1] then
                        tinsert(d.tooltip, { { FBConstants.CAUGHTTHISTOTAL, green }, { totals[level - 1], white } })
                        percent = count / totals[level - 1]
                    end
                end
            else
                local total = 0
                for _, count in pairs(bf[fid] or {}) do total = total + count end
                totals[0] = total
                d.count = total
                tinsert(d.tooltip, { { FBConstants.CAUGHTTHISTOTAL, green }, { total, white } })
            end
        else
            local text
            if sidx > 0 then
                text = FL:GetLocSubZone(Catchy_Info["SubZones"][zid], 1)
                tinsert(d.tooltip, text)
                local ztab = FBI.SubZoneMap[text]
                if ztab then
                    local inz = {}
                    for idx in pairs(ztab) do
                        local tz = zmex(idx)
                        tinsert(inz, FL:GetLocZone(tz))
                    end
                    table.sort(inz)
                    tinsert(d.tooltip, FL:Green(ZONE_COLON .. " ") .. FL:White(FBI:EnglishList(inz)))
                end
                if lastfid then
                    if bf[lastfid][zid] then
                        tinsert(d.tooltip, { { FBConstants.CAUGHTTHISTOTAL, green }, { bf[lastfid][zid], white } })
                        if level > 0 and totals[level - 1] then percent = bf[lastfid][zid] / totals[level - 1] end
                    end
                elseif ft[zid] then
                    d.count = ft[zid]
                    tinsert(d.tooltip, { { FBConstants.CAUGHTTHISTOTAL, green }, { ft[zid], white } })
                    if level > 0 and totals[level - 1] then percent = ft[zid] / totals[level - 1] end
                end
            else
                text = FL:GetLocZone(zidx)
                tinsert(d.tooltip, text)
                local subsorted = FBI.SortedByZone[text]
                local ins = {}
                for s = 1, #(subsorted or {}) do tinsert(ins, subsorted[s]) end
                tinsert(d.tooltip, FL:Green("Subzones: ") .. FL:White(FBI:EnglishList(ins)))
                tinsert(d.tooltip, { { FBConstants.CAUGHTTHISTOTAL, green }, { totals[level], white } })
                d.count = totals[level]
                if level > 0 and lastfid and bf[lastfid][zid] then percent = bf[lastfid][zid] / totals[level - 1] end
            end
            d.text = text
        end
        if percent then d.percent = math.floor(percent * 100) end
    end
    return d
end

local function CompactCount(value)
    value = tonumber(value) or 0
    if value >= 1000000 then return string.format("%.1fm", value / 1000000) end
    if value >= 10000 then return string.format("%.1fk", value / 1000) end
    return tostring(math.floor(value))
end

local function StatText(data)
    local parts = {}
    if data.count ~= nil then parts[#parts + 1] = "|cffffc738× " .. CompactCount(data.count) .. "|r" end
    if data.percent ~= nil then parts[#parts + 1] = "|cff8d99a8" .. data.percent .. "%|r" end
    return table.concat(parts, "   ")
end
FBI.LocationStatText = StatText

local function Valid(set)
    local frame = _G.FishingLocationsFrame
    if not frame then return false end
    if set ~= nil then frame.valid = set end
    return frame.valid
end

local function Rebuild()
    if not Valid() then FishingLocations:LinesChanged() end
end

local function ShowTip(row, d)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if d.item and d.item ~= "" and FL:IsLinkableItem(d.item) then
        GameTooltip:SetHyperlink("item:" .. d.item)
        FL:AddTooltip(d.tooltip)
    else
        local tip = {}
        if d.name then
            tinsert(tip, d.name)
            if d.item and d.item ~= "" then
                tinsert(tip, { FBConstants.NOTLINKABLE, "ff" .. FL.COLOR_HEX_RED })
            end
        end
        for _, line in ipairs(d.tooltip) do tinsert(tip, line) end
        FL:AddTooltip(tip)
    end
    GameTooltip:Show()
end

local function HiddenInWatcher(fishid)
    return Catchy_Info["HiddenFishies"] and Catchy_Info["HiddenFishies"][fishid]
end

local function FishMenu(row, d)
    local items = {}
    local label = (HiddenInWatcher(d.fishid) and "[ ]  " or "[x]  ") .. FBConstants.HIDEINWATCHER
    items[1] = { value = "watcher", label = label }
    K.OpenMenu(row, items, nil, function(choice)
        if choice == "watcher" and FBI.FWF and FBI.FWF.MakeToggle then
            FBI.FWF.MakeToggle(d.fishid)()
        end
    end)
end

local function NewRow(parent, i, list)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.stripe = Tex(row, "BACKGROUND", { 1, 1, 1, 0.025 })
    row.stripe:SetAllPoints()
    row.hover = Tex(row, "ARTWORK", { 1, 1, 1, 0.05 })
    row.hover:SetAllPoints()
    row.hover:Hide()
    row.arrow = Text(row, 12, AC)
    row.arrow:SetJustifyH("CENTER")
    row.arrow:SetWidth(14)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.name = Text(row, 12)
    row.name:SetWordWrap(false)
    row.percent = Text(row, 11, C.muted)
    row.percent:SetJustifyH("RIGHT")
    row.percent:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", function(self)
        self.hover:Show()
        if self.data then ShowTip(self, self.data) end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    row:SetScript("OnClick", function(self, button)
        local d = self.data
        if not d then return end
        if button == "RightButton" then
            if d.fishid then FishMenu(self, d) end
        elseif IsShiftKeyDown() and d.item then
            FL:ChatLink(d.item, d.name, d.color)
        elseif d.collapsible then
            FishingLocations:Toggle(self.line)
            list:Refresh()
        end
    end)
    return row
end

local function BuildLocations()
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(WIDTH, HEAD_H + ROWS * ROW_H + 4)
    f.offset = 0
    f.expandedAll = false

    local switch = FlatButton(f, "", 150, 26, function()
        FBI:SetSetting("GroupByLocation", not FBI:GetSetting("GroupByLocation"))
        Valid(false)
        f.offset = 0
        Settings:Refresh()
    end)
    switch:SetPoint("TOPLEFT", 0, 0)
    K.Tooltip(switch, FBConstants.LOCATIONS_TAB or "Locations", function()
        return FBI:GetSettingBool("GroupByLocation") and FBConstants.SHOWFISHIES_INFO or FBConstants.SHOWLOCATIONS_INFO
    end)

    local zones = W.Check(FBConstants.CONFIG_SHOWLOCATIONZONES_ONOFF or "Show zones",
        function() return FBI:GetSettingBool("ShowLocationZones") end,
        function(v)
            FBI:SetSetting("ShowLocationZones", v)
            Valid(false)
        end, FBConstants.CONFIG_SHOWLOCATIONZONES_INFO,
        { enabled = function() return FBI:GetSettingBool("GroupByLocation") end })
    zones:SetParent(f)
    zones:SetPoint("LEFT", switch, "RIGHT", 18, 0)
    zones:SetWidth(150)

    local collapse = FlatButton(f, "", 110, 26, function()
        f.expandedAll = not f.expandedAll
        Rebuild()
        local ok, err = pcall(FishingLocations.SetExpandCollapse, FishingLocations, f.expandedAll)
        if not ok then FBI:Output("Catchy locations: " .. tostring(err), 1, 0.3, 0.3) end
        f:Refresh()
    end)
    collapse:SetPoint("TOPRIGHT", 0, 0)

    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 0, -HEAD_H)
    box:SetPoint("BOTTOMRIGHT")
    Tex(box, "BACKGROUND", C.field):SetAllPoints()
    Border(box, { 1, 1, 1, 0.08 })
    local empty = Text(box, 12, C.muted)
    empty:SetPoint("CENTER")
    empty:SetText("No fish caught yet. Go and catch something.")
    local thumb = Accent(Tex(box, "OVERLAY"), 0.5)
    thumb:SetWidth(3)

    f.rows = {}
    for i = 1, ROWS do
        local row = NewRow(box, i, f)
        row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", -6, 0)
        f.rows[i] = row
    end
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta)
        f.offset = f.offset - delta * 3
        f:Refresh()
    end)

    function f:Refresh()
        local grouped = FBI:GetSettingBool("GroupByLocation")
        switch.text:SetText(grouped and (FBConstants.SHOWFISHIES or "Show fish") or (FBConstants.SHOWLOCATIONS or "Locations"))
        collapse.text:SetText(self.expandedAll and "Collapse all" or "Expand all")
        zones:Refresh()
        Rebuild()
        local count = FishingLocations:Lines()
        self.offset = math.max(0, math.min(self.offset, count - ROWS))
        for i, row in ipairs(self.rows) do
            local index = self.offset + i
            local d = index <= count and LineData(index) or nil
            row.data, row.line = d, index
            if d then
                row.stripe:SetShown(index % 2 == 1)
                local x = 6 + d.level * INDENT
                row.arrow:ClearAllPoints()
                row.arrow:SetPoint("LEFT", x, 0)
                row.arrow:SetText(d.collapsible and (d.expanded and "-" or "+") or "")
                row.icon:ClearAllPoints()
                row.icon:SetPoint("LEFT", x + 18, 0)
                local nameX = x + 18
                if d.texture then
                    row.icon:SetTexture(d.texture)
                    row.icon:Show()
                    nameX = nameX + 22
                else
                    row.icon:Hide()
                end
                row.name:ClearAllPoints()
                row.name:SetPoint("LEFT", nameX, 0)
                row.name:SetPoint("RIGHT", row.percent, "LEFT", -8, 0)
                row.name:SetText(d.text or "")
                row.percent:SetText(StatText(d))
                row:Show()
            else
                row:Hide()
            end
        end
        empty:SetShown(count == 0)
        if count > ROWS then
            local h = box:GetHeight() - 2
            local th = math.max(24, h * ROWS / count)
            thumb:ClearAllPoints()
            thumb:SetHeight(th)
            thumb:SetPoint("TOPRIGHT", box, "TOPRIGHT", -2, -1 - (h - th) * (self.offset / (count - ROWS)))
            thumb:Show()
        else
            thumb:Hide()
        end
    end

    EventRegistry:RegisterCallback("FishingLocatons.Update", function()
        if f:IsVisible() then f:Refresh() end
    end, f)
    return f, HEAD_H + ROWS * ROW_H + 4
end

Settings:SetPage({ section = "fishing", key = "locations", label = FBConstants.LOCATIONS_TAB or "Locations", order = 1, cache = true,
    build = function(p)
        p:Section(FBConstants.LOCATIONS_TAB or "Locations", "Fish you have caught, by area or by fish. Right-click a fish to hide it from the watcher.")
        local widget, height = BuildLocations()
        p:Add(widget, height, true)
    end })
