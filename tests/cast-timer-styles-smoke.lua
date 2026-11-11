local function Region()
    local object = { shown = true, level = 1 }
    function object:SetShown(value) self.shown = value end
    function object:SetText(value) self.text = value end
    function object:SetSize(width, height) self.width, self.height = width, height end
    function object:SetScale(value) self.scale = value end
    function object:SetWidth(width) self.width = width end
    function object:SetHeight(height) self.height = height end
    function object:SetFrameLevel(level) self.level = level end
    function object:GetFrameLevel() return self.level end
    function object:SetCooldown(start, duration) self.start, self.duration = start, duration end
    function object:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
    function object:SetTextColor(r, g, b) self.textColor = { r, g, b } end
    function object:SetDesaturated(value) self.desaturated = value end
    function object:CreateTexture()
        local texture = Region()
        self.textures = self.textures or {}
        self.textures[#self.textures + 1] = texture
        return texture
    end
    function object:SetPoint(_, _, _, x, y) self.anchorX, self.anchorY = x, y end
    function object:ClearAllPoints() end
    function object:SetAllPoints() end
    function object:SetTexture() end
    function object:SetTexCoord(left, right, top, bottom)
        self.texCoord = { left, right, top, bottom }
    end
    function object:SetSwipeTexture() end
    function object:SetSwipeColor() end
    function object:SetDrawSwipe() end
    function object:SetDrawEdge() end
    function object:SetDrawBling() end
    function object:SetHideCountdownNumbers() end
    function object:SetJustifyH() end
    function object:SetAlpha(value) self.alpha = value end
    return object
end

CreateFrame = function() return Region() end
local style = "bar"
local opacity = 100
local kit = {
    Tex = function(parent, _, color)
        local texture = parent:CreateTexture()
        if color then texture:SetVertexColor(unpack(color)) end
        return texture
    end,
    Text = function(parent) return parent:CreateTexture() end,
    Border = function() end,
    SetFont = function() end,
    C = { text = { 1, 1, 1 } },
}
local addon = {
    Settings = { Kit = kit },
    GetSetting = function(_, key)
        if key == "CastTimerStyle" then return style end
        if key == "CastTimerTransparency" then return opacity end
    end,
}
assert(loadfile("CatchyGauge.lua"))("Catchy", addon)

local frame = Region()
frame.numberText = Region()
frame.startTime, frame.total = 10, 30
addon.CastGauge:Update(frame, 18)
assert(frame.gauge.shown and not frame.radial.shown and not frame.numberText.shown,
    "bar mode showed another timer")
assert(frame.width == 228 and frame.height == 36 and frame.gauge.scale == 1,
    "segmented bar changed size")
assert(frame.gauge.timeText.text == "18s" and frame.gauge.activeSegments == 8,
    "bar mode did not update the segmented countdown")
assert(frame.gauge.textures[1].texCoord[2] == 228 / 256 and
       frame.gauge.textures[1].texCoord[4] == 36 / 64,
    "bar background is stretched, distorting its round ends")

style = "solid"
addon.CastGauge:Update(frame, 18)
assert(frame.gauge.shown and not frame.radial.shown and not frame.numberText.shown,
    "solid bar mode showed another timer")
assert(frame.width == 228 * 0.45 and frame.height == 36 * 0.45 and frame.gauge.scale == 0.45,
    "mono bar is not uniformly smaller")
assert(frame.gauge.solidWidth == 125 and frame.gauge.solidFill.left.shown,
    "solid bar did not update its continuous fill")
assert(not frame.gauge.segments[1].shown and not frame.gauge.marker.shown,
    "solid bar displayed segmented decorations")
assert(not frame.gauge.label.shown and not frame.gauge.timeText.shown,
    "mono bar still displays words")
local parts = frame.gauge.solidFill
assert(parts.left.width == 6 and parts.middle.anchorX + parts.middle.width == parts.right.anchorX,
    "mono fill pieces overlap or leave a gap")
assert(not parts.dot.shown and frame.gauge.solidTrack.width == 208 and
       frame.gauge.solidTrack.texCoord[2] == 208 / 256,
    "mono track does not fit the pill width")
local fill = frame.gauge.solidFill.left.color
assert(frame.gauge.background.desaturated and fill[1] == fill[2] and fill[2] == fill[3],
    "mono bar uses colored art or fill")

addon.CastGauge:Update(frame, 1)
assert(parts.dot.shown and not parts.left.shown and not parts.middle.shown and not parts.right.shown,
    "nearly empty mono fill should be a single dot")
addon.CastGauge:Update(frame, 0)
assert(not parts.dot.shown and not parts.left.shown and not parts.middle.shown and not parts.right.shown,
    "empty mono fill should be hidden")
for _, value in ipairs({ 20, 50, 100 }) do
    opacity = value
    addon.CastGauge:Update(frame, 18)
    assert(frame.alpha == value / 100, "timer opacity setting was not applied")
end

style = "radial"
addon.CastGauge:Update(frame, 18)
assert(frame.radial.shown and not frame.gauge.shown and not frame.numberText.shown,
    "watch mode showed another timer")
assert(frame.radial.timeText.text == "18" and frame.radial.cooldown.duration == 30,
    "watch mode did not update its countdown")

style = "number"
addon.CastGauge:Update(frame, 18)
assert(frame.numberText.shown and frame.numberPill.shown and not frame.gauge.shown and not frame.radial.shown,
    "number mode showed another timer")
assert(frame.width == 92 and frame.height == 38, "number pill has the wrong size")

print("cast timer styles smoke: ok")
