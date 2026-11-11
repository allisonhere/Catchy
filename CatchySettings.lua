-- Catchy: Settings
-- The options window, drawn in the exact Tempus look (dark two-tone panel, accent header
-- with logo, collapsible sidebar pages, flat widgets). The style kit is copied locally so
-- Catchy works on its own. When Tempus is installed it lists these pages in its own window
-- (Settings.pages + Settings:Mixin) and Catchy opens there instead.
--
-- Option pages are generated from the option tables the rest of Catchy already registers
-- (FBI.OptionsTable), so every module's settings show up without being listed here.
local addonName, FBI = ...
local FBConstants = FBI.FBConstants

local Settings = {}
FBI.Settings = Settings
_G.CatchyUI = { Settings = Settings }

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MEDIA = "Interface\\AddOns\\" .. tostring(addonName) .. "\\"
local FONT = MEDIA .. "media\\fonts\\Inter-SemiBold.ttf"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"
local LOGO = MEDIA .. "Icons\\Fishing-Icon"
local tempus = _G.Tempus
-- Hold Tempus's accent table itself (not a copy), so every Catchy module that
-- keeps K.AC sees profile and combat-accent changes immediately.
local AC = tempus and tempus.accent or { 0.25, 0.76, 1 }
local C = {
    bg      = { 0.047, 0.054, 0.068, 0.97 },
    panel   = { 0.06, 0.068, 0.085, 0.92 },
    side    = { 0.065, 0.073, 0.092, 1 },
    card    = { 0.10, 0.11, 0.135, 1 },
    cardHi  = { 0.13, 0.145, 0.175, 1 },
    line    = { 1, 1, 1, 0.07 },
    field   = { 0.03, 0.035, 0.045, 1 },
    text    = { 0.9, 0.92, 0.95 },
    muted   = { 0.55, 0.6, 0.68 },
}

local WIN_W, WIN_H, SIDE_W = 860, 600, 196
local CONTENT_W = WIN_W - SIDE_W - 14
local COL_W, COL_GAP, MARGIN = 280, 22, 22
local DISABLED_ALPHA = 0.45

local function Setting(name) return FBI:GetSettingBool(name) end

----------------------------------------------------------------------------------------
-- Primitives
----------------------------------------------------------------------------------------
local function SetFont(fs, size, flags)
    if fs:SetFont(FONT, size, flags or "") == false then fs:SetFont(FALLBACK_FONT, size, flags or "") end
end

local function Accent(object, alpha, multiplier)
    local T = _G.Tempus
    if T and T.Style and T.Style.Accent then
        return T.Style.Accent(object, alpha, multiplier)
    end
    local m = multiplier or 1
    if object.SetTextColor and not object.SetVertexColor then
        object:SetTextColor(AC[1] * m, AC[2] * m, AC[3] * m)
    else
        object:SetVertexColor(AC[1] * m, AC[2] * m, AC[3] * m, alpha or 1)
    end
    return object
end

