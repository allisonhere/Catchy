-- Catchy: cast gauge
-- A fuel-gauge bar for the fishing cast timer. The frame, the number and the cursor
-- following live in Catchy.lua (the original timer); this adds the bar to that frame and
-- lays it out to match the Gauge / Number settings.
local addonName, FBI = ...
local Settings = FBI.Settings
if not Settings then return end

local K = Settings.Kit
local Tex, Text, Border, SetFont, C = K.Tex, K.Text, K.Border, K.SetFont, K.C

local Gauge = {}
FBI.CastGauge = Gauge

local GAUGE_W, GAUGE_H, GAP, NUMBER_W, LABEL_H, RADIAL_SIZE = 110, 10, 6, 40, 12, 38

-- full, half and empty colours the bar passes through
local FULL, HALF, EMPTY = { 0.30, 0.85, 0.40 }, { 1.00, 0.75, 0.20 }, { 0.95, 0.25, 0.25 }

local function Lerp(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
end

-- green when full, amber at half, red when nearly out
function Gauge.Color(fraction)
    if fraction >= 0.5 then return Lerp(HALF, FULL, (fraction - 0.5) * 2) end
    return Lerp(EMPTY, HALF, fraction * 2)
end

-- Where the timer frame hangs relative to the pointer: below (default), above, left or right.
-- `gap` is the distance from the pointer; `half` pushes the side positions out by half the
-- text width when the number is alone. Returns the frame point and the x, y offset.
function Gauge.Anchor(where, gap, half)
    half = half or 0
    if where == "above" then return "BOTTOM", 0, gap end
    if where == "left" then return "RIGHT", -(gap + half), 0 end
    if where == "right" then return "LEFT", gap + half, 0 end
    return "TOP", 0, -gap
end

local function Build(frame)
    local g = CreateFrame("Frame", nil, frame)
    g:SetSize(GAUGE_W, GAUGE_H)
    Tex(g, "BACKGROUND", C.field):SetAllPoints()
    Border(g, { 1, 1, 1, 0.25 })

    local bar = CreateFrame("StatusBar", nil, g)
    bar:SetPoint("TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    g.bar = bar

    -- tick marks at a quarter, half and three quarters
    for i = 1, 3 do
        local tick = Tex(g, "OVERLAY", { 0, 0, 0, 0.6 })
        tick:SetSize(1, GAUGE_H - 2)
        tick:SetPoint("LEFT", g, "LEFT", GAUGE_W * i / 4, 0)
    end

    g.full = Text(g, 9, C.muted, "OUTLINE")
    g.full:SetPoint("TOPLEFT", g, "BOTTOMLEFT", 0, -1)
    g.full:SetText("F")
    g.empty = Text(g, 9, C.muted, "OUTLINE")
    g.empty:SetPoint("TOPRIGHT", g, "BOTTOMRIGHT", 0, -1)
    g.empty:SetText("E")

    local radial = CreateFrame("Frame", nil, frame)
    radial:SetSize(RADIAL_SIZE, RADIAL_SIZE)
    local icon = radial:CreateTexture(nil, "BACKGROUND")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture("Interface\\Icons\\Trade_Fishing")
    icon:SetDesaturated(true)
    icon:SetVertexColor(0.55, 0.72, 0.82, 0.9)
    Border(radial, { 0.25, 0.76, 1, 0.8 })

    local cooldown = CreateFrame("Cooldown", nil, radial, "CooldownFrameTemplate")
    cooldown:SetAllPoints(radial)
    cooldown:SetDrawEdge(true)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetSwipeColor(0.05, 0.07, 0.10, 0.86)
    radial.cooldown = cooldown
    frame.radial = radial
    return g
end

-- Lay the frame out for any combination of gauge, number and radial timer.
local function Layout(frame, g, showGauge, showNumber, showRadial)
    local text = frame.numberText
    frame.gaugeMode = (showGauge and "g" or "") .. (showNumber and "n" or "") .. (showRadial and "r" or "")
    text:ClearAllPoints()
    g:ClearAllPoints()
    frame.radial:ClearAllPoints()
    g:SetShown(showGauge)
    text:SetShown(showNumber)
    frame.radial:SetShown(showRadial)
    if not showGauge and not showRadial then
        -- number alone: exactly the original timer
        frame:SetSize(1, 1)
        local font = frame.numberFont
        if font then text:SetFont(font[1], font[2], font[3]) end
        text:SetPoint("CENTER", frame, "CENTER")
        return
    end
    local width = 0
    if showRadial then
        frame.radial:SetPoint("LEFT", frame, "LEFT", 0, 0)
        width = RADIAL_SIZE
    end
    if showGauge then
        if width > 0 then width = width + GAP end
        g:SetPoint("LEFT", frame, "LEFT", width, LABEL_H / 2)
        width = width + GAUGE_W
    end
    if showNumber then
        if width > 0 then width = width + GAP end
        SetFont(text, 12, "OUTLINE")
        text:SetJustifyH("LEFT")
        text:SetPoint("LEFT", frame, "LEFT", width, 0)
        width = width + NUMBER_W
    end
    frame:SetSize(math.max(1, width), math.max(RADIAL_SIZE, GAUGE_H + LABEL_H))
end

-- Called every frame by the timer in Catchy.lua with the seconds left.
function Gauge:Update(frame, remaining)
    local showGauge = FBI:GetSettingBool("CastTimerGauge")
    local showNumber = FBI:GetSettingBool("CastTimerNumber")
    local showRadial = FBI:GetSettingBool("CastTimerRadial")
    if not showGauge and not showNumber and not showRadial then
        frame:Hide()
        return
    end
    local g = frame.gauge
    if not g then
        g = Build(frame)
        frame.gauge = g
    end
    local mode = (showGauge and "g" or "") .. (showNumber and "n" or "") .. (showRadial and "r" or "")
    if frame.gaugeMode ~= mode then Layout(frame, g, showGauge, showNumber, showRadial) end
    frame:SetAlpha(math.max(0.2, math.min(1, (tonumber(FBI:GetSetting("CastTimerTransparency")) or 100) / 100)))
    if showRadial and frame.startTime and frame.total and frame.radialStart ~= frame.startTime then
        frame.radial.cooldown:SetCooldown(frame.startTime, frame.total)
        frame.radialStart = frame.startTime
    end
    if not showGauge then return end

    local total = frame.total
    if not total or total <= 0 then total = math.max(remaining, 1) end
    local fraction = math.max(0, math.min(1, remaining / total))
    g.bar:SetMinMaxValues(0, total)
    g.bar:SetValue(math.min(remaining, total))
    local r, gr, b = Gauge.Color(fraction)
    g.bar:SetStatusBarColor(r, gr, b)
end
