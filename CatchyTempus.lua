-- Optional Tempus settings bridge. This file deliberately loads after every Catchy
-- settings page so Tempus receives the final page definitions, including Journal,
-- Locations and Outfits replacements.
local _, FBI = ...
local Settings = FBI and FBI.Settings
local Tempus = _G.Tempus

if not (Settings and Tempus and Tempus.RegisterPage and Tempus.pageSections) then return end

local SECTION_KEY = "catchy"
local sectionExists = false
for _, section in ipairs(Tempus.pageSections) do
    if section.key == SECTION_KEY then
        sectionExists = true
        break
    end
end
if not sectionExists then
    Tempus.pageSections[#Tempus.pageSections + 1] = { key = SECTION_KEY, label = "Catchy" }
end

local sectionOrder = {}
for index, section in ipairs(Settings.sections or {}) do
    sectionOrder[section.key] = index
end

for index, definition in ipairs(Settings.pages or {}) do
    local source = definition
    Tempus:RegisterPage(SECTION_KEY, {
        key = "catchy_" .. source.key,
        label = source.label,
        order = (sectionOrder[source.section] or 50) * 100 + (source.order or index),
        build = function(page)
            Settings:Mixin(page)
            source.build(page)
        end,
    })
end

Settings.hosted = true
