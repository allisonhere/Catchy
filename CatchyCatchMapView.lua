-- Catchy Catch Map view: draws recorded catch spots on the world map.
-- Each spot is a glowing star, bigger and hotter where more fish were caught. A small panel on
-- the map filters by fish and by how recently the fish were caught. Opened from the Journal.
local addonName, FBI = ...
local CatchMap = FBI.CatchMap
if not CatchMap then return end

local View = {}
FBI.CatchMapView = View

local MAX_PINS = 250
local WINDOWS = {
    { days = nil, label = "Any time" },
    { days = 1, label = "Last 24 hours" },
    { days = 7, label = "Last 7 days" },
    { days = 30, label = "Last 30 days" },
}

View.filter = { fish = nil, window = 1 }   -- window indexes WINDOWS
View.enabled = false

local pins, panel = {}, nil
local sawMapShown = false

------------------------------------------------------------------------------------------
-- Data helpers (no UI; covered by the smoke test)
------------------------------------------------------------------------------------------
local function FishName(id)
    local name = FBI.GetFishie and select(6, FBI:GetFishie(id))
    if name then return name end
    if C_Item and C_Item.GetItemNameByID then return C_Item.GetItemNameByID(id) or ("Item " .. id) end
    return "Item " .. id
end
View.FishName = FishName

function View.ZoneName(mapId)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapId)
    if info and info.name then return info.name end
    return "Map " .. tostring(mapId)
end

local function AgeString(seconds)
    if seconds < 3600 then return string.format("%dm ago", math.max(1, math.floor(seconds / 60))) end
    if seconds < 86400 then return string.format("%dh ago", math.floor(seconds / 3600)) end
    return string.format("%dd ago", math.floor(seconds / 86400))
end

