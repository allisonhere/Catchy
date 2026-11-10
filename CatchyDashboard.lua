-- Catchy Session Dashboard
--
-- Turns the casts/catches Catchy already observes into a small live HUD:
-- catches per hour, catch rate, misses, streaks, session duration and gold.
--
-- The stats module is intentionally self contained so other parts of the addon
-- (watcher, future journal) can read from FBI.Stats without duplicating data.

local addonName, FBStorage = ...
local FBI = FBStorage
local FBConstants = FBI.FBConstants;

local FL = LibStub("LibFishing-1.0");

-- 5.0.4 has a problem with a global "_"
local _

local GSB = function(...) return FBI:GetSettingBool(...); end;

FBI.Stats = FBI.Stats or {};
local Stats = FBI.Stats;

local SESSION_IDLE = 30 * 60;   -- start a fresh session after this long away
local CAST_DEBOUNCE = 0.5;      -- collapse duplicate cast notifications
local MAX_CATCH_TIMES = 20;
local MAX_OUTCOMES = 20;
local MAX_SESSIONS = 30;

local db;
local lastCastAt = 0;
local lastCastStartedAt = 0;
local castSerial = 0;
local pendingCast = nil;
local lootMoneyBefore = nil;
local session = nil;

local function Today()
    return date("%Y-%m-%d");
end

local function EnsureDB()
    if ( not Catchy_Player ) then
        return nil;
    end
    Catchy_Player["Stats"] = Catchy_Player["Stats"] or {};
    db = Catchy_Player["Stats"];
    db.lifetime = db.lifetime or { casts = 0, catches = 0, misses = 0, gold = 0 };
    db.lifetime.perFish = db.lifetime.perFish or {};
    db.lifetime.zones = db.lifetime.zones or {};
    db.daily = db.daily or {};
    db.sessions = db.sessions or {};
    return db;
end

local function NewSession()
    local s = {
        startWall = time(),
        lastActivity = time(),
        casts = 0,
        catches = 0,
        misses = 0,
        gold = 0,
        streak = 0,
        best = 0,
        catchTimes = {},
        outcomes = {},
        perFish = {},
        zones = {},
        hookTotal = 0,
        hookCount = 0,
        intervalTotal = 0,
        intervalCount = 0,
        unresolved = 0,
        interrupted = 0,
    };
    if ( db ) then
        db.session = s;
    end
    return s;
end

