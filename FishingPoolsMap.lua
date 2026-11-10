-- Catchy Pool Intelligence
--
-- Draws known fishing schools (Catchy_Info["FishSchools"]) on the world map
-- and annotates them with freshness. Coordinates are stored per zone by
-- FishingSchools.lua; HereBeDragons translates them between maps.

local addonName, FBStorage = ...
local FBI = FBStorage
local FBConstants = FBI.FBConstants;

local FL = LibStub("LibFishing-1.0");
local HBD = LibStub("HereBeDragons-2.0", true);

-- 5.0.4 has a problem with a global "_"
local _

local GSB = function(...) return FBI:GetSettingBool(...); end;

local FRESH = 10 * 60;          -- 10 minutes
local WARM = 30 * 60;           -- 30 minutes
local PRUNE_AGE = 45 * 86400;   -- 45 days
local MAX_PER_MAP = 1000;
local MAX_PINS = 150;
local UPDATE_INTERVAL = 0.15;

local Pools = {};
FBI.Pools = Pools;

local pins = {};
local radarPins = {};
local driver;
local installed = false;
local accumulator = 0;

local function PoolAge(hole)
    local seen = hole and (hole.lastSeen or hole.firstSeen);
    if ( not seen ) then
        return nil;
    end
    return math.max(0, time() - seen);
end

local function AgeString(seconds)
    if ( not seconds ) then
        return "unknown";
    end
    if ( seconds < 60 ) then
        return string.format("%ds ago", seconds);
    elseif ( seconds < 3600 ) then
        return string.format("%dm ago", math.floor(seconds / 60));
    elseif ( seconds < 86400 ) then
        return string.format("%dh ago", math.floor(seconds / 3600));
    end
    return string.format("%dd ago", math.floor(seconds / 86400));
end

local function Freshness(age)
    if ( not age ) then
        return 0.55, 0.55, 0.55;
    elseif ( age <= FRESH ) then
        return 0.35, 1.0, 0.45;
    elseif ( age <= WARM ) then
        return 1.0, 0.82, 0.25;
    end
    return 0.55, 0.55, 0.55;
end

local function GetMapParent()
    if ( WorldMapFrame and WorldMapFrame.ScrollContainer ) then
        return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer;
    end
end

local function GetCurrentMapID()
    if ( WorldMapFrame and WorldMapFrame.GetMapID ) then
        return WorldMapFrame:GetMapID();
    end
end