-- Zones with recorded catches, most catches first.
function View:Zones()
    local zones = {}
    for mapId in pairs(Catchy_Info and Catchy_Info["CatchSpots"] or {}) do
        local summary = CatchMap:Summary(mapId)
        if summary.total > 0 then
            zones[#zones + 1] = { mapId = mapId, name = View.ZoneName(mapId), total = summary.total, spots = summary.spots }
        end
    end
    table.sort(zones, function(a, b) return a.total > b.total end)
    return zones
end

-- Fish seen on one map, or on all maps when mapId is nil, most caught first.
function View:FishChoices(mapId)
    local counts = {}
    for id, cells in pairs(Catchy_Info and Catchy_Info["CatchSpots"] or {}) do
        if not mapId or id == mapId then
            for _, summaryFish in ipairs(CatchMap:Summary(id).fish) do
                counts[summaryFish.id] = (counts[summaryFish.id] or 0) + summaryFish.count
            end
        end
    end
    local list = {}
    for id, count in pairs(counts) do list[#list + 1] = { id = id, count = count, name = FishName(id) } end
    table.sort(list, function(a, b) return a.count > b.count end)
    return list
end

-- The cells to draw for a map under the current fish and time filter.
function View:Visible(mapId)
    local window = WINDOWS[View.filter.window or 1]
    local cutoff = window and window.days and (time() - window.days * 86400) or nil
    local list = {}
    for _, cell in ipairs(CatchMap:Cells(mapId, View.filter.fish)) do
        if not cutoff or (cell.last or 0) >= cutoff then list[#list + 1] = cell end
    end
    table.sort(list, function(a, b) return a.n > b.n end)
    for i = #list, MAX_PINS + 1, -1 do list[i] = nil end
    return list
end

-- Cool blue for single catches, through gold, to hot orange for the best spots.
local function HeatColor(t)
    if t < 0.5 then
        local k = t * 2
        return 0.30 + 0.70 * k, 0.85 - 0.07 * k, 1.00 - 0.78 * k
    end
    local k = (t - 0.5) * 2
    return 1.00, 0.78 - 0.45 * k, 0.22
end
View.HeatColor = HeatColor

------------------------------------------------------------------------------------------
-- Zone art for the in-UI showcase
------------------------------------------------------------------------------------------
-- Tile rectangles for a map layer drawn at `scale`. Edge tiles are cropped by texture
-- coordinates, the way the world map does it.
function View.TileLayout(layerW, layerH, tileW, tileH, scale)
    local tiles = {}
    if not (layerW and layerH and tileW and tileH) or tileW <= 0 or tileH <= 0 then return tiles end
    local cols, rows = math.ceil(layerW / tileW), math.ceil(layerH / tileH)
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local w = math.min(tileW, layerW - col * tileW)
            local h = math.min(tileH, layerH - row * tileH)
            tiles[#tiles + 1] = {
                x = col * tileW * scale, y = row * tileH * scale, w = w * scale, h = h * scale,
                right = w / tileW, bottom = h / tileH,
            }
        end
    end
    return tiles
end

-- Texture ids and sizes for a zone's art, or nil when the client cannot provide them.
function View.ArtInfo(mapId)
    if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures and mapId) then return end
    local ok, layers = pcall(C_Map.GetMapArtLayers, mapId)
    local layer = ok and layers and layers[1]
    if not (layer and layer.layerWidth and layer.tileWidth) then return end
    local ok2, textures = pcall(C_Map.GetMapArtLayerTextures, mapId, 1)
    if not (ok2 and type(textures) == "table" and #textures > 0) then return end
    return {
        textures = textures, layerW = layer.layerWidth, layerH = layer.layerHeight,
        tileW = layer.tileWidth, tileH = layer.tileHeight,
    }
end

-- Size of the map as drawn inside a w by h box: as large as fits, centred.
function View.FitMap(layerW, layerH, w, h)
    local scale = math.min(w / layerW, h / layerH)
    local mapW, mapH = layerW * scale, layerH * scale
    return scale, (w - mapW) / 2, (h - mapH) / 2, mapW, mapH
end

------------------------------------------------------------------------------------------
-- Map pins
------------------------------------------------------------------------------------------
local function MapParent()
    if WorldMapFrame and WorldMapFrame.ScrollContainer then
        return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
    end
end

local function SpotTooltip(pin)
    local cell = pin.cell
    if not cell then return end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Catch spot", 1, 0.82, 0.28)
    GameTooltip:AddLine(string.format("%d catch%s here", cell.n, cell.n == 1 and "" or "es"), 1, 1, 1)
    local fish = {}
    for id, count in pairs(cell.fish or {}) do fish[#fish + 1] = { id = id, count = count } end
    table.sort(fish, function(a, b) return a.count > b.count end)
    for i = 1, math.min(6, #fish) do
        GameTooltip:AddDoubleLine(FishName(fish[i].id), "x" .. fish[i].count, 0.85, 0.9, 1, 1, 0.78, 0.22)
    end
    if cell.last then GameTooltip:AddLine("Last caught " .. AgeString(math.max(0, time() - cell.last)), 0.6, 0.65, 0.72) end
    GameTooltip:Show()
end

local function AcquirePin(parent)
    for _, pin in ipairs(pins) do
        if not pin.inUse then pin.inUse = true; return pin end
    end
    local pin = CreateFrame("Frame", nil, parent)
    pin:EnableMouse(true)
    pin.glow = pin:CreateTexture(nil, "ARTWORK")
    pin.glow:SetAllPoints()
    pin.glow:SetTexture("Interface\\Cooldown\\star4")
    pin.glow:SetBlendMode("ADD")
    pin.core = pin:CreateTexture(nil, "OVERLAY")
    pin.core:SetPoint("CENTER")
    pin.core:SetTexture("Interface\\Buttons\\WHITE8X8")
    pin:SetScript("OnEnter", SpotTooltip)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
    pin.inUse = true
    pins[#pins + 1] = pin
    return pin
end

local function HidePins()
    for _, pin in ipairs(pins) do
        pin:Hide()
        pin.inUse = false
        pin.cell = nil
    end
end

------------------------------------------------------------------------------------------
-- Filter panel on the world map
------------------------------------------------------------------------------------------
local function EnsurePanel()
    if panel then return panel end
    local K = FBI.Settings and FBI.Settings.Kit
    if not (K and WorldMapFrame) then return end
    local anchor = WorldMapFrame.ScrollContainer or WorldMapFrame
    panel = CreateFrame("Frame", nil, WorldMapFrame)
    panel:SetSize(230, 118)
    panel:SetPoint("TOPLEFT", anchor, "TOPLEFT", 14, -14)
    panel:SetFrameStrata("HIGH")
    panel:EnableMouse(true)
    K.Tex(panel, "BACKGROUND", { 0.05, 0.06, 0.08, 0.92 }):SetAllPoints()
    K.Border(panel, { 1, 1, 1, 0.14 })
    panel.glow = K.Tex(panel, "BACKGROUND", { 1, 1, 1, 1 }, 1)
    panel.glow:SetPoint("TOPLEFT"); panel.glow:SetPoint("TOPRIGHT"); panel.glow:SetHeight(44)

    panel.title = K.Text(panel, 12, K.AC, "OUTLINE")
    panel.title:SetPoint("TOPLEFT", 12, -10)
    panel.title:SetText("CATCH MAP")
    panel.summary = K.Text(panel, 10, K.C.muted)
    panel.summary:SetPoint("TOPLEFT", 12, -27)

    panel.fishButton = K.FlatButton(panel, "", 206, 22, function(self)
        local items = { { value = 0, label = "All fish" } }
        local mapId = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
        for _, fish in ipairs(View:FishChoices(mapId)) do
            items[#items + 1] = { value = fish.id, label = string.format("%s  (%d)", fish.name, fish.count) }
        end
        K.OpenMenu(self, items, View.filter.fish or 0, function(value)
            View.filter.fish = value ~= 0 and value or nil
            View:Refresh()
        end)
    end)
    panel.fishButton:SetPoint("TOPLEFT", 12, -48)
    panel.timeButton = K.FlatButton(panel, "", 206, 22, function()
        View.filter.window = (View.filter.window % #WINDOWS) + 1
        View:Refresh()
    end)
    panel.timeButton:SetPoint("TOPLEFT", 12, -74)
    panel.hide = K.FlatButton(panel, "HIDE CATCH MAP", 206, 18, function() View:Close() end)
    panel.hide:SetPoint("BOTTOMLEFT", 12, 8)
    return panel
end

------------------------------------------------------------------------------------------
-- Refresh, open, close
------------------------------------------------------------------------------------------
function View:Refresh()
    local parent = MapParent()
    local shown = WorldMapFrame and WorldMapFrame:IsShown()
    if not (View.enabled and parent and shown) then
        HidePins()
        if panel then panel:Hide() end
        return
    end
    local mapId = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
    local width, height = parent:GetWidth() or 0, parent:GetHeight() or 0
    if not mapId or width <= 0 or height <= 0 then HidePins() return end

    local K = FBI.Settings and FBI.Settings.Kit
    local cells = View:Visible(mapId)
    local peak = cells[1] and cells[1].n or 1
    for _, pin in ipairs(pins) do pin.inUse = false end
    for _, cell in ipairs(cells) do
        local pin = AcquirePin(parent)
        if pin:GetParent() ~= parent then pin:SetParent(parent) end
        pin:SetFrameLevel(math.max(1, (parent:GetFrameLevel() or 1) + 6))
        local t = math.sqrt(cell.n / peak)
        local size = 18 + 26 * t
        pin:SetSize(size, size)
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", parent, "TOPLEFT", cell.x * width, -cell.y * height)
        local r, g, b = HeatColor(t)
        pin.glow:SetVertexColor(r, g, b, 0.95)
        pin.core:SetSize(4, 4)
        pin.core:SetVertexColor(1, 1, 1, 0.95)
        pin.cell = cell
        pin:Show()
    end
    for _, pin in ipairs(pins) do
        if not pin.inUse then pin:Hide(); pin.cell = nil end
    end

    local p = EnsurePanel()
    if p then
        p:Show()
        if K then K.SetGradient(p.glow, "VERTICAL", K.AC[1], K.AC[2], K.AC[3], 0, K.AC[1], K.AC[2], K.AC[3], 0.16) end
        local total = 0
        for _, cell in ipairs(cells) do total = total + cell.n end
        p.summary:SetText(string.format("%s  •  %d catch%s  •  %d spot%s", View.ZoneName(mapId),
            total, total == 1 and "" or "es", #cells, #cells == 1 and "" or "s"))
        p.fishButton.text:SetText(View.filter.fish and FishName(View.filter.fish) or "All fish")
        p.timeButton.text:SetText(WINDOWS[View.filter.window or 1].label)
    end
end

local function ShowMap(mapId)
    if not WorldMapFrame then return end
    if mapId and OpenWorldMap then
        OpenWorldMap(mapId)
        return
    end
    if ShowUIPanel then ShowUIPanel(WorldMapFrame) elseif WorldMapFrame.Show then WorldMapFrame:Show() end
    if mapId and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapId) end
end

-- Open the world map on a zone with the catch spots showing.
function View:Open(mapId, fishId)
    View.enabled = true
    sawMapShown = false
    if fishId ~= nil then View.filter.fish = fishId ~= 0 and fishId or nil end
    ShowMap(mapId)
    View:Refresh()
end

function View:Close()
    View.enabled = false
    HidePins()
    if panel then panel:Hide() end
end

-- Follow the map while it is open, and switch off once the map has been closed again.
local driver = CreateFrame("Frame")
local elapsed = 0
driver:SetScript("OnUpdate", function(_, delta)
    if not View.enabled then return end
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.2 then return end
    elapsed = 0
    local shown = WorldMapFrame and WorldMapFrame:IsShown()
    if shown then
        sawMapShown = true
        View:Refresh()
    elseif sawMapShown then
        View:Close()
    end
end)

------------------------------------------------------------------------------------------
-- The showcase: a map panel inside Catchy's own UI
------------------------------------------------------------------------------------------
local ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local function FishIcon(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return icon or (GetItemIcon and GetItemIcon(id)) or ICON_FALLBACK
end

-- Which zone the showcase shows: the chosen one, else the zone with the most catches.
function View:Selected()
    local zones = View:Zones()
    for _, zone in ipairs(zones) do
        if zone.mapId == View.selected then return zone.mapId, zones end
    end
    View.selected = zones[1] and zones[1].mapId or nil
    return View.selected, zones
end

function View:Step(delta)
    local current, zones = View:Selected()
    if #zones == 0 then return end
    local index = 1
    for i, zone in ipairs(zones) do if zone.mapId == current then index = i end end
    index = ((index - 1 + delta) % #zones) + 1
    View.selected = zones[index].mapId
end

function View:BuildShowcase(K, width, height)
    local box = CreateFrame("Frame", nil, nil)
    box:SetSize(width, height)
    K.Tex(box, "BACKGROUND", { 0.02, 0.03, 0.05, 1 }):SetAllPoints()

    -- map art
    local tiles = {}
    for i = 1, 32 do
        local t = box:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:Hide()
        tiles[i] = t
    end
    local grid = {}
    for i = 1, 9 do
        local line = K.Tex(box, "BACKGROUND", { 0.3, 0.7, 0.9, 0.06 }, 1)
        line:Hide()
        grid[i] = line
    end
    local noArt = K.Text(box, 11, K.C.muted)
    noArt:SetPoint("CENTER", 0, -10)
    noArt:SetText("Map art is not available for this zone")
    noArt:Hide()

    -- moody wash and vignette
    local wash = K.Tex(box, "ARTWORK", { 0.03, 0.06, 0.1, 0.38 }, -1)
    wash:SetAllPoints()
    local function Edge(point1, point2, orientation, thick, alpha)
        local e = K.Tex(box, "ARTWORK", { 0, 0, 0, 1 }, 1)
        e:SetPoint(point1); e:SetPoint(point2)
        if orientation == "V" then e:SetHeight(thick) else e:SetWidth(thick) end
        return e
    end
    local top = Edge("TOPLEFT", "TOPRIGHT", "V", 120)
    local bottom = Edge("BOTTOMLEFT", "BOTTOMRIGHT", "V", 90)
    local left = Edge("TOPLEFT", "BOTTOMLEFT", "H", 70)
    local right = Edge("TOPRIGHT", "BOTTOMRIGHT", "H", 70)
    K.SetGradient(top, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.82)
    K.SetGradient(bottom, "VERTICAL", 0, 0, 0, 0.85, 0, 0, 0, 0)
    K.SetGradient(left, "HORIZONTAL", 0, 0, 0, 0.6, 0, 0, 0, 0)
    K.SetGradient(right, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.6)
    K.Border(box, { 1, 1, 1, 0.12 })

    -- spots live on their own canvas that matches the drawn map
    local canvas = CreateFrame("Frame", nil, box)
    canvas:SetAllPoints()
    local spots = {}
    local function Spot(index)
        local pin = spots[index]
        if pin then return pin end
        pin = CreateFrame("Frame", nil, canvas)
        pin:EnableMouse(true)
        pin.halo = pin:CreateTexture(nil, "ARTWORK", nil, 1)
        pin.halo:SetPoint("CENTER")
        pin.halo:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        pin.halo:SetBlendMode("ADD")
        pin.star = pin:CreateTexture(nil, "ARTWORK", nil, 2)
        pin.star:SetAllPoints()
        pin.star:SetTexture("Interface\\Cooldown\\star4")
        pin.star:SetBlendMode("ADD")
        pin.core = pin:CreateTexture(nil, "OVERLAY")
        pin.core:SetPoint("CENTER")
        pin.core:SetSize(4, 4)
        pin.core:SetTexture("Interface\\Buttons\\WHITE8X8")
        if pin.CreateAnimationGroup then
            pin.pulse = pin.halo:CreateAnimationGroup()
            local a = pin.pulse:CreateAnimation("Alpha")
            a:SetFromAlpha(0.45); a:SetToAlpha(1)
            a:SetDuration(1.2 + (index % 7) * 0.17)
            if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
            pin.pulse:SetLooping("BOUNCE")
        end
        pin:SetScript("OnEnter", SpotTooltip)
        pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
        spots[index] = pin
        return pin
    end

    -- headline
    local zoneName = K.Text(box, 24, K.AC, "OUTLINE")
    zoneName:SetPoint("TOPLEFT", 20, -16)
    local zoneStats = K.Text(box, 11, K.C.text)
    zoneStats:SetPoint("TOPLEFT", 21, -46)
    local zoneFishLine = K.Text(box, 11, K.C.muted)
    zoneFishLine:SetPoint("TOPLEFT", 21, -63)

    local prev = K.FlatButton(box, "<", 26, 24, function() View:Step(-1); box:Refresh() end)
    prev:SetPoint("TOPRIGHT", -58, -16)
    local nextBtn = K.FlatButton(box, ">", 26, 24, function() View:Step(1); box:Refresh() end)
    nextBtn:SetPoint("LEFT", prev, "RIGHT", 6, 0)

    -- bottom row: heat legend, time filter, top spot callout
    local legendLabel = K.Text(box, 9, K.C.muted)
    legendLabel:SetPoint("BOTTOMLEFT", 20, 40)
    legendLabel:SetText("CATCH DENSITY")
    local legend = {}
    for i = 1, 24 do
        local seg = K.Tex(box, "OVERLAY", { 1, 1, 1, 1 })
        seg:SetSize(5, 6)
        seg:SetPoint("BOTTOMLEFT", 20 + (i - 1) * 5, 28)
        seg:SetVertexColor(View.HeatColor((i - 1) / 23))
        legend[i] = seg
    end
    local lo = K.Text(box, 9, K.C.muted)
    lo:SetPoint("BOTTOMLEFT", 20, 14); lo:SetText("few")
    local hi = K.Text(box, 9, K.C.muted)
    hi:SetPoint("BOTTOMLEFT", 20 + 24 * 5 - 22, 14); hi:SetText("many")
    local timeBtn = K.FlatButton(box, "", 118, 22, function()
        View.filter.window = (View.filter.window % #WINDOWS) + 1
        box:Refresh()
    end)
    timeBtn:SetPoint("BOTTOMRIGHT", -16, 14)

    local callout = CreateFrame("Frame", nil, box)
    callout:SetSize(230, 30)
    callout:SetPoint("BOTTOMRIGHT", timeBtn, "BOTTOMLEFT", -10, 0)
    K.Tex(callout, "BACKGROUND", { 0, 0, 0, 0.45 }):SetAllPoints()
    K.Border(callout, { 1, 1, 1, 0.12 })
    callout.icon = callout:CreateTexture(nil, "ARTWORK")
    callout.icon:SetSize(22, 22)
    callout.icon:SetPoint("LEFT", 5, 0)
    callout.text = K.Text(callout, 11, K.C.text)
    callout.text:SetPoint("LEFT", callout.icon, "RIGHT", 8, 0)
    callout.text:SetWidth(190)

    local empty = K.Text(box, 14, K.C.muted)
    empty:SetPoint("CENTER", 0, 4)
    empty:SetJustifyH("CENTER")
    empty:SetText("No catch spots yet\nGo fishing and your best waters light up here")

    function box:Refresh()
        local mapId = View:Selected()
        local r, g, b = K.AC[1], K.AC[2], K.AC[3]
        local cells = mapId and View:Visible(mapId) or {}
        empty:SetShown(mapId == nil)
        timeBtn.text:SetText(WINDOWS[View.filter.window or 1].label)
        for _, t in ipairs(tiles) do t:Hide() end
        for _, line in ipairs(grid) do line:Hide() end
        noArt:Hide()
        for _, pin in ipairs(spots) do
            pin:Hide()
            if pin.pulse then pin.pulse:Stop() end
        end
        callout:SetShown(mapId ~= nil and #cells > 0)
        for _, w in ipairs({ prev, nextBtn }) do w:SetShown(mapId ~= nil) end
        if not mapId then
            zoneName:SetText("Catch Map")
            zoneStats:SetText("")
            zoneFishLine:SetText("")
            return
        end

        -- draw the zone
        local art = View.ArtInfo(mapId)
        local mapW, mapH, offsetX, offsetY
        if art then
            local scale
            scale, offsetX, offsetY, mapW, mapH = View.FitMap(art.layerW, art.layerH, width, height)
            for i, rect in ipairs(View.TileLayout(art.layerW, art.layerH, art.tileW, art.tileH, scale)) do
                local tex, id = tiles[i], art.textures[i]
                if tex and id then
                    tex:ClearAllPoints()
                    tex:SetPoint("TOPLEFT", box, "TOPLEFT", offsetX + rect.x, -(offsetY + rect.y))
                    tex:SetSize(rect.w, rect.h)
                    tex:SetTexture(id)
                    tex:SetTexCoord(0, rect.right, 0, rect.bottom)
                    tex:SetVertexColor(0.78, 0.86, 0.95, 1)
                    tex:Show()
                end
            end
        else
            mapW, mapH = width - 40, height - 40
            offsetX, offsetY = 20, 20
            for i = 1, 9 do
                local line = grid[i]
                line:ClearAllPoints()
                if i <= 5 then
                    line:SetSize(mapW, 1)
                    line:SetPoint("TOPLEFT", box, "TOPLEFT", offsetX, -(offsetY + (i - 1) * mapH / 4))
                else
                    line:SetSize(1, mapH)
                    line:SetPoint("TOPLEFT", box, "TOPLEFT", offsetX + (i - 6) * mapW / 3, -offsetY)
                end
                line:Show()
            end
            noArt:Show()
        end

        -- draw the spots
        local peak = cells[1] and cells[1].n or 1
        local total = 0
        for index, cell in ipairs(cells) do
            total = total + cell.n
            local pin = Spot(index)
            local t = math.sqrt(cell.n / peak)
            local size = 16 + 30 * t
            pin:SetSize(size, size)
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", box, "TOPLEFT", offsetX + cell.x * mapW, -(offsetY + cell.y * mapH))
            pin:SetFrameLevel(box:GetFrameLevel() + 4 + math.floor(t * 4))
            local hr, hg, hb = HeatColor(t)
            pin.halo:SetSize(size * 2.6, size * 2.6)
            pin.halo:SetVertexColor(hr, hg, hb, 0.85)
            pin.star:SetVertexColor(hr, hg, hb, 1)
            pin.core:SetVertexColor(1, 1, 1, 1)
            pin.cell = cell
            pin:Show()
            if pin.pulse then pin.pulse:Play() end
        end

        -- headline and callout
        local summary = CatchMap:Summary(mapId)
        zoneName:SetText(View.ZoneName(mapId))
        zoneStats:SetText(string.format("|cffffc738%d|r catch%s  •  |cff49dce8%d|r spot%s",
            total, total == 1 and "" or "es", #cells, #cells == 1 and "" or "s"))
        local topFish = summary.fish[1]
        zoneFishLine:SetText(topFish and ("Top fish: " .. FishName(topFish.id) .. "  x" .. topFish.count) or "")
        if cells[1] then
            local best, bestCount = nil, 0
            for id, count in pairs(cells[1].fish or {}) do
                if count > bestCount then best, bestCount = id, count end
            end
            callout.icon:SetTexture(best and FishIcon(best) or ICON_FALLBACK)
            callout.text:SetText(string.format("Best spot: |cffffc738%d|r catches%s", cells[1].n,
                best and ("  •  " .. FishName(best)) or ""))
        end
        K.SetGradient(wash, "VERTICAL", r * 0.2, g * 0.2, b * 0.3, 0.35, 0.02, 0.04, 0.08, 0.5)
    end

    box:SetScript("OnShow", function() box:Refresh() end)
    return box
end