local function EnsureSession()
    if ( not EnsureDB() ) then
        return nil;
    end
    local s = db.session;
    if ( not s or type(s) ~= "table" or type(s.startWall) ~= "number" or
         (time() - (s.lastActivity or s.startWall)) > SESSION_IDLE or
         date("%Y-%m-%d", s.startWall) ~= Today() ) then
        if ( s and type(s) == "table" and (s.casts or 0) > 0 ) then
            db.sessions = db.sessions or {};
            table.insert(db.sessions, 1, s);
            while ( #db.sessions > MAX_SESSIONS ) do
                table.remove(db.sessions);
            end
        end
        s = NewSession();
    end
    s.catchTimes = s.catchTimes or {};
    s.outcomes = s.outcomes or {};
    s.perFish = s.perFish or {};
    s.zones = s.zones or {};
    s.streak = s.streak or 0;
    s.best = s.best or 0;
    s.gold = s.gold or 0;
    s.casts = s.casts or 0;
    s.catches = s.catches or 0;
    s.misses = s.misses or 0;
    s.hookTotal = s.hookTotal or 0;
    s.hookCount = s.hookCount or 0;
    s.intervalTotal = s.intervalTotal or 0;
    s.intervalCount = s.intervalCount or 0;
    s.unresolved = s.unresolved or 0;
    s.interrupted = s.interrupted or 0;
    session = s;
    db.session = s;
    return s;
end

Stats.EnsureSession = EnsureSession;

local function BumpDaily(field, amount)
    if ( not EnsureDB() ) then
        return;
    end
    local key = Today();
    local day = db.daily[key];
    if ( not day ) then
        day = { casts = 0, catches = 0, misses = 0, gold = 0, perFish = {}, zones = {} };
        db.daily[key] = day;
    end
    day[field] = (day[field] or 0) + amount;
end

local function CurrentZone()
    local mapId = FBI.GetCurrentMapIdInfo and FBI:GetCurrentMapIdInfo();
    local name = GetRealZoneText and GetRealZoneText() or UNKNOWN or "Unknown";
    return mapId or 0, name;
end

local function BumpNested(container, key, field, amount, name)
    container[key] = container[key] or {};
    local row = container[key];
    row[field] = (row[field] or 0) + amount;
    row.name = row.name or name;
end

local function RecordOutcome(value)
    table.insert(session.outcomes, value);
    while ( #session.outcomes > MAX_OUTCOMES ) do
        table.remove(session.outcomes, 1);
    end
end

local function BumpLifetime(field, amount)
    if ( not EnsureDB() ) then
        return;
    end
    db.lifetime[field] = (db.lifetime[field] or 0) + amount;
end

local function ResolveCast()
    if ( pendingCast ) then
        pendingCast.resolved = true;
    end
end
Stats.ResolveCast = ResolveCast;

function Stats:Cast()
    if ( not EnsureSession() ) then
        return;
    end
    local now = GetTime();
    if ( now - lastCastAt ) < CAST_DEBOUNCE then
        return;
    end
    if ( pendingCast and not pendingCast.resolved ) then
        pendingCast.resolved = true;
        session.unresolved = session.unresolved + 1;
        BumpDaily("unresolved", 1);
        BumpLifetime("unresolved", 1);
        RecordOutcome(0);
    end
    if ( lastCastStartedAt > 0 and (now - lastCastStartedAt) < 180 ) then
        local interval = now - lastCastStartedAt;
        session.intervalTotal = session.intervalTotal + interval;
        session.intervalCount = session.intervalCount + 1;
        BumpDaily("intervalTotal", interval);
        BumpDaily("intervalCount", 1);
        BumpLifetime("intervalTotal", interval);
        BumpLifetime("intervalCount", 1);
    end
    lastCastAt = now;
    lastCastStartedAt = now;
    castSerial = castSerial + 1;
    pendingCast = { serial = castSerial, resolved = false, started = now };
    session.casts = session.casts + 1;
    session.lastActivity = time();
    BumpDaily("casts", 1);
    BumpLifetime("casts", 1);
    local mapId, zoneName = CurrentZone();
    BumpNested(session.zones, mapId, "casts", 1, zoneName);
    local day = db.daily[Today()];
    day.zones = day.zones or {};
    db.lifetime.zones = db.lifetime.zones or {};
    BumpNested(day.zones, mapId, "casts", 1, zoneName);
    BumpNested(db.lifetime.zones, mapId, "casts", 1, zoneName);
end

function Stats:Catch(id, quantity)
    if ( not EnsureSession() ) then
        return;
    end
    -- One fishing cast can yield several loot entries (fish + junk/coins).
    -- Count the cast once for catch-rate purposes, but track every item.
    local firstOfCast = true;
    if ( pendingCast ) then
        firstOfCast = not pendingCast.resolved;
    end
    ResolveCast();

    quantity = quantity or 1;
    if ( quantity < 1 ) then
        quantity = 1;
    end
    session.lastActivity = time();
    if ( firstOfCast ) then
        session.catches = session.catches + 1;
        session.streak = session.streak + 1;
        if ( session.streak > session.best ) then
            session.best = session.streak;
        end
        table.insert(session.catchTimes, time());
        while ( #session.catchTimes > MAX_CATCH_TIMES ) do
            table.remove(session.catchTimes, 1);
        end
        BumpDaily("catches", 1);
        BumpLifetime("catches", 1);
        RecordOutcome(1);
        if ( pendingCast and pendingCast.started ) then
            local hook = GetTime() - pendingCast.started;
            if ( hook >= 0 and hook < 180 ) then
                session.hookTotal = session.hookTotal + hook;
                session.hookCount = session.hookCount + 1;
                BumpDaily("hookTotal", hook);
                BumpDaily("hookCount", 1);
                BumpLifetime("hookTotal", hook);
                BumpLifetime("hookCount", 1);
            end
        end
    end
    if ( id ) then
        session.perFish[id] = (session.perFish[id] or 0) + quantity;
        local day = db.daily[Today()];
        day.perFish = day.perFish or {};
        db.lifetime.perFish = db.lifetime.perFish or {};
        day.perFish[id] = (day.perFish[id] or 0) + quantity;
        db.lifetime.perFish[id] = (db.lifetime.perFish[id] or 0) + quantity;
    end
    local mapId, zoneName = CurrentZone();
    BumpNested(session.zones, mapId, "catches", firstOfCast and 1 or 0, zoneName);
    local day = db.daily[Today()];
    day.zones = day.zones or {};
    BumpNested(day.zones, mapId, "catches", firstOfCast and 1 or 0, zoneName);
    BumpNested(db.lifetime.zones, mapId, "catches", firstOfCast and 1 or 0, zoneName);
end

function Stats:Miss()
    if ( not EnsureSession() ) then
        return;
    end
    local firstOfCast = true;
    if ( pendingCast ) then
        firstOfCast = not pendingCast.resolved;
    end
    ResolveCast();
    session.lastActivity = time();
    if ( firstOfCast ) then
        session.misses = session.misses + 1;
        session.streak = 0;
        BumpDaily("misses", 1);
        BumpLifetime("misses", 1);
        RecordOutcome(0);
    end
end

function Stats:Interrupted()
    if ( not EnsureSession() or not pendingCast or pendingCast.resolved ) then
        return;
    end
    pendingCast.resolved = true;
    session.interrupted = session.interrupted + 1;
    BumpDaily("interrupted", 1);
    BumpLifetime("interrupted", 1);
end

function Stats:RollingRate()
    if ( not session or #session.outcomes == 0 ) then return 0; end
    local caught = 0;
    for _, outcome in ipairs(session.outcomes) do caught = caught + outcome; end
    return caught * 100 / #session.outcomes;
end

function Stats:AverageHookTime()
    if ( not session or session.hookCount == 0 ) then return 0; end
    return session.hookTotal / session.hookCount;
end

function Stats:AverageCastInterval()
    if ( not session or session.intervalCount == 0 ) then return 0; end
    return session.intervalTotal / session.intervalCount;
end

function Stats:GetDatabase()
    EnsureSession();
    return db, session;
end

function Stats:CastEnded()
    -- Misses are recorded from the "missed fish" loot items Catchy already
    -- recognises. Counting a timeout here would double-count those (and flag
    -- slow manual looters), so this is intentionally a no-op hook.
end

function Stats:AddGold(copper)
    if ( not copper or copper <= 0 ) then
        return;
    end
    if ( not EnsureSession() ) then
        return;
    end
    session.gold = session.gold + copper;
    BumpDaily("gold", copper);
    BumpLifetime("gold", copper);
end

function Stats:Elapsed()
    if ( not session ) then
        return 0;
    end
    return math.max(0, time() - (session.startWall or time()));
end

function Stats:CatchRate()
    if ( not session or session.casts <= 0 ) then
        return 0;
    end
    return (session.catches / session.casts) * 100;
end

function Stats:CatchesPerHour()
    if ( not session ) then
        return 0;
    end
    local hours = self:Elapsed() / 3600;
    if ( hours < 0.0166 ) then -- less than a minute of data
        return 0;
    end
    return session.catches / hours;
end

function Stats:Reset()
    if ( not EnsureDB() ) then
        return;
    end
    db.session = nil;
    session = nil;
    ResolveCast();
    pendingCast = nil;
    EnsureSession();
    Stats:Refresh(true);
end

function Stats:Save()
    if ( EnsureSession() ) then
        session.lastActivity = session.lastActivity or time();
    end
end

-- ---------------------------------------------------------------------------
-- Cast / loot hooks
-- ---------------------------------------------------------------------------

local function IsFishingSpell(spellid)
    if ( spellid and (spellid == 131474 or spellid == 131490) ) then
        return true;
    end
    local name, _, _, channelSpellID = FBI:GetChannelInfo("player");
    if ( channelSpellID and (channelSpellID == 131474 or channelSpellID == 131490) ) then
        return true;
    end
    if ( name and (name == PROFESSIONS_FISHING) ) then
        return true;
    end
    return false;
end

local function RecentlyFishing()
    return lastCastAt > 0 and (GetTime() - lastCastAt) < 20;
end

-- Catchy records loot through FBI:AddFishie. Wrapping it gives us a single,
-- reliable catch signal without touching the loot parser.
local origAddFishie = FBI.AddFishie;
if ( origAddFishie ) then
    function FBI:AddFishie(color, id, name, mapId, subzone, texture, quantity, quality, level, it, st, poolhint)
        origAddFishie(self, color, id, name, mapId, subzone, texture, quantity, quality, level, it, st, poolhint);
        if ( id and id ~= 0 ) then
            if ( FL:IsMissedFish(id) ) then
                Stats:Miss();
            else
                Stats:Catch(id, quantity);
            end
        end
    end
end

local eventFrame = CreateFrame("Frame");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:RegisterEvent("PLAYER_LOGOUT");
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START");
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP");
eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED");
eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED");
eventFrame:RegisterEvent("LOOT_OPENED");
eventFrame:RegisterEvent("LOOT_CLOSED");

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if ( event == "PLAYER_LOGIN" ) then
        EnsureSession();
        Stats:RestorePosition();
        Stats:Refresh(true);
    elseif ( event == "PLAYER_LOGOUT" ) then
        Stats:Save();
    elseif ( event == "LOOT_OPENED" ) then
        if ( RecentlyFishing() ) then
            lootMoneyBefore = GetMoney();
        else
            lootMoneyBefore = nil;
        end
    elseif ( event == "LOOT_CLOSED" ) then
        if ( lootMoneyBefore ) then
            local gained = GetMoney() - lootMoneyBefore;
            lootMoneyBefore = nil;
            Stats:AddGold(gained);
        end
    else
        local unit, _, spellid = ...;
        if ( unit ~= "player" ) then
            return;
        end
        if ( event == "UNIT_SPELLCAST_CHANNEL_START" ) then
            if ( IsFishingSpell(spellid) ) then
                Stats:Cast();
            end
        elseif ( event == "UNIT_SPELLCAST_CHANNEL_STOP" ) then
            if ( IsFishingSpell(spellid) or (FishingModeFrame and FishingModeFrame.fishing_started) ) then
                lastCastAt = GetTime();
                Stats:CastEnded();
            end
        elseif ( event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" ) then
            Stats:Interrupted();
        end
    end
end);

-- ---------------------------------------------------------------------------
-- Dashboard UI
-- ---------------------------------------------------------------------------

local ROWS = {
    { key = "duration", label = "Session time" },
    { key = "casts",    label = "Casts" },
    { key = "catches",  label = "Catches" },
    { key = "rate",     label = "Catch rate" },
    { key = "missed",   label = "Missed" },
    { key = "perhour",  label = "Catches / hour" },
    { key = "rolling",  label = "Last 20 casts" },
    { key = "hook",     label = "Avg. bite time" },
    { key = "cadence",  label = "Cast cadence" },
    { key = "unresolved", label = "Unlooted casts" },
    { key = "streak",   label = "Best streak" },
    { key = "gold",     label = "Gold earned" },
};

local function FormatTime(seconds)
    local s = math.floor(seconds or 0);
    local hours = math.floor(s / 3600);
    local mins = math.floor((s % 3600) / 60);
    local secs = s % 60;
    if ( hours > 0 ) then
        return string.format("%d:%02d:%02d", hours, mins, secs);
    end
    return string.format("%02d:%02d", mins, secs);
end

local function FormatMoney(copper)
    copper = math.floor(copper or 0);
    local gold = math.floor(copper / 10000);
    local silver = math.floor((copper % 10000) / 100);
    local cop = copper % 100;
    if ( gold > 0 ) then
        return string.format("%dg %ds", gold, silver);
    elseif ( silver > 0 ) then
        return string.format("%ds %dc", silver, cop);
    end
    return string.format("%dc", cop);
end

local frame = CreateFrame("Frame", "CatchyStatsFrame", UIParent, "BackdropTemplate");
frame:SetSize(270, 318);
frame:SetFrameStrata("LOW");
frame:SetClampedToScreen(true);
frame:SetMovable(true);
frame:EnableMouse(true);
frame:Hide();

if ( frame.SetBackdrop ) then
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    });
    frame:SetBackdropColor(0.04, 0.04, 0.06, 0.84);
    frame:SetBackdropBorderColor(0.82, 0.66, 0.24, 1);
end

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
title:SetPoint("TOPLEFT", 12, -10);
title:SetText("Catchy");
title:SetTextColor(1.0, 0.82, 0.28);

local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
subtitle:SetPoint("LEFT", title, "RIGHT", 6, 0);
subtitle:SetText("Session");
subtitle:SetTextColor(0.75, 0.75, 0.75);

local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
hint:SetPoint("TOPRIGHT", -12, -11);
hint:SetText("drag");
hint:SetTextColor(0.45, 0.45, 0.45);

local rowWidgets = {};
local y = -34;
for _, row in ipairs(ROWS) do
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
    label:SetPoint("TOPLEFT", 14, y);
    label:SetText(row.label);
    label:SetTextColor(0.64, 0.64, 0.64);

    local value = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall");
    value:SetPoint("TOPRIGHT", -14, y);
    value:SetText("-");
    value:SetJustifyH("RIGHT");

    rowWidgets[row.key] = value;
    y = y - 19;
end

local journalButton = CreateFrame("Button", nil, frame, "BackdropTemplate");
journalButton:SetPoint("BOTTOMLEFT", 12, 10);
journalButton:SetPoint("BOTTOMRIGHT", -12, 10);
journalButton:SetHeight(24);
if ( journalButton.SetBackdrop ) then
    journalButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    });
    journalButton:SetBackdropColor(0.11, 0.09, 0.035, 0.96);
    journalButton:SetBackdropBorderColor(0.82, 0.66, 0.24, 0.9);
