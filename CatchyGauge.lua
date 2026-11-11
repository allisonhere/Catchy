-- Catchy: cursor-following fishing cast timers.
local addonName, FBI = ...
local Settings = FBI.Settings
if not Settings then return end
local MEDIA = "Interface\\AddOns\\" .. tostring(addonName) .. "\\media\\"

local K = Settings.Kit
local Tex, Text, SetFont, C = K.Tex, K.Text, K.SetFont, K.C

local Gauge = {}
FBI.CastGauge = Gauge

local BAR_W, BAR_H, NUMBER_W, NUMBER_H, RADIAL_SIZE = 228, 36, 92, 38, 48
local MONO_SCALE = 0.45
local SEGMENTS = 12
local PROGRESS_X, PROGRESS_W, CAP = 10, 208, 12

local function SolidFill(parent, color)
    local left = Tex(parent, "ARTWORK", color)
    local middle = Tex(parent, "ARTWORK", color)
    local right = Tex(parent, "ARTWORK", color)
    local dot = Tex(parent, "ARTWORK", color)
    for _, cap in ipairs({ left, right, dot }) do
        cap:SetTexture(MEDIA .. "CastTimerSolidCap")
    end
    left:SetTexCoord(0, CAP / 32, 0, CAP / 16)
    right:SetTexCoord(CAP / 32, CAP / 16, 0, CAP / 16)
    dot:SetTexCoord(0, CAP / 16, 0, CAP / 16)
    left:SetSize(CAP / 2, CAP)
    right:SetSize(CAP / 2, CAP)
    dot:SetSize(CAP, CAP)
    middle:SetHeight(CAP)
    left:SetPoint("LEFT", parent, "LEFT", PROGRESS_X, 0)
    middle:SetPoint("LEFT", parent, "LEFT", PROGRESS_X + CAP / 2, 0)
    dot:SetPoint("LEFT", parent, "LEFT", PROGRESS_X, 0)
    return { left = left, middle = middle, right = right, dot = dot }
end

local function SizeSolidFill(parent, parts, width)
    parts.dot:SetShown(width > 0 and width < CAP)
    parts.left:SetShown(width >= CAP)
    parts.middle:SetShown(width > CAP)
    parts.right:SetShown(width >= CAP)
    if width < CAP then return end
    parts.middle:SetWidth(width - CAP)
    parts.right:ClearAllPoints()
    parts.right:SetPoint("LEFT", parent, "LEFT", PROGRESS_X + width - CAP / 2, 0)
end

-- Where the timer hangs relative to the pointer: below, above, left or right.
function Gauge.Anchor(where, gap)
    if where == "above" then return "BOTTOM", 0, gap end
    if where == "left" then return "RIGHT", -gap, 0 end
    if where == "right" then return "LEFT", gap, 0 end
    return "TOP", 0, -gap
end

local function Build(frame)
    local g = CreateFrame("Frame", nil, frame)
    g:SetSize(BAR_W, BAR_H)
    local background = g:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(g)
    background:SetTexture(MEDIA .. "CastTimerBarFace")
    background:SetTexCoord(0, BAR_W / 256, 0, BAR_H / 64)
    g.background = background
    g.label = Text(g, 9, C.text, "OUTLINE")
    g.label:SetPoint("LEFT", g, "LEFT", 14, 0)
    g.label:SetText("FISHING")
    g.segments = {}
    for i = 1, SEGMENTS do
        local segment = Tex(g, "ARTWORK", { 0.08, 0.15, 0.20, 0.9 })
        segment:SetSize(6, 12)
        segment:SetPoint("LEFT", g, "LEFT", 74 + (i - 1) * 8, 0)
        g.segments[i] = segment
    end
    g.marker = Tex(g, "OVERLAY", { 1.0, 0.66, 0.18, 1 })
    g.marker:SetSize(3, 14)
    g.marker:SetPoint("LEFT", g, "LEFT", 176, 0)
    g.solidTrack = Tex(g, "ARTWORK", { 0.14, 0.14, 0.14, 0.95 })
    g.solidTrack:SetTexture(MEDIA .. "CastTimerSolidTrack")
    g.solidTrack:SetTexCoord(0, PROGRESS_W / 256, 0, CAP / 16)
    g.solidTrack:SetSize(PROGRESS_W, CAP)
    g.solidTrack:SetPoint("LEFT", g, "LEFT", PROGRESS_X, 0)
    g.solidFill = SolidFill(g, { 0.86, 0.86, 0.86, 1 })
    g.timeText = Text(g, 12, C.text, "OUTLINE")
    g.timeText:SetPoint("RIGHT", g, "RIGHT", -14, 0)
    g.timeText:SetJustifyH("RIGHT")

    local radial = CreateFrame("Frame", nil, frame)
    radial:SetSize(RADIAL_SIZE, RADIAL_SIZE)
    local face = radial:CreateTexture(nil, "BACKGROUND")
    face:SetAllPoints(radial)
    face:SetTexture(MEDIA .. "CastTimerClockFace")

    local cooldown = CreateFrame("Cooldown", nil, radial, "CooldownFrameTemplate")
    cooldown:SetAllPoints(radial)
    cooldown:SetSwipeTexture(MEDIA .. "CastTimerClockProgress")
    cooldown:SetSwipeColor(1, 1, 1, 1)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(true)
    radial.cooldown = cooldown

    local label = CreateFrame("Frame", nil, radial)
    label:SetAllPoints(radial)
    label:SetFrameLevel(cooldown:GetFrameLevel() + 1)
    radial.timeText = Text(label, 16, C.text, "OUTLINE")
    radial.timeText:SetPoint("CENTER", radial, "CENTER", 0, 0)
    radial.timeText:SetJustifyH("CENTER")
    frame.radial = radial

    local numberPill = frame:CreateTexture(nil, "BACKGROUND")
    numberPill:SetTexture(MEDIA .. "CastTimerNumberFace")
    numberPill:SetAllPoints(frame)
    frame.numberPill = numberPill
    return g