local function PoolTooltip(pin)
    local hole = pin.school;
    if ( not hole ) then
        return;
    end
    GameTooltip:SetOwner(pin, "ANCHOR_RIGHT");
    GameTooltip:AddLine("Fishing Pool", 1.0, 0.82, 0.28);

    if ( hole.fish ) then
        local names = {};
        local count = 0;
        for id, n in pairs(hole.fish) do
            local name = select(6, FBI:GetFishie(id));
            if ( name ) then
                names[#names + 1] = name .. " x" .. n;
            else
                names[#names + 1] = tostring(id) .. " x" .. n;
            end
            count = count + 1;
            if ( count >= 6 ) then
                break;
            end
        end
        if ( #names > 0 ) then
            GameTooltip:AddLine(table.concat(names, ", "), 1, 1, 1, true);
        end
    end

    if ( GSB("ShowPoolAge") ) then
        local age = PoolAge(hole);
        GameTooltip:AddLine("Last seen: " .. AgeString(age), 0.8, 0.8, 0.8);
    end
    GameTooltip:AddLine("Seen: " .. (hole.count or 1) .. " time(s)", 0.8, 0.8, 0.8);
    if ( hole.x and hole.y ) then
        GameTooltip:AddLine(string.format("Location: %.0f, %.0f", hole.x * 100, hole.y * 100), 0.8, 0.8, 0.8);
    end
    GameTooltip:Show();
end

local function CreatePin(parent)
    local pin = CreateFrame("Frame", nil, parent);
    pin:SetSize(16, 16);
    pin:EnableMouse(true);
    pin:Hide();

    local icon = pin:CreateTexture(nil, "ARTWORK");
    icon:SetAllPoints();
    icon:SetTexture("Interface\\Icons\\INV_Misc_Fish_02");
    pin.icon = icon;

    local glow = pin:CreateTexture(nil, "HIGHLIGHT");
    glow:SetAllPoints();
    glow:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight");
    glow:SetBlendMode("ADD");

    pin:SetScript("OnEnter", PoolTooltip);
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide();
    end);
    return pin;
end

local function AcquirePin()
    for _, pin in ipairs(pins) do
        if ( not pin.inUse ) then
            pin.inUse = true;
            pin:Show();
            return pin;
        end
    end
    local parent = GetMapParent();
    if ( not parent ) then
        return nil;
    end
    local pin = CreatePin(parent);
    pin.inUse = true;
    pin:SetFrameLevel(math.max(1, parent:GetFrameLevel() + 5));
    pin:Show();
    pins[#pins + 1] = pin;
    return pin;
end

local function HidePins()
    for _, pin in ipairs(pins) do
        pin:Hide();
        pin.inUse = false;
        pin.school = nil;
    end
end

local function PositionPins()
    if ( not GSB("ShowMapPools") ) then
        HidePins();
        return;
    end
    if ( not WorldMapFrame or not WorldMapFrame:IsShown() ) then
        HidePins();
        return;
    end
    local mapID = GetCurrentMapID();
    local parent = GetMapParent();
    local width = parent and parent:GetWidth() or 0;
    local height = parent and parent:GetHeight() or 0;
    if ( not mapID or not parent or width <= 0 or height <= 0 ) then
        HidePins();
        return;
    end

    local freshOnly = GSB("ShowPoolsFreshOnly");
    local used = 0;
    local schools = Catchy_Info and Catchy_Info["FishSchools"] or {};
    for _, pin in ipairs(pins) do pin.inUse = false; end

    for storedMap, holes in pairs(schools) do
        for _, hole in ipairs(holes) do
            if ( type(hole) == "table" and hole.x and hole.y ) then
                local age = PoolAge(hole);
                if ( not freshOnly or (age and age <= FRESH) ) then
                    local x, y;
                    if ( storedMap == mapID ) then
                        x, y = hole.x, hole.y;
                    elseif ( HBD ) then
                        local wx, wy = HBD:GetWorldCoordinatesFromZone(hole.x, hole.y, storedMap);
                        if ( wx ) then
                            x, y = HBD:GetZoneCoordinatesFromWorld(wx, wy, mapID, true);
                        end
                    end

                    if ( x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 ) then
                        used = used + 1;
                        if ( used > MAX_PINS ) then
                            break;
                        end
                        local pin = AcquirePin();
                        if ( pin ) then
                            if ( pin:GetParent() ~= parent ) then
                                pin:SetParent(parent);
                                pin:SetFrameLevel(math.max(1, parent:GetFrameLevel() + 5));
                            end
                            pin:ClearAllPoints();
                            pin:SetPoint("CENTER", parent, "TOPLEFT", x * width, -y * height);
                            pin.school = hole;
                            local r, g, b = Freshness(age);
                            pin.icon:SetVertexColor(r, g, b);
                        end
                    end
                end
            end
        end
        if ( used > MAX_PINS ) then
            break;
        end
    end

    for _, pin in ipairs(pins) do
        if ( not pin.inUse ) then
            pin:Hide();
            pin.school = nil;
        end
    end
end

function Pools:Refresh()
    PositionPins();
    self:RefreshRadar();
end

-- ---------------------------------------------------------------------------
-- Minimap radar
-- ---------------------------------------------------------------------------

local RADAR_RANGE = 250; -- yards; keeps the display useful at every minimap zoom
local MAX_RADAR_PINS = 30;

local function HideRadarPins()
    for _, pin in ipairs(radarPins) do
        pin:Hide();
        pin.inUse = false;
        pin.school = nil;
    end
end

local function AcquireRadarPin()
    for _, pin in ipairs(radarPins) do
        if ( not pin.inUse ) then
            pin.inUse = true;
            pin:Show();
            return pin;
        end
    end
    if ( not Minimap or #radarPins >= MAX_RADAR_PINS ) then return nil; end
    local pin = CreatePin(Minimap);
    pin:SetSize(13, 13);
    pin:SetFrameStrata("MEDIUM");
    pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8);
    pin.inUse = true;
    radarPins[#radarPins + 1] = pin;
    return pin;
end

local function IsMinimapRound()
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND";
    return shape == "ROUND" or shape == "CORNER-TOPLEFT" or shape == "CORNER-TOPRIGHT" or
        shape == "CORNER-BOTTOMLEFT" or shape == "CORNER-BOTTOMRIGHT";
end

local function PositionRadarPins()
    if ( not GSB("ShowMinimapPools") or not Minimap or not Minimap:IsShown() or not HBD ) then
        HideRadarPins();
        return;
    end
    local px, py, instance = HBD:GetPlayerWorldPosition();
    if ( not px or not py ) then HideRadarPins(); return; end
    local radius = math.max(20, math.min(Minimap:GetWidth(), Minimap:GetHeight()) / 2 - 8);
    local used = 0;
    local freshOnly = GSB("ShowPoolsFreshOnly");
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1";
    local facing = rotate and (GetPlayerFacing() or 0) or 0;
    for _, pin in ipairs(radarPins) do pin.inUse = false; end

    for mapId, holes in pairs(Catchy_Info and Catchy_Info["FishSchools"] or {}) do
        for _, hole in ipairs(holes) do
            local age = PoolAge(hole);
            if ( hole.x and hole.y and (not freshOnly or (age and age <= FRESH)) ) then
                local wx, wy, wi = HBD:GetWorldCoordinatesFromZone(hole.x, hole.y, mapId);
                if ( wx and wi == instance ) then
                    local distance, dx, dy = HBD:GetWorldDistance(instance, px, py, wx, wy);
                    if ( distance and distance <= RADAR_RANGE ) then
                        local sx, sy = dx / RADAR_RANGE * radius, -dy / RADAR_RANGE * radius;
                        if ( rotate ) then
                            local c, s = math.cos(facing), math.sin(facing);
                            sx, sy = sx * c - sy * s, sx * s + sy * c;
                        end
                        if ( IsMinimapRound() and (sx * sx + sy * sy) > radius * radius ) then
                            local scale = radius / math.sqrt(sx * sx + sy * sy);
                            sx, sy = sx * scale, sy * scale;
                        end
                        local pin = AcquireRadarPin();
                        if ( pin ) then
                            used = used + 1;
                            pin:ClearAllPoints();
                            pin:SetPoint("CENTER", Minimap, "CENTER", sx, sy);
                            pin.school = hole;
                            local r, g, b = Freshness(age);
                            pin.icon:SetVertexColor(r, g, b);
                            pin:SetAlpha(math.max(0.55, 1 - (distance / RADAR_RANGE) * 0.45));
                        end
                    end
                end
            end
            if ( used >= MAX_RADAR_PINS ) then break; end
        end
        if ( used >= MAX_RADAR_PINS ) then break; end
    end
    for _, pin in ipairs(radarPins) do
        if ( not pin.inUse ) then pin:Hide(); pin.school = nil; end
    end
end

function Pools:RefreshRadar()
    PositionRadarPins();
end

local function Migrate()
    if ( not Catchy_Info or not Catchy_Info["FishSchools"] ) then
        return;
    end
    local now = time();
    for mapId, holes in pairs(Catchy_Info["FishSchools"]) do
        if ( type(holes) == "table" ) then
            local kept = {};
            for _, hole in ipairs(holes) do
                if ( type(hole) == "table" ) then
                    hole.lastSeen = hole.lastSeen or hole.firstSeen or (now - WARM);
                    hole.firstSeen = hole.firstSeen or hole.lastSeen;
                    if ( (now - hole.lastSeen) < PRUNE_AGE and #kept < MAX_PER_MAP ) then
                        kept[#kept + 1] = hole;
                    end
                end
            end
            Catchy_Info["FishSchools"][mapId] = kept;
        end
    end
end
Pools.Migrate = Migrate;

local function InstallWorldMapHooks()
    if ( installed or not WorldMapFrame ) then
        return;
    end
    installed = true;
    WorldMapFrame:HookScript("OnShow", function()
        Pools:Refresh();
    end);
    WorldMapFrame:HookScript("OnHide", function()
        HidePins();
    end);
end

driver = CreateFrame("Frame");
driver:RegisterEvent("PLAYER_LOGIN");
driver:RegisterEvent("ADDON_LOADED");
driver:SetScript("OnEvent", function(self, event, arg1)
    if ( event == "PLAYER_LOGIN" ) then
        Migrate();
        if ( WorldMapFrame ) then
            InstallWorldMapHooks();
        end
    elseif ( event == "ADDON_LOADED" and arg1 == "Blizzard_WorldMap" ) then
        InstallWorldMapHooks();
    end
end);

driver:SetScript("OnUpdate", function(self, elapsed)
    accumulator = accumulator + (elapsed or 0);
    if ( accumulator < 0.20 ) then
        return;
    end
    accumulator = 0;
    if ( WorldMapFrame and WorldMapFrame:IsShown() ) then PositionPins(); end
    PositionRadarPins();
end);

-- ---------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------

local function ClearCurrentMap()
    local mapID = GetCurrentMapID() or (FBI.GetCurrentMapIdInfo and FBI:GetCurrentMapIdInfo());
    if ( not mapID or not Catchy_Info or not Catchy_Info["FishSchools"] or not Catchy_Info["FishSchools"][mapID] ) then
        FBI:Print("No stored pools for this map.");
        return 0;
    end
    local count = #Catchy_Info["FishSchools"][mapID];
    Catchy_Info["FishSchools"][mapID] = {};
    HidePins();
    FBI:Print(string.format("Cleared %d stored pool(s) for this map.", count));
    return count;
end

FBI:AddCommand("pools", function(what)
    if ( what == "fresh" ) then
        local value = not GSB("ShowPoolsFreshOnly");
        FBI:SetSetting("ShowPoolsFreshOnly", value);
        FBI:Print("Pool pins: " .. (value and "fresh only" or "all") .. ".");
        PositionPins();
        return true;
    elseif ( what == "clear" ) then
        ClearCurrentMap();
        return true;
    end
    local value = not GSB("ShowMapPools");
    FBI:SetSetting("ShowMapPools", value);
    FBI:Print("World map pools " .. (value and "enabled" or "disabled") .. ".");
    PositionPins();
    return true;
end, "pools [fresh|clear] -- toggle world map pool pins, fresh-only filter, or clear this map's pools");

FBI:AddCommand("radar", function()
    local value = not GSB("ShowMinimapPools");
    FBI:SetSetting("ShowMinimapPools", value);
    FBI:Print("Minimap pool radar " .. (value and "enabled" or "disabled") .. ".");
    PositionRadarPins();
    return true;
end, "radar -- toggle nearby pool pins on the minimap");