end
local journalLabel = journalButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
journalLabel:SetPoint("CENTER");
journalLabel:SetText("OPEN FISHING JOURNAL");
journalLabel:SetTextColor(1.0, 0.82, 0.28);
journalButton:SetScript("OnEnter", function(self)
    if ( self.SetBackdropColor ) then self:SetBackdropColor(0.20, 0.16, 0.05, 1); end
    journalLabel:SetTextColor(1, 0.94, 0.55);
end);
journalButton:SetScript("OnLeave", function(self)
    if ( self.SetBackdropColor ) then self:SetBackdropColor(0.11, 0.09, 0.035, 0.96); end
    journalLabel:SetTextColor(1.0, 0.82, 0.28);
end);
journalButton:SetScript("OnClick", function()
    if ( FBI.Journal and FBI.Journal.Open ) then FBI.Journal:Open(); end
end);
FBI.StatsJournalButton = journalButton;

local function UpdateValues()
    if ( not EnsureSession() ) then
        return;
    end
    rowWidgets.duration:SetText(FormatTime(Stats:Elapsed()));
    rowWidgets.casts:SetText(tostring(session.casts or 0));
    rowWidgets.catches:SetText(tostring(session.catches or 0));
    rowWidgets.rate:SetText(string.format("%.1f%%", Stats:CatchRate()));
    rowWidgets.missed:SetText(tostring(session.misses or 0));
    rowWidgets.perhour:SetText(string.format("%.1f", Stats:CatchesPerHour()));
    rowWidgets.rolling:SetText(string.format("%.1f%%", Stats:RollingRate()));
    rowWidgets.hook:SetText(session.hookCount > 0 and string.format("%.1fs", Stats:AverageHookTime()) or "--");
    rowWidgets.cadence:SetText(session.intervalCount > 0 and string.format("%.1fs", Stats:AverageCastInterval()) or "--");
    rowWidgets.unresolved:SetText(tostring(session.unresolved or 0));
    rowWidgets.streak:SetText(tostring(session.best or 0));
    if ( GSB("WatchDashboardGold") ) then
        rowWidgets.gold:SetText(FormatMoney(session.gold));
    else
        rowWidgets.gold:SetText("");
    end