end

-- Each style is a complete timer, so only one is visible at a time.
local function Layout(frame, g, style)
    local text = frame.numberText
    frame.gaugeMode = style
    text:ClearAllPoints()
    g:ClearAllPoints()
    frame.radial:ClearAllPoints()
    g:SetShown(style == "bar" or style == "solid")
    g:SetScale(style == "solid" and MONO_SCALE or 1)
    g.background:SetDesaturated(style == "solid")
    g.label:SetShown(style == "bar")
    g.timeText:SetShown(style == "bar")
    frame.radial:SetShown(style == "radial")
    text:SetShown(style == "number")
    frame.numberPill:SetShown(style == "number")
    for _, segment in ipairs(g.segments) do segment:SetShown(style == "bar") end
    g.marker:SetShown(style == "bar")
    g.solidTrack:SetShown(style == "solid")
    for _, texture in pairs(g.solidFill) do texture:SetShown(style == "solid") end
    if style == "solid" then g.solidWidth = nil end
    if style == "radial" then
        frame:SetSize(RADIAL_SIZE, RADIAL_SIZE)
        frame.radial:SetPoint("CENTER", frame, "CENTER")
    elseif style == "number" then
        frame:SetSize(NUMBER_W, NUMBER_H)
        SetFont(text, 18, "OUTLINE")
        text:SetJustifyH("CENTER")
        text:SetPoint("CENTER", frame, "CENTER", 7, 1)
    else
        local scale = style == "solid" and MONO_SCALE or 1
        frame:SetSize(BAR_W * scale, BAR_H * scale)
        g:SetPoint("CENTER", frame, "CENTER")
    end
end

-- Called every frame by the timer in Catchy.lua with the seconds left.
function Gauge:Update(frame, remaining)
    local style = FBI:GetSetting("CastTimerStyle")
    if style ~= "radial" and style ~= "number" and style ~= "solid" then style = "bar" end
    local g = frame.gauge
    if not g then
        g = Build(frame)
        frame.gauge = g
    end
    if frame.gaugeMode ~= style then Layout(frame, g, style) end
    frame:SetAlpha(math.max(0.2, math.min(1, (tonumber(FBI:GetSetting("CastTimerTransparency")) or 100) / 100)))
    if style == "radial" and frame.startTime and frame.total and frame.radialStart ~= frame.startTime then
        frame.radial.cooldown:SetCooldown(frame.startTime, frame.total)
        frame.radialStart = frame.startTime
    end
    if style == "radial" then
        frame.radial.timeText:SetText(tostring(math.ceil(math.max(remaining, 0))))
    elseif style == "bar" or style == "solid" then
        local total = frame.total or 1
        local fraction = math.max(0, math.min(1, remaining / math.max(total, 1)))
        if style == "solid" then
            local width = math.floor(PROGRESS_W * fraction + 0.5)
            if width ~= g.solidWidth then
                SizeSolidFill(g, g.solidFill, width)
                g.solidWidth = width
            end
        else
            g.timeText:SetText(tostring(math.ceil(math.max(remaining, 0))) .. "s")
            local active = math.ceil(SEGMENTS * fraction)
            if active ~= g.activeSegments then
                for i, segment in ipairs(g.segments) do
                    if i <= active then
                        segment:SetVertexColor(0.13 + i * 0.015, 0.72 + i * 0.015, 1, 1)
                    else
                        segment:SetVertexColor(0.08, 0.15, 0.20, 0.9)
                    end
                end
                g.activeSegments = active
            end
        end
    end
end
