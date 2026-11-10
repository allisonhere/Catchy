local core = assert(io.open("Catchy.lua", "rb")):read("*a")
local settings = assert(io.open("CatchySettings.lua", "rb")):read("*a")

for _, value in ipairs({ "above", "below", "left", "right" }) do
    assert(core:find('["' .. value .. '"]', 1, true), "missing timer position: " .. value)
end
assert(core:find('["CastTimerPosition"]', 1, true), "timer position option is not registered")
assert(core:find('["CastTimerRadial"]', 1, true), "radial timer option is not registered")
assert(core:find('["CastTimerTransparency"]', 1, true), "timer opacity option is not registered")
assert(core:find('FBI:GetSetting("CastTimerPosition")', 1, true), "pointer anchor ignores saved position")
assert(settings:find('if o.values and o.text then return "values" end', 1, true),
    "modern settings cannot render value dropdowns")
assert(settings:find('if o.range and o.text then return "range" end', 1, true),
    "modern settings cannot render direct sliders")

local gauge = assert(io.open("CatchyGauge.lua", "rb")):read("*a")
assert(gauge:find('CreateFrame("Cooldown"', 1, true), "radial timer has no cooldown frame")
assert(gauge:find('FBI:GetSetting("CastTimerTransparency")', 1, true), "timer opacity is not applied")

local addon = { CastGauge = {} }
assert(loadfile("CatchyGauge.lua")) -- syntax and module presence are covered by the deploy sweep

print("cast timer position smoke: ok")