local function Tex(parent, layer, color, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetTexture(WHITE)
    if color == AC then Accent(t, color[4] or 1)
    elseif color then t:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
    return t
end

local function Text(parent, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    SetFont(fs, size or 12, flags)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    color = color or C.text
    if color == AC then Accent(fs) else fs:SetTextColor(color[1], color[2], color[3]) end
    fs:SetJustifyH("LEFT")
    return fs
end

-- 1px line around a frame, built from four textures.
local function Border(frame, color)
    local sides = {}
    for i = 1, 4 do sides[i] = Tex(frame, "BORDER") end
    local t, b, l, r = sides[1], sides[2], sides[3], sides[4]
    t:SetPoint("TOPLEFT", -1, 1); t:SetPoint("TOPRIGHT", 1, 1); t:SetHeight(1)
    b:SetPoint("BOTTOMLEFT", -1, -1); b:SetPoint("BOTTOMRIGHT", 1, -1); b:SetHeight(1)
    l:SetPoint("TOPLEFT", -1, 0); l:SetPoint("BOTTOMLEFT", -1, 0); l:SetWidth(1)
    r:SetPoint("TOPRIGHT", 1, 0); r:SetPoint("BOTTOMRIGHT", 1, 0); r:SetWidth(1)
    local border = {}
    function border:SetColor(cr, cg, cb, ca)
        for _, tex in ipairs(sides) do tex:SetVertexColor(cr, cg, cb, ca or 1) end
    end
    function border:SetShown(shown)
        for _, tex in ipairs(sides) do tex:SetShown(shown) end
    end
    color = color or C.line
    border:SetColor(color[1], color[2], color[3], color[4])
    return border
end

local function SetGradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if CreateColor and pcall(tex.SetGradient, tex, orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then
        return
    end
    if tex.SetGradientAlpha then tex:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2) end
end

-- `body` and `extra` may be strings or functions returning one, read when the tip is shown.
local function Resolve(v)
    if type(v) == "function" then
        local ok, res = pcall(v)
        return ok and res or nil
    end
    return v
end

local function Tooltip(frame, title, body, extra)
    if not body and not extra then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        local text, more = Resolve(body), Resolve(extra)
        if text then GameTooltip:AddLine(text, C.muted[1] + 0.2, C.muted[2] + 0.2, C.muted[3] + 0.2, true) end
        if more then GameTooltip:AddLine(more, 1, 0.75, 0.3, true) end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Click(on)
    if PlaySound then PlaySound((SOUNDKIT and (on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)) or (on and 856 or 857)) end
end

local function FlatButton(parent, label, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, h or 24)
    b.bg = Tex(b, "BACKGROUND", C.card)
    b.bg:SetAllPoints()
    b.border = Border(b, { 1, 1, 1, 0.1 })
    b.text = Text(b, 11)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b.text:SetText(label)
    b:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(C.cardHi[1], C.cardHi[2], C.cardHi[3])
        self.border:SetColor(AC[1], AC[2], AC[3], 0.8)
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(C.card[1], C.card[2], C.card[3])
        if not self.active then self.border:SetColor(1, 1, 1, 0.1) end
    end)
    b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
    b:SetScript("OnClick", function(self, ...)
        Click(true)
        if onClick then onClick(self, ...) end
    end)
    function b:SetActive(on)
        self.active = on
        if on then
            self.border:SetColor(AC[1], AC[2], AC[3], 1)
            self.text:SetTextColor(AC[1], AC[2], AC[3])
        else
            self.border:SetColor(1, 1, 1, 0.1)
            self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        end
    end
    return b
end

local function StyledEditBox(parent, w, h)
    local e = CreateFrame("EditBox", nil, parent)
    e:SetSize(w, h or 24)
    e:SetAutoFocus(false)
    SetFont(e, 12)
    e:SetTextColor(C.text[1], C.text[2], C.text[3])
    e:SetTextInsets(8, 8, 0, 0)
    Tex(e, "BACKGROUND", C.field):SetAllPoints()
    local border = Border(e, { 1, 1, 1, 0.12 })
    e:SetScript("OnEditFocusGained", function() border:SetColor(AC[1], AC[2], AC[3], 0.9) end)
    e:SetScript("OnEditFocusLost", function() border:SetColor(1, 1, 1, 0.12) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end

----------------------------------------------------------------------------------------
-- Pop-up list used by dropdowns: one shared frame, closed by clicking anywhere else.
----------------------------------------------------------------------------------------
local menu

local function CloseMenu()
    if menu then menu:Hide() end
end

local function OpenMenu(owner, items, current, onPick)
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:EnableMouse(true)
        Tex(menu, "BACKGROUND", C.bg):SetAllPoints()
        Border(menu, { 1, 1, 1, 0.15 })
        menu.rows = {}
        menu.catcher = CreateFrame("Button", nil, UIParent)
        menu.catcher:SetAllPoints(UIParent)
        menu.catcher:SetFrameStrata("FULLSCREEN")
        menu.catcher:SetScript("OnClick", CloseMenu)
        menu.catcher:Hide()
        menu:SetScript("OnHide", function(self) self.catcher:Hide() end)
        menu:Hide()
    end
    local ROW_H = 24
    menu:SetWidth(owner:GetWidth())
    menu:SetHeight(#items * ROW_H + 2)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    for i, item in ipairs(items) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(ROW_H)
            row.bg = Tex(row, "BACKGROUND", { 1, 1, 1, 0 })
            row.bg:SetAllPoints()
            row.bar = Tex(row, "ARTWORK", AC)
            row.bar:SetSize(3, 14)
            row.bar:SetPoint("LEFT", 0, 0)
            row.text = Text(row, 12)
            row.text:SetPoint("LEFT", 12, 0)
            row:SetScript("OnEnter", function(self) self.bg:SetVertexColor(1, 1, 1, 0.06) end)
            row:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
            row:SetScript("OnClick", function(self)
                Click(true)
                CloseMenu()
                if menu.onPick then menu.onPick(self.value) end
            end)
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", -1, 0)
        row.value = item.value
        row.text:SetText(item.label)
        row.bar:SetShown(item.value == current)
        row:Show()
    end
    for i = #items + 1, #menu.rows do menu.rows[i]:Hide() end
    menu.onPick = onPick
    menu.catcher:Show()
    menu:Show()
    menu:Raise()
end

----------------------------------------------------------------------------------------
-- Widgets. Each returns frame, height, and has :Refresh() that re-reads its option.
-- opts: indent (px), enabled (function -> bool), tipd (text shown while disabled).
----------------------------------------------------------------------------------------
local W = {}

local function Enabled(opts) return not (opts and opts.enabled) or opts.enabled() end

function W.Check(label, get, set, tip, opts)
    opts = opts or {}
    local f = CreateFrame("Button", nil, nil)
    f:SetSize(COL_W, 24)
    local box = CreateFrame("Frame", nil, f)
    box:SetSize(18, 18)
    box:SetPoint("LEFT", opts.indent or 0, 0)
    Tex(box, "BACKGROUND", C.field):SetAllPoints()
    local border = Border(box, { 1, 1, 1, 0.18 })
    local fill = Tex(box, "ARTWORK", AC)
    fill:SetPoint("TOPLEFT", 4, -4)
    fill:SetPoint("BOTTOMRIGHT", -4, 4)
    local text = Text(f, 12)
    text:SetPoint("LEFT", box, "RIGHT", 9, 0)
    text:SetPoint("RIGHT", f, "RIGHT")
    text:SetText(label)
    f:SetScript("OnEnter", function() border:SetColor(AC[1], AC[2], AC[3], 0.9) end)
    f:SetScript("OnLeave", function() border:SetColor(1, 1, 1, 0.18) end)
    f:SetScript("OnClick", function()
        if not Enabled(opts) then return end
        set(not get())
        Click(get())
        Settings:Refresh()
    end)
    function f:Refresh()
        fill:SetShown(get() and true or false)
        f:SetAlpha(Enabled(opts) and 1 or DISABLED_ALPHA)
    end
    Tooltip(f, label, tip, function() if not Enabled(opts) then return Resolve(opts.tipd) end end)
    return f, 24
end

function W.Slider(label, minV, maxV, step, get, set, fmt, tip, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(COL_W, 42)
    local text = Text(f, 12)
    text:SetPoint("TOPLEFT", opts.indent or 0, 0)
    text:SetText(label)
    local value = StyledEditBox(f, 58, 18)
    value:SetPoint("TOPRIGHT", 0, 2)
    value:SetJustifyH("RIGHT")
    SetFont(value, 11)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("TOPLEFT", opts.indent or 0, -26)
    s:SetPoint("TOPRIGHT", 0, -26)
    s:SetHeight(14)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local track = Tex(s, "BACKGROUND", C.field)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    local fillT = Tex(s, "BORDER", AC)
    fillT:SetPoint("LEFT", track, "LEFT")
    fillT:SetHeight(4)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(10, 14)
    thumb:SetVertexColor(0.92, 0.95, 1)
    fillT:SetPoint("RIGHT", thumb, "CENTER")
    local function Show(v)
        if fmt then value:SetText(fmt(v)) else value:SetText(tostring(v)) end
    end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        v = tonumber(("%.3f"):format(v))
        Show(v)
        if self.updating or not Enabled(opts) then return end
        if v ~= get() then
            set(v)
            Settings:Refresh()
        end
    end)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + delta * step)))
    end)
    value:SetScript("OnEnterPressed", function(self)
        local v = tonumber((self:GetText():gsub("[^%d%.%-]", "")))
        if v then s:SetValue(math.min(maxV, math.max(minV, v))) end
        self:ClearFocus()
    end)
    function f:Refresh()
        s.updating = true
        s:SetValue(get() or minV)
        s.updating = false
        Show(get() or minV)
        f:SetAlpha(Enabled(opts) and 1 or DISABLED_ALPHA)
    end
    Tooltip(f, label, tip, function() if not Enabled(opts) then return Resolve(opts.tipd) end end)
    return f, 44