end

function Stats:Refresh(force)
    if ( not frame:IsShown() and not force ) then
        return;
    end
    UpdateValues();
end

local accumulator = 0;
frame:SetScript("OnUpdate", function(self, elapsed)
    accumulator = accumulator + (elapsed or 0);
    if ( accumulator < 0.5 ) then
        return;
    end
    accumulator = 0;

    local shouldShow = GSB("WatchDashboard") and
        ( GSB("WatchDashboardAlways") or FBI:AreWeFishing() or FBI.watcher_fishing_pending or
          ( self.forceShowUntil and GetTime() < self.forceShowUntil ) );
    if ( shouldShow ) then
        if ( not self:IsShown() ) then
            self:Show();
        end
        UpdateValues();
    elseif ( self:IsShown() ) then
        self:Hide();
    end
end);

frame:SetScript("OnDragStart", function(self)
    self:StartMoving();
end);
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing();
    Stats:SavePosition();
end);
frame:RegisterForDrag("LeftButton");
frame:SetScript("OnMouseDown", function(self, button)
    if ( button == "RightButton" ) then
        self:Hide();
    end
end);

function Stats:SavePosition()
    if ( not EnsureDB() ) then
        return;
    end
    local point, _, relPoint, x, y = frame:GetPoint();
    db.pos = { point = point, relPoint = relPoint, x = x, y = y };
end

function Stats:RestorePosition()
    if ( not EnsureDB() ) then
        return;
    end
    local p = db.pos;
    frame:ClearAllPoints();
    if ( p and p.point ) then
        frame:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 20, p.y or 140);
    else
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 140);
    end
end

FBI:AddCommand("stats", function(what)
    if ( what == "reset" ) then
        Stats:Reset();
        FBI:Print("Catchy session stats reset.");
        return true;
    end
    if ( not FBI:GetSettingOption("WatchDashboard") ) then
        FBI:Print("Dashboard options are still loading; try again in a moment.");
        return true;
    end
    local enabled = not GSB("WatchDashboard");
    FBI:SetSetting("WatchDashboard", enabled);
    FBI:Print("Session dashboard " .. (enabled and "enabled" or "disabled") .. ".");
    if ( enabled ) then
        Stats:Refresh(true);
        frame.forceShowUntil = GetTime() + 30;
        frame:Show();
    else
        frame:Hide();
    end
    return true;
end, "stats [reset] -- toggle the session dashboard or reset the current session");

FBI:AddCommand("journal", function()
    if ( FBI.Journal ) then FBI.Journal:Toggle(); end
    return true;
end, "journal -- open the Catchy fishing journal");

FBI.StatsFrame = frame;