end

-- items: { { value = v, label = "text" }, ... } or a function returning that.
function W.Dropdown(label, items, get, set, tip, opts)
    opts = opts or {}
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(COL_W, 48)
    local text = Text(f, 12)
    text:SetPoint("TOPLEFT", opts.indent or 0, 0)
    text:SetText(label)
    local b = FlatButton(f, "", COL_W - (opts.indent or 0), 24, function(self)
        local list = Resolve(items) or {}
        OpenMenu(self, list, get(), function(v)
            set(v)
            Settings:Refresh()
        end)
    end)
    b:SetPoint("TOPLEFT", opts.indent or 0, -20)
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", 10, 0)
    b.text:SetJustifyH("LEFT")
    local arrow = Text(b, 10, C.muted)
    arrow:SetPoint("RIGHT", -10, 0)
    arrow:SetText("v")
    function f:Refresh()
        local current, shown = get(), ""
        for _, item in ipairs(Resolve(items) or {}) do
            if item.value == current then shown = item.label end
        end
        b.text:SetText(shown)
        f:SetAlpha(Enabled(opts) and 1 or DISABLED_ALPHA)
    end
    Tooltip(f, label, tip, function() if not Enabled(opts) then return Resolve(opts.tipd) end end)
    return f, 48
end

local TIMER_ART = MEDIA .. "media\\"
local TIMER_STYLES = {
    { key = "radial", label = "Watch" },
    { key = "bar", label = "Segmented" },
    { key = "solid", label = "Mono bar" },
    { key = "number", label = "Number" },
}

local function TimerPreview(card, style)
    if style == "radial" then
        local face = card:CreateTexture(nil, "ARTWORK")
        face:SetSize(42, 42)
        face:SetPoint("CENTER", card, "CENTER", 0, -12)
        face:SetTexture(TIMER_ART .. "CastTimerClockFace")
        local ring = card:CreateTexture(nil, "OVERLAY")
        ring:SetAllPoints(face)
        ring:SetTexture(TIMER_ART .. "CastTimerClockProgress")
        local time = Text(card, 13, C.text, "OUTLINE")
        time:SetPoint("CENTER", face, "CENTER")
        time:SetText("18")
    elseif style == "number" then
        local face = card:CreateTexture(nil, "ARTWORK")
        face:SetSize(78, 30)
        face:SetPoint("CENTER", card, "CENTER", 0, -12)
        face:SetTexture(TIMER_ART .. "CastTimerNumberFace")
        local time = Text(card, 14, C.text, "OUTLINE")
        time:SetPoint("CENTER", face, "CENTER", 5, 0)
        time:SetText("18.0")
    else
        local face = card:CreateTexture(nil, "ARTWORK")
        face:SetSize(style == "solid" and 55 or 122, style == "solid" and 9 or 20)
        face:SetPoint("CENTER", card, "CENTER", 0, -12)
        face:SetTexture(TIMER_ART .. "CastTimerBarFace")
        face:SetTexCoord(0, 228 / 256, 0, 36 / 64)
        face:SetDesaturated(style == "solid")
        if style == "bar" then
            local name = Text(card, 7, C.text, "OUTLINE")
            name:SetPoint("LEFT", face, "LEFT", 7, 0)
            name:SetText("FISHING")
            local time = Text(card, 8, C.text, "OUTLINE")
            time:SetPoint("RIGHT", face, "RIGHT", -8, 0)
            time:SetText("18s")
            for i = 1, 12 do
                local segment = Tex(card, "OVERLAY", i <= 8 and { 0.22, 0.85, 1 } or { 0.08, 0.15, 0.20 })
                segment:SetSize(3, 6)
                segment:SetPoint("LEFT", face, "LEFT", 38 + (i - 1) * 4, 0)
            end
            local marker = Tex(card, "OVERLAY", { 1, 0.66, 0.18 })
            marker:SetSize(2, 8)
            marker:SetPoint("LEFT", face, "LEFT", 88, 0)
        else
            local track = Tex(card, "OVERLAY", { 0.14, 0.14, 0.14 })
            track:SetTexture(TIMER_ART .. "CastTimerSolidTrack")
            track:SetTexCoord(0, 208 / 256, 0, 12 / 16)
            track:SetSize(51, 3)
            track:SetPoint("LEFT", face, "LEFT", 2, 0)
            local fill = Tex(card, "OVERLAY", { 0.86, 0.86, 0.86 })
            fill:SetSize(27, 3)
            fill:SetPoint("LEFT", face, "LEFT", 4, 0)
            for index, offset in ipairs({ 2, 31 }) do
                local cap = Tex(card, "OVERLAY", { 0.86, 0.86, 0.86 })
                cap:SetTexture(TIMER_ART .. "CastTimerSolidCap")
                if index == 1 then
                    cap:SetTexCoord(0, 6 / 16, 0, 12 / 16)
                else
                    cap:SetTexCoord(6 / 16, 12 / 16, 0, 12 / 16)
                end
                cap:SetSize(2, 3)
                cap:SetPoint("LEFT", face, "LEFT", offset, 0)
            end
        end
    end
end

function W.TimerStylePicker()
    local picker = CreateFrame("Frame", nil, nil)
    picker:SetSize(COL_W * 2 + COL_GAP, 88)
    local cards = {}
    for index, style in ipairs(TIMER_STYLES) do
        local card = CreateFrame("Button", nil, picker)
        card:SetSize(139, 88)
        card:SetPoint("TOPLEFT", picker, "TOPLEFT", (index - 1) * 147, 0)
        Tex(card, "BACKGROUND", C.card):SetAllPoints()
        card.border = Border(card, C.line)
        local title = Text(card, 11, C.text)
        title:SetPoint("TOP", card, "TOP", 0, -8)
        title:SetText(style.label)
        TimerPreview(card, style.key)
        card:SetScript("OnClick", function()
            FBI:SetSetting("CastTimerStyle", style.key)
            FBI:OptionsUpdate()
            Click(true)
            Settings:Refresh()
        end)
        card:SetScript("OnEnter", function(self)
            if style.key == "solid" then
                self.border:SetColor(0.86, 0.86, 0.86, 0.85)
            else
                self.border:SetColor(AC[1], AC[2], AC[3], 0.85)
            end
        end)
        card:SetScript("OnLeave", function() picker:Refresh() end)
        cards[index] = card
    end
    function picker:Refresh()
        local current = FBI:GetSetting("CastTimerStyle")
        for index, card in ipairs(cards) do
            if TIMER_STYLES[index].key == current then
                if current == "solid" then
                    card.border:SetColor(0.86, 0.86, 0.86, 1)
                else
                    card.border:SetColor(AC[1], AC[2], AC[3], 1)
                end
            else
                card.border:SetColor(1, 1, 1, 0.12)
            end
        end
    end
    picker.searchLabel = "Cast timer style"
    picker.searchText = "Watch segmented bar monochrome mono gray desaturated number cursor timer"
    return picker, 88
end

function W.Button(label, onClick, tip, width)
    local f = CreateFrame("Frame", nil, nil)
    f:SetSize(COL_W, 28)
    local b = FlatButton(f, label, width or 150, 26, onClick)
    b:SetPoint("LEFT")
    function f:Refresh() end
    Tooltip(b, label, tip)
    f.button = b
    return f, 28
end

----------------------------------------------------------------------------------------
-- Page layout: a two-column flow with full-width sections.
----------------------------------------------------------------------------------------
local Page = {}
Page.__index = Page

local function NewPage(parent)
    local p = setmetatable({ widgets = {}, y = -18, col = 0, rowH = 0 }, Page)
    p.frame = CreateFrame("Frame", nil, parent)
    p.frame:SetSize(CONTENT_W - 20, 10)
    return p
end

function Page:Newline()
    if self.col > 0 then
        self.y = self.y - self.rowH - 12
        self.col, self.rowH = 0, 0
    end
end

function Page:Add(widget, height, full)
    widget:SetParent(self.frame)
    widget:ClearAllPoints()
    if full then
        self:Newline()
        widget:SetPoint("TOPLEFT", self.frame, "TOPLEFT", MARGIN, self.y)
        self.y = self.y - height - 12
    else
        widget:SetPoint("TOPLEFT", self.frame, "TOPLEFT", MARGIN + self.col * (COL_W + COL_GAP), self.y)
        self.rowH = math.max(self.rowH, height)
        self.col = self.col + 1
        if self.col == 2 then self:Newline() end
    end
    self.widgets[#self.widgets + 1] = widget
    return widget
end

function Page:Section(title, desc)
    self:Newline()
    if self.y < -20 then self.y = self.y - 10 end
    local t = Text(self.frame, 14, AC)
    t:SetPoint("TOPLEFT", MARGIN, self.y)
    t:SetText(title)
    local line = Tex(self.frame, "ARTWORK", C.line)
    line:SetHeight(1)
    line:SetPoint("LEFT", t, "RIGHT", 10, 0)
    line:SetPoint("RIGHT", self.frame, "RIGHT", -MARGIN, 0)
    self.y = self.y - 22
    if desc then
        local d = Text(self.frame, 11, C.muted)
        d:SetPoint("TOPLEFT", MARGIN, self.y)
        d:SetWidth(COL_W * 2 + COL_GAP)
        d:SetText(desc)
        d:SetSpacing(2)
        self.y = self.y - d:GetStringHeight() - 10
    end
    self.y = self.y - 4
end

function Page:Paragraph(text, indent, color, size, gap)
    self:Newline()
    local d = Text(self.frame, size or 12, color or C.muted)
    d:SetPoint("TOPLEFT", MARGIN + (indent or 0), self.y)
    d:SetWidth(COL_W * 2 + COL_GAP - (indent or 0))
    d:SetText(text)
    d:SetSpacing(2)
    self.y = self.y - d:GetStringHeight() - (gap or 12)
end

function Page:Finish()
    self:Newline()
    self.frame:SetHeight(-self.y + 20)
end

function Page:Refresh()
    for _, w in ipairs(self.widgets) do w:Refresh() end
end

function Page:Button(label, onClick, tip, width)
    return self:Add(W.Button(label, onClick, tip, width))
end

----------------------------------------------------------------------------------------
-- Option pages: widgets bound to Catchy's registered option tables.
----------------------------------------------------------------------------------------
-- Known options keep the order the old window used; anything else follows by name.
local PRIORITY = {}
do
    local order = {
        "ShowNewFishies", "TurnOffPVP", "SortByPercent", "ShowBanner",
        "EnhanceFishingSounds", "BackgroundSounds", "TurnOnSound", "MaxSound", "EnhancePools",
        "TownsfolkTracker",
        "EasyCast", "MountedCast", "AutoLoot", "AutoOpen", "UseAction", "PartialGear", "WithoutGear",
        "WatchBobber", "WatchCastTimer", "CastTimerStyle", "CastTimerTransparency", "CastTimerPosition",
        "MouseEvent", "EasyCastKeys", "EasyLures", "AlwaysHat",
        "AlwaysLure", "LastResort",
        "WatchFishies", "WatchCurrentSkill", "WatchOnlyWhenFishing", "WatchCurrentZone",
        "WatchFishPercent", "WatchElapsedTime", "WatchCurrentOnly", "WatchHideTrash",
        "FishingFluff", "FindFish", "DrinkHeavily",
    }
    for i, name in ipairs(order) do PRIORITY[name] = i end
end

local function FindTab(spec)
    local tabs = FBI.OptionsTable
    if not tabs then return end
    if spec.name and tabs[spec.name] then return spec.name, tabs[spec.name] end
    for name, info in pairs(tabs) do
        if info.options then
            if spec.option and info.options[spec.option] then return name, info end
            if spec.button then
                for _, o in pairs(info.options) do
                    if o.button == spec.button then return name, info end
                end
            end
        end
    end
end

function Settings:AuditOptions()
    local checks = {
        general = { name = GENERAL },
        casting = { option = "EasyCast" },
        watcher = { option = "WatchFishies" },
        fun = { option = "FishingFluff" },
    }
    local results, total = {}, 0
    for key, spec in pairs(checks) do
        local _, info = FindTab(spec)
        local count = 0
        if info and info.options then
            for name, option in pairs(info.options) do
                if (option.v and option.text or option.button) and
                    (not spec.include or spec.include(name, option)) then
                    count = count + 1
                end
            end
        end
        results[key] = count
        total = total + count
    end
    return results, total
end

-- What kind of widget an option becomes, or nil when it has none here.
local function OptionKind(o)
    if o.visible then
        local ok, show = pcall(o.visible, o)
        if ok and not show then return end
    end
    if o.v and o.text then return "check" end
    if o.values and o.text then return "values" end
    if o.range and o.text then return "range" end
    if type(o.button) == "string" then
        local frame = _G[o.button]
        if frame then
            if frame.info and frame.info.setting and frame.info.min and frame.info.max then return "slider", frame end
            if frame.Setting and frame.menu and frame.menu.Mapping then return "dropdown", frame end
        end
    end
end

local function SortedItems(mapping)
    local items = {}
    for value, label in pairs(mapping) do items[#items + 1] = { value = value, label = tostring(label) } end
    table.sort(items, function(a, b) return a.label < b.label end)
    return items
end

local function ParentNames(o)
    local names = {}
    for _, field in ipairs({ "parents", "depends" }) do
        for name, what in pairs(o[field] or {}) do names[#names + 1] = { name = name, what = what } end
    end
    return names
end

local function Tip(o)
    return function()
        local t = o.tooltip
        return type(t) == "function" and t(o) or t
    end
end

local function DisabledTip(o)
    return function()
        local t = o.tooltipd
        if type(t) == "function" then
            local ok, res = pcall(t, o)
            t = ok and res or nil
        end
        return t
    end
end

-- Build the widget for one entry; `byName` lets it find its parents' state.
local function EntryWidget(e, byName, indent)
    local o, name = e.o, e.name
    local opts = { indent = indent, tipd = DisabledTip(o) }
    opts.enabled = function()
        if o.enabled then
            local ok, v = pcall(o.enabled, o)
            if ok and (v == 0 or v == false) then return false end
        end
        for _, link in ipairs(ParentNames(o)) do
            local parent = byName[link.name]
            if parent then
                if parent.opts and not parent.opts.enabled() then return false end
                if not Setting(link.name) then return false end
                if type(link.what) == "function" then
                    local ok, _, value = pcall(link.what)
                    if ok and not value then return false end
                end
            end
        end
        return true
    end
    e.opts = opts
    if e.kind == "check" then
        return W.Check(o.text, function() return Setting(name) end, function(v)
            FBI:SetSetting(name, v)
            FBI:OptionsUpdate()
            if o.update then pcall(o.update, { name = name, option = o }) end
        end, Tip(o), opts)
    elseif e.kind == "slider" then
        local i = e.frame.info
        local label = (i.format or ""):match("^(.-)%s*%-%s*%%") or o.text or name
        local percent = (i.format or ""):find("%%%%", 1, true)
        return W.Slider(label, i.min, i.max, i.step or 1,
            function() return FBI:GetSetting(i.setting) end,
            function(v) FBI:SetSetting(i.setting, v); FBI:OptionsUpdate() end,
            percent and function(v) return v .. "%" end or nil, Tip(o), opts)
    elseif e.kind == "dropdown" then
        local d = e.frame
        return W.Dropdown(d.Label or o.text or name, function() return SortedItems(d.menu.Mapping) end,
            function() return FBI:GetSetting(d.Setting) end,
            function(v) FBI:SetSetting(d.Setting, v); FBI:OptionsUpdate() end, Tip(o), opts)
    elseif e.kind == "values" then
        return W.Dropdown(o.text or name, function() return SortedItems(o.values) end,
            function() return FBI:GetSetting(name) end,
            function(v) FBI:SetSetting(name, v); FBI:OptionsUpdate() end, Tip(o), opts)
    elseif e.kind == "range" then
        local range = o.range
        return W.Slider(o.text or name, range.min, range.max, range.step or 1,
            function() return FBI:GetSetting(name) end,
            function(v) FBI:SetSetting(name, v); FBI:OptionsUpdate() end,
            function(v) return tostring(v) .. (range.suffix or "") end, Tip(o), opts)
    end
end

-- Lay out a tab's options: loose options in two columns, then each option that has
-- dependents with those dependents indented beneath it.
function Page:Options(spec)
    local _, info = FindTab(spec)
    if not info then
        self:Paragraph("These options are not available yet. Try again in a moment.")
        return
    end
    local entries, byName = {}, {}
    for name, o in pairs(info.options) do
        local kind, frame = OptionKind(o)
        if kind and (not spec.include or spec.include(name, o)) then
            local e = { name = name, o = o, kind = kind, frame = frame, children = {} }
            entries[#entries + 1] = e
            byName[name] = e
        end
    end
    if #entries == 0 then
        self:Paragraph("No controls were registered for this page. Run /ca settingscheck and report the result.",
            0, { 1, 0.35, 0.35 })
        return
    end
    table.sort(entries, function(a, b)
        local pa, pb = PRIORITY[a.name] or 1000, PRIORITY[b.name] or 1000
        if pa ~= pb then return pa < pb end
        return tostring(a.o.text or a.name) < tostring(b.o.text or b.name)
    end)
    for _, e in ipairs(entries) do
        for _, link in ipairs(ParentNames(e.o)) do
            local parent = byName[link.name]
            if parent then
                e.parent = parent
                parent.children[#parent.children + 1] = e
                break
            end
        end
    end

    local function Place(e, indent)
        local widget, height = EntryWidget(e, byName, indent)
        -- every widget is one column wide, so sliders and dropdowns can share a row too
        if widget then self:Add(widget, height) end
    end
    local function PlaceTree(e, indent)
        Place(e, indent)
        for _, child in ipairs(e.children) do PlaceTree(child, indent + 22) end
    end

    for _, e in ipairs(entries) do
        if not e.parent and #e.children == 0 then Place(e, 0) end
    end
    for _, e in ipairs(entries) do
        if not e.parent and #e.children > 0 then
            self:Newline()
            Place(e, 0)
            self:Newline()
            for _, child in ipairs(e.children) do PlaceTree(child, 22) end
        end
    end
end

----------------------------------------------------------------------------------------
-- Pages and sidebar sections
----------------------------------------------------------------------------------------
local function ClassicButton(p, target, text)
    p:Button(text or "Open the classic window", function()
        if FBI.ToggleCatchyFrameClassic then FBI:ToggleCatchyFrameClassic(target) end
        Settings:Close()
    end, nil, 200)
end

-- On Classic, Fishing Fun's options are registered into the Casting tab itself, so a page
-- can't tell them apart by tab. Fishing Fun keeps its own list; each page filters by it.
local function IsFun(name)
    return FBI.FluffOptions ~= nil and FBI.FluffOptions[name] ~= nil
end

local function OptionPage(spec, title, desc)
    return function(p)
        p:Section(title, desc)
        p:Options(spec)
    end
end

local SECTIONS = {
    { key = "fishing",  label = "Fishing" },
    { key = "settings", label = "Settings" },
    { key = "about",    label = "About", flat = true },
}

local PAGES = {
    { section = "fishing", key = "locations", label = "Locations", order = 1, build = function(p)
        p:Section("Locations", "Fish you have caught, by zone.")
        ClassicButton(p, "FishingLocationsFrame")
    end },
    { section = "fishing", key = "outfits", label = "Outfits", order = 2, build = function(p)
        p:Section("Outfits", "Choose a fishing outfit and swap to it easily.")
        ClassicButton(p, "FishingOutfitFrame")
    end },
    { section = "settings", key = "general", label = "General", order = 1,
      build = OptionPage({ name = GENERAL }, "General") },
    { section = "settings", key = "casting", label = "Casting", order = 2,
      build = function(p)
          p:Section("Casting", "How Catchy casts, loots and applies lures for you.")
          p:Section("Cursor timer", "Choose one timer style. The preview cards show how each looks beside your pointer.")
          local picker, height = W.TimerStylePicker()
          p:Add(picker, height, true)
          p:Options({ option = "EasyCast", include = function(name)
              return name ~= "CastTimerStyle" and not IsFun(name)
          end })
      end },
    { section = "settings", key = "watcher", label = "Fish Watcher", order = 3,
      build = OptionPage({ option = "WatchFishies" }, "Fish Watcher", "The overlay that lists the fish you catch.") },
    { section = "settings", key = "fun", label = "Fishing Fun", order = 4,
      build = OptionPage({ option = "FishingFluff", include = IsFun }, "Fishing Fun") },
    { section = "about", key = "about", label = "About", order = 1, build = function(p)
        local width = COL_W * 2 + COL_GAP
        local hero = CreateFrame("Frame", nil, nil)
        hero:SetSize(width, 430)
        local glow = Tex(hero, "BACKGROUND", { 1, 1, 1, 1 })
        glow:SetPoint("TOPLEFT", 0, 0)
        glow:SetPoint("TOPRIGHT", 0, 0)
        glow:SetHeight(190)
        local logo = hero:CreateTexture(nil, "ARTWORK")
        logo:SetSize(112, 112)
        logo:SetPoint("TOP", 0, -26)
        logo:SetTexture(MEDIA .. "media\\Catchy-Logo")
        local name = Text(hero, 26, AC, "OUTLINE")
        name:SetPoint("TOP", logo, "BOTTOM", 0, -14)
        name:SetJustifyH("CENTER")
        name:SetText("Reel Catchy")
        local blurb = Text(hero, 12, C.text)
        blurb:SetPoint("TOP", name, "BOTTOM", 0, -14)
        blurb:SetWidth(width - 80)
        blurb:SetJustifyH("CENTER")
        blurb:SetText(tostring(FBConstants.DESCRIPTION1 or "") .. " " .. tostring(FBConstants.DESCRIPTION2 or ""))
        local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local version = Text(hero, 11, C.muted)
        version:SetPoint("TOP", 0, -272)
        version:SetJustifyH("CENTER")
        version:SetWidth(width)
        version:SetText("Version " .. tostring(get and get(addonName, "Version") or "?"))
        local copyright = Text(hero, 11, C.muted)
        copyright:SetPoint("TOP", 0, -298)
        copyright:SetJustifyH("CENTER")
        copyright:SetWidth(width)
        copyright:SetText(tostring(FBConstants.COPYRIGHT or ""))
        local made = Text(hero, 12, C.text)
        made:SetPoint("BOTTOM", -8, 62)
        made:SetJustifyH("CENTER")
        made:SetText("made by -allie")
        -- Inter has no heart glyph guarantee, so the heart uses a Blizzard font that does.
        local heart = hero:CreateFontString(nil, "OVERLAY")
        if heart:SetFont("Fonts\\ARIALN.TTF", 15, "OUTLINE") == false then SetFont(heart, 15, "OUTLINE") end
        heart:SetPoint("LEFT", made, "RIGHT", 4, -1)
        heart:SetTextColor(1, 0.16, 0.22)
        heart:SetText("\226\153\165")
        local credit = Text(hero, 10, C.muted)
        credit:SetPoint("BOTTOM", 0, 14)
        credit:SetWidth(width - 120)
        credit:SetJustifyH("CENTER")
        credit:SetSpacing(2)
        credit:SetText("Reel Catchy is a fork of Fishing Buddy by Sutorix, the original author. Fishing Buddy is the work of Sutorix and the many people who helped build it over the years.")
        function hero:Refresh()
            SetGradient(glow, "VERTICAL", AC[1], AC[2], AC[3], 0, AC[1], AC[2], AC[3], 0.12)
            Accent(name)
        end
        hero.searchLabel = "About Reel Catchy Catchy version copyright made by allie"
        p:Add(hero, 430, true)
    end },
}

Settings.pages, Settings.sections = PAGES, SECTIONS

-- Lets another window (Tempus) build Catchy pages: its page objects share the
-- Section/Add/Newline API, so only the option-aware helpers need adding.
function Settings:Mixin(page)
    for _, name in ipairs({ "Options", "Button", "Paragraph" }) do
        if not page[name] then page[name] = Page[name] end
    end
    page.Options = Page.Options
    return page
end

-- Exposed so a host window, and Catchy's own bigger pages, can create the same widgets.
Settings.Widgets = W
Settings.Kit = {
    Tex = Tex, Text = Text, Border = Border, FlatButton = FlatButton, StyledEditBox = StyledEditBox,
    Tooltip = Tooltip, Click = Click, SetFont = SetFont, SetGradient = SetGradient,
    OpenMenu = OpenMenu, CloseMenu = CloseMenu, Accent = Accent, W = W, C = C, AC = AC,
    COL_W = COL_W, COL_GAP = COL_GAP, MARGIN = MARGIN, CONTENT_W = CONTENT_W,
}

-- Replace a page (by key) or add it; used by files that build their own page.
function Settings:SetPage(def)
    for i, existing in ipairs(PAGES) do
        if existing.key == def.key then
            PAGES[i] = def
            return
        end
    end
    PAGES[#PAGES + 1] = def
end

----------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------
local win, scroll, thumb, nav
local expanded = {}
local pages = {}

local function UpdateScrollbar()
    local child = scroll:GetScrollChild()
    if not child then return end
    local range = math.max(0, child:GetHeight() - scroll:GetHeight())
    if range <= 0 then thumb:Hide() return end
    thumb:Show()
    local h = scroll:GetHeight()
    local th = math.max(30, h * h / child:GetHeight())
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 8, -(h - th) * (scroll:GetVerticalScroll() / range))
end

local function FindPage(key)
    for _, def in ipairs(PAGES) do
        if def.key == key then return def end
    end
end

local function Select(key)
    local def = FindPage(key) or FindPage("general")
    key = def.key
    for _, other in ipairs(PAGES) do
        local page = pages[other.key]
        if page then page.frame:SetShown(other.key == key) end
    end
    -- Option pages are rebuilt every time so options that appear later (items, plugins)
    -- are picked up; pages that build heavy widgets set `cache` and are built once.
    local page = pages[key]
    if not (page and def.cache) then
        if page then page.frame:Hide() end
        page = NewPage(scroll)
        local ok, err = pcall(def.build, page)
        if not ok then
            FBI:Output("Catchy settings page " .. key .. ": " .. tostring(err), 1, 0.3, 0.3)
        end
        page:Finish()
        pages[key] = page
    end
    scroll:SetScrollChild(page.frame)
    page.frame:Show()
    page:Refresh()
    Settings.current = key
    expanded[def.section] = true
    Settings:LayoutNav()
    scroll:SetVerticalScroll(0)
    UpdateScrollbar()
end

local function SectionPages(section)
    local list = {}
    for _, def in ipairs(PAGES) do
        if def.section == section then list[#list + 1] = def end
    end
    table.sort(list, function(a, b) return (a.order or 50) < (b.order or 50) end)
    return list
end

local function NavItem(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(26)
    b.bg = Tex(b, "BACKGROUND", { 1, 1, 1, 0 })
    b.bg:SetAllPoints()
    b.bar = Tex(b, "ARTWORK", AC)
    b.bar:SetSize(3, 16)
    b.bar:SetPoint("LEFT", 0, 0)
    b.text = Text(b, 12, C.muted)
    b.text:SetPoint("LEFT", 22, 0)
    b:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0.03) end end)
    b:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0) end end)
    function b:SetSelected(on)
        self.selected = on
        self.bar:SetShown(on)
        self.bg:SetVertexColor(1, 1, 1, on and 0.06 or 0)
        local c = on and C.text or C.muted
        self.text:SetTextColor(c[1], c[2], c[3])
    end
    return b
end

local function NavHeader(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(28)
    b.text = Text(b, 11, AC)
    b.text:SetPoint("LEFT", 12, 0)
    b.arrow = Text(b, 11, C.muted)
    b.arrow:SetPoint("RIGHT", -10, 0)
    b.line = Tex(b, "ARTWORK", C.line)
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 8, 0)
    b.line:SetPoint("BOTTOMRIGHT", -8, 0)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(AC[1], AC[2], AC[3]) end)
    return b
end

function Settings:LayoutNav()
    if not nav then return end
    local y = -8
    local hi, ii = 0, 0
    for _, section in ipairs(SECTIONS) do
        local list = SectionPages(section.key)
        if #list > 0 and section.flat then
            -- a top-level item with no header above it
            for _, def in ipairs(list) do
                ii = ii + 1
                local b = nav.items[ii] or NavItem(nav.child)
                nav.items[ii] = b
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 8, y)
                b:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
                b.text:SetText(def.label)
                b:SetSelected(def.key == Settings.current)
                b:SetScript("OnClick", function() Select(def.key) end)
                b:Show()
                y = y - 30
            end
        elseif #list > 0 then
            hi = hi + 1
            local h = nav.headers[hi] or NavHeader(nav.child)
            nav.headers[hi] = h
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 8, y)
            h:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
            h.text:SetText(section.label:upper())
            local open = expanded[section.key]
            h.arrow:SetText(open and "-" or "+")
            h:SetScript("OnClick", function()
                expanded[section.key] = not expanded[section.key]
                Settings:LayoutNav()
            end)
            h:Show()
            y = y - 30
            if open then
                for _, def in ipairs(list) do
                    ii = ii + 1
                    local b = nav.items[ii] or NavItem(nav.child)
                    nav.items[ii] = b
                    b:ClearAllPoints()
                    b:SetPoint("TOPLEFT", 8, y)
                    b:SetPoint("RIGHT", nav.child, "RIGHT", -8, 0)
                    b.text:SetText(def.label)
                    b:SetSelected(def.key == Settings.current)
                    b:SetScript("OnClick", function() Select(def.key) end)
                    b:Show()
                    y = y - 27
                end
                y = y - 4
            end
        end
    end
    for i = hi + 1, #nav.headers do nav.headers[i]:Hide() end
    for i = ii + 1, #nav.items do nav.items[i]:Hide() end
    nav.child:SetHeight(-y + 8)
    local range = math.max(0, nav.child:GetHeight() - nav:GetHeight())
    if nav:GetVerticalScroll() > range then nav:SetVerticalScroll(range) end
end

function Settings:Refresh()
    local T = _G.Tempus
    if T and T.Options and T.Options.Refresh then T.Options:Refresh() end
    if not win or not win:IsShown() then return end
    local page = pages[Settings.current]
    if page then page:Refresh() end
end

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(addonName, "Version") or "?"
end

local function CreateWindow()
    win = CreateFrame("Frame", "CatchyOptionsFrame", UIParent)
    win:SetSize(WIN_W, WIN_H)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    table.insert(UISpecialFrames, "CatchyOptionsFrame")

    local shadow = Tex(win, "BACKGROUND", { 0, 0, 0, 0.45 }, -8)
    shadow:SetPoint("TOPLEFT", -6, 6)
    shadow:SetPoint("BOTTOMRIGHT", 6, -6)
    Tex(win, "BACKGROUND", C.bg, -7):SetAllPoints()
    Border(win, { 1, 1, 1, 0.1 })

    -- Header
    local header = CreateFrame("Frame", nil, win)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(56)
    local hbg = Tex(header, "BACKGROUND", { 1, 1, 1, 1 }, -6)
    hbg:SetAllPoints()
    local function PaintHeader()
        SetGradient(hbg, "HORIZONTAL", AC[1] * 0.28, AC[2] * 0.28, AC[3] * 0.28, 0.9, 0.05, 0.055, 0.07, 0.2)
    end
    if tempus and tempus.Style and tempus.Style.OnAccent then tempus.Style.OnAccent(PaintHeader) else PaintHeader() end
    local hline = Accent(Tex(header, "ARTWORK"), 0.55)
    hline:SetHeight(1)
    hline:SetPoint("BOTTOMLEFT")
    hline:SetPoint("BOTTOMRIGHT")
    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(34, 34)
    logo:SetPoint("LEFT", 14, 0)
    logo:SetTexture(LOGO)
    local title = Text(header, 20, AC)
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, 0)
    title:SetText("Reel Catchy")
    local sub = Text(header, 10, C.muted)
    sub:SetPoint("BOTTOMLEFT", logo, "BOTTOMRIGHT", 12, 1)
    sub:SetText("FISHING ASSISTANT  ·  v" .. Version())

    local close = CreateFrame("Button", nil, header)
    close:SetSize(28, 28)
    close:SetPoint("RIGHT", -12, 0)
    local x = Text(close, 16, C.muted)
    x:SetPoint("CENTER")
    x:SetJustifyH("CENTER")
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(1, 0.4, 0.4) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    close:SetScript("OnClick", function() win:Hide() end)

    -- Sidebar
    local side = CreateFrame("Frame", nil, win)
    side:SetPoint("TOPLEFT", 0, -56)
    side:SetPoint("BOTTOMLEFT")
    side:SetWidth(SIDE_W)
    Tex(side, "BACKGROUND", C.side, -6):SetAllPoints()
    local sline = Tex(side, "ARTWORK", C.line)
    sline:SetWidth(1)
    sline:SetPoint("TOPRIGHT")
    sline:SetPoint("BOTTOMRIGHT")
    nav = CreateFrame("ScrollFrame", nil, side)
    nav:SetPoint("TOPLEFT", 0, -2)
    nav:SetPoint("BOTTOMRIGHT", 0, 40)
    nav.child = CreateFrame("Frame", nil, nav)
    nav.child:SetSize(SIDE_W, 10)
    nav:SetScrollChild(nav.child)
    nav.headers, nav.items = {}, {}
    nav:EnableMouseWheel(true)
    nav:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, nav.child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
    end)
    local foot = Text(side, 10, C.muted)
    foot:SetPoint("BOTTOMLEFT", 14, 12)
    foot:SetWidth(SIDE_W - 24)
    foot:SetText("/catchy  ·  /ca")

    -- Content
    scroll = CreateFrame("ScrollFrame", nil, win)
    scroll:SetPoint("TOPLEFT", SIDE_W + 2, -60)
    scroll:SetPoint("BOTTOMRIGHT", -14, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild()
        local range = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 48)))
        UpdateScrollbar()
    end)
    scroll:SetScrollChild(CreateFrame("Frame"))
    thumb = Accent(Tex(win, "OVERLAY"), 0.5)
    thumb:SetWidth(3)

    win:SetScript("OnShow", function()
        Settings:Refresh()
        UpdateScrollbar()
    end)
    win:SetScript("OnHide", CloseMenu)
    win:Hide()
end

-- Open the window (or Tempus's, when it hosts these pages) on a page.
function Settings:Open(key)
    key = FindPage(key or Settings.current or "general") and (key or Settings.current or "general") or "general"
    local T = _G.Tempus
    local hostedAllowed = not (T and T.PluginEnabled) or T:PluginEnabled("catchy")
    if Settings.hosted and hostedAllowed and T and T.Options and T.Options.Open and not Settings.standalone then
        -- Open the requested Catchy page and expand its section in Tempus's sidebar.
        local hostedKey = "catchy_" .. key
        if pcall(T.Options.Open, T.Options, hostedKey) then
            Settings.current = key
            if Settings.ScrollHostedPageIntoView then Settings:ScrollHostedPageIntoView(hostedKey) end
            return
        end
    end
    if not win then CreateWindow() end
    Settings.frame = win
    win:Show()
    Select(key)
end

function Settings:Close()
    if win then win:Hide() end
end

function Settings:Toggle(key)
    if win and win:IsShown() and (not key or key == Settings.current) then
        win:Hide()
    else
        Settings:Open(key)
    end
end

----------------------------------------------------------------------------------------
-- Take over the old window's entry points (minimap button, key binding, slash command).
-- The classic window stays loaded for anything not yet moved across.
----------------------------------------------------------------------------------------
local FRAME_PAGES = {
    FishingOptionsFrame = "general",
    FishingLocationsFrame = "locations",
    FishingOutfitFrame = "outfits",
}

FBI.ToggleCatchyFrameClassic = FBI.ToggleCatchyFrame
function FBI:ToggleCatchyFrame(target)
    Settings:Toggle(FRAME_PAGES[target])
end

FBI:AddCommand("settingscheck", function()
    local counts, total = Settings:AuditOptions()
    FBI:Print(string.format("Settings controls: general=%d, casting=%d, watcher=%d, fun=%d, total=%d.",
        counts.general, counts.casting, counts.watcher, counts.fun, total))
    return true
end, "settingscheck -- verify that every settings page has registered controls")
